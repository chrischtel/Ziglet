//! First prototype of the Ziglet VM
//! Target: Execute basic arithmetic operations using registers

const std = @import("std");
const error_mod = @import("../error.zig");
const VMError = error_mod.VMError;
const ErrorContext = error_mod.ErrorContext;
const createRuntimeError = error_mod.createRuntimeError;
const instruction_types = @import("../instruction/types.zig");
const decoder = @import("../instruction/decoder.zig");
const nexlog = @import("nexlog");

pub const Instruction = instruction_types.Instruction;
pub const OpCode = instruction_types.OpCode;
pub const REGISTER_COUNT = instruction_types.REGISTER_COUNT;

/// The configuration for a VM instance.
pub const VMConfig = struct {
    memory_size: usize = 1024 * 64,
    debug_mode: bool = true,
    log_config: LogConfig = .{},
    pub const LogConfig = struct {
        min_level: nexlog.LogLevel = .debug,
        enable_colors: bool = true,
        buffer_size: usize = 8192,
        log_file_path: ?[]const u8 = "logs/vm.log",
        max_file_size: usize = 5 * 1024 * 1024,
        max_rotated_files: usize = 3,
        enable_rotation: bool = true,
        enable_async: bool = false,
        enable_metadata: bool = true,
    };
};

