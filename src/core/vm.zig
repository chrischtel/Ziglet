//! First prototype of the Ziglet VM
//! Target: Execute basic arithmetic operations using registers
//! Example program we want to execute:
//!   LOAD R1, 5    ; Load value 5 into register 1
//!   LOAD R2, 10   ; Load value 10 into register 2
//!   ADD R3, R1, R2 ; Add R1 and R2, store in R3
//!   HALT          ; Stop execution

const std = @import("std");
const Error = @import("../error.zig").Error;
const createError = @import("../error.zig").createError;
const instruction_types = @import("../instruction/types.zig");
const decoder = @import("../instruction/decoder.zig");
const nexlog = @import("nexlog");

pub const Instruction = instruction_types.Instruction;
pub const OpCode = instruction_types.OpCode;
pub const REGISTER_COUNT = instruction_types.REGISTER_COUNT;

pub const VMConfig = struct {
    memory_size: usize = 1024 * 64, // 64KB default
    debug_mode: bool = false,
    log_config: LogConfig = .{},

    pub const LogConfig = struct {
        min_level: nexlog.LogLevel = .debug,
        enable_colors: bool = true,
        buffer_size: usize = 8192,
        log_file_path: ?[]const u8 = "logs/vm.log",
        max_file_size: usize = 5 * 1024 * 1024,
        max_rotated_files: usize = 3,
        enable_rotation: bool = true,
        enable_async: bool = true,
        enable_metadata: bool = true,
    };
};