/// The Virtual Machine state.
pub const VM = struct {
    registers: [REGISTER_COUNT]u32,
    pc: usize,
    program: []const Instruction,
    allocator: std.mem.Allocator,
    running: bool,
    stack: std.ArrayList(u32),
    sp: usize,
    cmp_flag: i8,
    memory: []u8,
    memory_size: usize,
    debug_mode: bool,
    instruction_cache: std.AutoHashMap(usize, Instruction),
    execution_count: std.AutoHashMap(usize, usize),
    logger: *nexlog.Logger,

    /// Initialize a new VM with custom configuration.
    pub fn initWithConfig(
        allocator: std.mem.Allocator,
        config: VMConfig,
    ) !*VM {
        try std.fs.cwd().makePath("logs");
        var builder = nexlog.LogBuilder.init();
        _ = builder.setMinLevel(config.log_config.min_level)
            .enableColors(config.log_config.enable_colors)
            .setBufferSize(config.log_config.buffer_size)
            .enableMetadata(config.log_config.enable_metadata);

        if (config.log_config.log_file_path) |path| {
            _ = builder.enableFileLogging(true, path)
                .setMaxFileSize(config.log_config.max_file_size)
                .setMaxRotatedFiles(config.log_config.max_rotated_files)
                .enableRotation(config.log_config.enable_rotation);
        }
        if (config.log_config.enable_async) {
            _ = builder.enableAsyncMode(true);
        }
        try builder.build(allocator);
        const logger = nexlog.getDefaultLogger() orelse return error.LoggerNotInitialized;

        const memory = try allocator.alloc(u8, config.memory_size);
        const instruction_cache = std.AutoHashMap(usize, Instruction).init(allocator);
        const execution_count = std.AutoHashMap(usize, usize).init(allocator);
        const vm = try allocator.create(VM);
        vm.* = VM{
            .registers = [_]u32{0} ** REGISTER_COUNT,
            .pc = 0,
            .program = &[_]Instruction{},
            .allocator = allocator,
            .running = false,
            .stack = std.ArrayList(u32).init(allocator),
            .sp = 0,
            .cmp_flag = 0,
            .memory = memory,
            .memory_size = config.memory_size,
            .debug_mode = config.debug_mode,
            .instruction_cache = instruction_cache,
            .execution_count = execution_count,
            .logger = logger,
        };

        const metadata = vm.createLogMetadata();
        vm.logger.info("VM initialized with {d}KB memory", .{config.memory_size / 1024}, metadata);
        return vm;
    }

    pub fn init(allocator: std.mem.Allocator) !*VM {
        return initWithConfig(allocator, .{});
    }

    fn createLogMetadata(self: *const VM) nexlog.LogMetadata {
        _ = self;
        return .{
            .timestamp = std.time.timestamp(),
            .thread_id = 0,
            .file = @src().file,
            .line = @src().line,
            .function = @src().fn_name,
        };
    }

    pub fn deinit(self: *VM) void {
        const metadata = self.createLogMetadata();
        self.logger.info("VM shutting down", .{}, metadata);
        self.allocator.free(self.memory);
        self.stack.deinit();
        self.instruction_cache.deinit();
        self.execution_count.deinit();
        self.logger.flush() catch {};
        nexlog.deinit();
        self.allocator.destroy(self);
    }

    /// Load a program into the VM.
    pub fn loadProgram(self: *VM, program: []const Instruction) !void {
        if (program.len == 0) {
            return createRuntimeError(error.InvalidInstruction, "loading program", "Program is empty", "Provide at least one instruction");
        }
        self.program = program;
        self.pc = 0;
        self.logProgramLoad();
    }

    /// Execute the loaded program.
    pub fn execute(self: *VM) !void {
        if (self.program.len == 0) {
            return self.logAndCreateError(error.InvalidInstruction, "executing program", "No program loaded", "Load a program before executing");
        }
        self.running = true;
        while (self.running and self.pc < self.program.len) {
            const current_inst = self.program[self.pc];
            if (self.debug_mode) {
                self.logInstructionExecution(current_inst);
                self.logRegisterState();
                self.logStackState();
            }
            try self.execution_count.put(self.pc, (self.execution_count.get(self.pc) orelse 0) + 1);
            try self.executeInstruction(current_inst);
            self.pc += 1;
            if (self.pc % 1000 == 0) {
                try self.optimizeHotPaths();
                if (self.debug_mode) {
                    self.logMemoryDump(0, 64);
                }
            }
        }
        if (self.debug_mode) {
            const debug_info = self.getDebugInfo();
            self.logger.debug("Final VM state:\n{}", .{debug_info}, self.createLogMetadata());
        }
    }

    fn executeInstruction(self: *VM, inst: instruction_types.Instruction) !void {
        const metadata = self.createLogMetadata();
        if (inst.opcode == .HALT) {
            self.logger.debug("Executing HALT instruction", .{}, metadata);
            self.running = false;
            return;
        }
        if (self.debug_mode) {
            self.logger.debug("Before instruction {any}: R{d}={d}, R{d}={d}", .{ inst, inst.operand1, self.registers[inst.operand1], inst.operand2, self.registers[inst.operand2] }, metadata);
        }
        try decoder.decode(inst, self);
        if (self.debug_mode) {
            self.logger.debug("After instruction: R{d}={d}", .{ inst.dest_reg, self.registers[inst.dest_reg] }, metadata);
        }
    }

    fn logAndCreateError(
        self: *VM,
        err: VMError,
        operation: []const u8,
        details: []const u8,
        suggestion: []const u8,
    ) VMError {
        const metadata = self.createLogMetadata();
        self.logger.err("VM Error:\n  Type: {s}\n  Operation: {s}\n  Details: {s}\n  Suggestion: {s}\n", .{ @errorName(err), operation, details, suggestion }, metadata);
        return createRuntimeError(err, operation, details, suggestion);
    }

    // --- Logging Helper Methods ---
    fn logInstructionExecution(self: *VM, inst: Instruction) void {
        const metadata = self.createLogMetadata();
        self.logger.debug("Executing instruction: {any} at PC={d}", .{ inst, self.pc }, metadata);
    }

    fn logRegisterState(self: *VM) void {
        const metadata = self.createLogMetadata();
        var buf: [512]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var string = std.ArrayList(u8).init(fba.allocator());
        defer string.deinit();
        for (self.registers, 0..) |reg, i| {
            if (reg != 0) {
                string.writer().print("R{d}={d} ", .{ i, reg }) catch continue;
            }
        }
        self.logger.debug("Register state: {s}", .{string.items}, metadata);
    }

    fn logStackState(self: *VM) void {
        const metadata = self.createLogMetadata();
        if (self.stack.items.len > 0) {
            self.logger.debug("Stack depth={d}: {any}", .{ self.stack.items.len, self.stack.items }, metadata);
        }
    }

    fn logMemoryDump(self: *VM, start: usize, length: usize) void {
        const metadata = self.createLogMetadata();
        const end = @min(start + length, self.memory.len);
        self.logger.debug("Memory dump [{d}..{d}]: {any}", .{ start, end, self.memory[start..end] }, metadata);
    }

    fn logProgramLoad(self: *VM) void {
        const metadata = self.createLogMetadata();
        self.logger.info("Program loaded: {d} instructions", .{self.program.len}, metadata);
    }

    pub fn getDebugInfo(self: *VM) DebugInfo {
        const metadata = self.createLogMetadata();
        self.logger.debug("Gathering debug information", .{}, metadata);
        return .{
            .instruction_count = self.pc,
            .last_instruction = if (self.pc > 0) self.program[self.pc - 1] else null,
            .stack_depth = self.stack.items.len,
            .registers = self.registers,
            .pc = self.pc,
            .cmp_flag = self.cmp_flag,
        };
    }

    pub fn getRegister(self: *VM, register: u8) !u32 {
        if (register >= REGISTER_COUNT) {
            return createRuntimeError(error.InvalidInstruction, "reading register", "Invalid register number", "Use registers 0 through 15");
        }
        return self.registers[register];
    }

    pub fn optimizeHotPaths(self: *VM) !void {
        var it = self.execution_count.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.* > 1000) {
                try self.instruction_cache.put(entry.key_ptr.*, self.program[entry.key_ptr.*]);
            }
        }
    }

    /// Debug information structure.
    pub const DebugInfo = struct {
        instruction_count: usize,
        last_instruction: ?Instruction,
        stack_depth: usize,
        registers: [REGISTER_COUNT]u32,
        pc: usize,
        cmp_flag: i8,

        pub fn format(
            self: DebugInfo,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.print("Debug Information:\n  Instructions executed: {d}\n  Stack depth: {d}\n  PC: {d}\n  Compare Flag: {d}\n\nRegisters:\n", .{ self.instruction_count, self.stack_depth, self.pc, self.cmp_flag });
            for (self.registers, 0..) |reg, i| {
                if (reg != 0) {
                    try writer.print("  R{d}: {d}\n", .{ i, reg });
                }
            }
            if (self.last_instruction) |inst| {
                try writer.print("\nLast instruction: {any}\n", .{inst});
            }
        }
    };
};

test "basic arithmetic operations" {
    const allocator = std.testing.allocator;
    var vm = try VM.init(allocator);
    defer vm.deinit();

    const program = &[_]Instruction{
        .{ .opcode = .LOAD, .dest_reg = 1, .operand1 = 5, .operand2 = 0 },
        .{ .opcode = .LOAD, .dest_reg = 2, .operand1 = 10, .operand2 = 0 },
        .{ .opcode = .ADD, .dest_reg = 3, .operand1 = 1, .operand2 = 2 },
        .{ .opcode = .HALT, .dest_reg = 0, .operand1 = 0, .operand2 = 0 },
    };

    try vm.loadProgram(program);
    try vm.execute();
    try std.testing.expectEqual(@as(u32, 15), try vm.getRegister(3));
}