/// The Virtual Machine state
pub const VM = struct {
    /// General purpose registers
    registers: [REGISTER_COUNT]u32,
    /// Program counter
    pc: usize,
    /// Current program
    program: []const Instruction,
    /// Allocation for VM memory
    allocator: std.mem.Allocator,
    /// Is the VM currently running?
    running: bool,
    /// Stack for the VM
    stack: std.ArrayList(u32),
    /// Stack pointer
    sp: usize,
    /// Comparison flag for conditional jumps
    cmp_flag: i8, // -1: less, 0: equal, 1: greater
    /// Memory for the VM
    memory: []u8,
    /// Memory size in bytes
    memory_size: usize,
    /// Debug mode flag
    debug_mode: bool,
    /// Instruction cache
    instruction_cache: std.AutoHashMap(usize, Instruction),
    /// Hot path detection
    execution_count: std.AutoHashMap(usize, usize),
    /// Logger instance
    logger: *nexlog.Logger,

    /// Initialize a new VM with custom configuration
    pub fn initWithConfig(
        allocator: std.mem.Allocator,
        config: VMConfig,
    ) !*VM {
        // Initialize logger first
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

        // Initialize VM memory
        const memory = try allocator.alloc(u8, config.memory_size);

        // Initialize hashmaps for optimization
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

    pub fn optimizeHotPaths(self: *VM) !void {
        // Identify frequently executed code paths
        var it = self.execution_count.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.* > 1000) {
                // Cache this instruction
                try self.instruction_cache.put(entry.key_ptr.*, self.program[entry.key_ptr.*]);
            }
        }
    }

    /// Debug information
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
            try writer.print(
                \\Debug Information:
                \\  Instructions executed: {}
                \\  Stack depth: {}
                \\  Program Counter: {}
                \\  Compare Flag: {}
                \\
                \\Registers:
                \\
            , .{
                self.instruction_count,
                self.stack_depth,
                self.pc,
                self.cmp_flag,
            });

            // Print registers in a formatted way
            for (self.registers, 0..) |reg, i| {
                if (reg != 0) {
                    try writer.print("  R{d}: {d}\n", .{ i, reg });
                }
            }

            if (self.last_instruction) |inst| {
                try writer.print("\nLast instruction: {}\n", .{inst});
            }
        }
    };

    pub fn getDebugInfo(self: *VM) DebugInfo {
        const metadata = self.createLogMetadata();
        self.logger.debug("Gathering debug information", .{}, metadata);

        const debug_info = DebugInfo{
            .instruction_count = self.pc,
            .last_instruction = if (self.pc > 0) self.program[self.pc - 1] else null,
            .stack_depth = self.stack.items.len,
            .registers = self.registers,
            .pc = self.pc,
            .cmp_flag = self.cmp_flag,
        };

        // Log detailed debug information
        self.logger.debug(
            \\Debug snapshot:
            \\  PC: {d}
            \\  Stack depth: {d}
            \\  Instructions executed: {d}
            \\
        , .{
            debug_info.pc,
            debug_info.stack_depth,
            debug_info.instruction_count,
        }, metadata);

        return debug_info;
    }

    /// Initialize a new VM with default configuration
    pub fn init(allocator: std.mem.Allocator) !*VM {
        return initWithConfig(allocator, .{});
    }

    fn createLogMetadata(self: *const VM) nexlog.LogMetadata {
        _ = self;
        return .{
            .timestamp = std.time.timestamp(),
            .thread_id = 0, // In a real app, get actual thread ID
            .file = @src().file,
            .line = @src().line,
            .function = @src().fn_name,
        };
    }

    /// Enable or disable debug mode
    pub fn setDebugMode(self: *VM, enable: bool) void {
        self.debug_mode = enable;
    }

    pub fn deinit(self: *VM) void {
        const metadata = self.createLogMetadata();
        self.logger.info("VM shutting down", .{}, metadata);

        self.allocator.free(self.memory);
        self.stack.deinit();
        self.instruction_cache.deinit();
        self.execution_count.deinit();

        // Ensure all logs are flushed before shutdown
        self.logger.flush() catch {};

        nexlog.deinit(); // Clean up the logger
        self.allocator.destroy(self);
    }
    /// Load a program into the VM
    pub fn loadProgram(self: *VM, program: []const Instruction) !void {
        if (program.len == 0) {
            return createError(
                error.InvalidInstruction, // Note: using error.InvalidInstruction
                "loading program",
                "Program is empty",
                "Provide at least one instruction",
                null,
            );
        }
        self.program = program;
        self.pc = 0;
    }

    /// Execute the loaded program
    pub fn execute(self: *VM) !void {
        const metadata = self.createLogMetadata();

        if (self.program.len == 0) {
            self.logger.err("Attempted to execute with no program loaded", .{}, metadata);
            return createError(
                error.InvalidInstruction,
                "executing program",
                "No program loaded",
                "Load a program before executing",
                null,
            );
        }

        self.logger.info("Starting program execution with {d} instructions", .{self.program.len}, metadata);

        self.running = true;
        while (self.running and self.pc < self.program.len) {
            if (self.debug_mode) {
                const current_inst = self.program[self.pc];
                self.logger.debug(
                    "Executing instruction at PC={d}: {any}",
                    .{ self.pc, current_inst },
                    metadata,
                );
            }

            try self.execution_count.put(self.pc, (self.execution_count.get(self.pc) orelse 0) + 1);

            try self.executeInstruction(self.program[self.pc]);
            self.pc += 1;

            if (self.pc % 1000 == 0) {
                self.logger.debug("Optimizing hot paths at PC={d}", .{self.pc}, metadata);
                try self.optimizeHotPaths();
            }
        }

        // Log final execution state
        if (self.debug_mode) {
            const debug_info = self.getDebugInfo();
            self.logger.debug(
                \\Execution completed:
                \\{}
            ,
                .{debug_info},
                metadata,
            );
        }

        self.logger.info("Program execution completed successfully", .{}, metadata);
    }

    fn executeInstruction(self: *VM, inst: instruction_types.Instruction) !void {
        const metadata = self.createLogMetadata();

        if (inst.opcode == .HALT) {
            self.logger.debug("Executing HALT instruction", .{}, metadata);
            self.running = false;
            return;
        }

        if (self.debug_mode) {
            // Log register state before execution
            self.logger.debug(
                "Before instruction {any}: R{d}={d}, R{d}={d}",
                .{
                    inst,
                    inst.operand1,
                    self.registers[inst.operand1],
                    inst.operand2,
                    self.registers[inst.operand2],
                },
                metadata,
            );
        }

        try decoder.decode(inst, self);

        if (self.debug_mode) {
            // Log register state after execution
            self.logger.debug(
                "After instruction: R{d}={d}",
                .{ inst.dest_reg, self.registers[inst.dest_reg] },
                metadata,
            );
        }
    }

    /// Get the value of a register
    pub fn getRegister(self: *VM, register: u8) !u32 {
        if (register >= REGISTER_COUNT) {
            return createError(
                error.InvalidInstruction,
                "reading register",
                "Invalid register number",
                "Use registers 0 through 15",
                null,
            );
        }
        return self.registers[register];
    }
};

// Example test showing the target we want to achieve
test "basic arithmetic operations" {
    const allocator = std.testing.allocator;

    var vm = try VM.init(allocator);
    defer vm.deinit();

    // Create a test program:
    // LOAD R1, 5
    // LOAD R2, 10
    // ADD R3, R1, R2
    const program = &[_]Instruction{
        .{ .opcode = .LOAD, .dest_reg = 1, .operand1 = 5, .operand2 = 0 },
        .{ .opcode = .LOAD, .dest_reg = 2, .operand1 = 10, .operand2 = 0 },
        .{ .opcode = .ADD, .dest_reg = 3, .operand1 = 1, .operand2 = 2 },
        .{ .opcode = .HALT, .dest_reg = 0, .operand1 = 0, .operand2 = 0 },
    };

    try vm.loadProgram(program);
    try vm.execute();

    // R3 should contain 15 (5 + 10)
    try std.testing.expectEqual(@as(u32, 15), try vm.getRegister(3));
}
