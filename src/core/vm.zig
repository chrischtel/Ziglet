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
const debug_system = @import("../debug/debug.zig");

pub const Instruction = instruction_types.Instruction;
pub const OpCode = instruction_types.OpCode;
pub const REGISTER_COUNT = instruction_types.REGISTER_COUNT;

/// The configuration for a VM instance.
pub const VMConfig = struct {
    memory_size: usize = 1024 * 64,
    debug_mode: bool = true,
    log_config: LogConfig = .{},
    debug_config: ?debug_system.DebugConfig = null, // Add debug config

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
    debug: ?debug_system.DebugSystem = null,

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

        // Initialize debug system if configured
        if (config.debug_config) |debug_cfg| {
            vm.debug = debug_system.DebugSystem.init(allocator, debug_cfg) catch |err| {
                logger.err("Failed to initialize debug system: {s}", .{@errorName(err)}, metadata);
                return error.DebugSystemInitFailed;
            };
        }
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
        if (self.debug) |*d| d.deinit();

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
            if (self.debug) |*d| d.beginInstruction(self);

            try self.execution_count.put(self.pc, (self.execution_count.get(self.pc) orelse 0) + 1);
            try self.executeInstruction(current_inst);

            if (self.debug) |*d| try d.endInstruction(self);

            self.pc += 1;
            if (self.pc % 1000 == 0) {
                try self.optimizeHotPaths();
                if (self.debug_mode) {
                    self.logMemoryDump(0, 64);
                }
            }
        }

        if (self.debug) |*d| {
            if (d.config.auto_save_trace) try d.saveTraceToFile();
            if (d.config.auto_save_profile) try d.saveProfileToFile();
        }
    }

    pub fn recordMemoryAccess(self: *VM, address: usize, is_write: bool, size: u8, value: u32) !void {
        if (self.debug) |*d| {
            try d.recordMemoryAccess(address, is_write, size, value);
        }
    }

    fn executeInstruction(self: *VM, inst: instruction_types.Instruction) !void {
        const metadata = self.createLogMetadata();

        var decoded_inst: Instruction = undefined;
        if (self.instruction_cache.get(self.pc)) |cachedInst| {
            decoded_inst = cachedInst;
            if (self.debug_mode) {
                self.logInstructionExecution(decoded_inst); // Log the cached instruction
                self.logRegisterState();
                self.logStackState();
            }
        } else {
            decoded_inst = inst;
            try decoder.decode(decoded_inst, self); // Decode only if not cached
            if (self.debug_mode) {
                self.logInstructionExecution(decoded_inst);
                self.logRegisterState();
                self.logStackState();
            }
        }

        if (decoded_inst.opcode == .HALT) {
            self.logger.debug("Executing HALT instruction", .{}, metadata);
            self.running = false;
            return;
        }

        try self.execution_count.put(self.pc, (self.execution_count.get(self.pc) orelse 0) + 1);

        // Log before execution (using decoded_inst)
        if (self.debug_mode) {
            switch (decoded_inst.opcode) {
                .LOAD => {
                    self.logger.debug(
                        "Before instruction {any}: immediate={d}",
                        .{ decoded_inst, decoded_inst.operand1 },
                        metadata,
                    );
                },
                .ADD, .SUB, .MUL, .DIV, .MOD, .CMP => {
                    if (decoded_inst.operand1 < REGISTER_COUNT and decoded_inst.operand2 < REGISTER_COUNT) {
                        self.logger.debug(
                            "Before instruction {any}: R{d}={d}, R{d}={d}",
                            .{
                                decoded_inst,
                                decoded_inst.operand1,
                                self.registers[decoded_inst.operand1],
                                decoded_inst.operand2,
                                self.registers[decoded_inst.operand2],
                            },
                            metadata,
                        );
                    } else {
                        self.logger.debug(
                            "Before instruction {any}: invalid register operands",
                            .{decoded_inst},
                            metadata,
                        );
                    }
                },
                .STORE, .LOAD_MEM => {
                    self.logger.debug(
                        "Before instruction {any}: memory address={d}",
                        .{ decoded_inst, decoded_inst.operand1 },
                        metadata,
                    );
                },
                .MEMCPY => {
                    self.logger.debug(
                        "Before instruction {any}: dest={d}, src={d}, len={d}",
                        .{ decoded_inst, decoded_inst.dest_reg, decoded_inst.operand1, decoded_inst.operand2 },
                        metadata,
                    );
                },
                .PUSH => {
                    if (decoded_inst.dest_reg < REGISTER_COUNT) {
                        self.logger.debug(
                            "Before instruction {any}: R{d}={d}",
                            .{ decoded_inst, decoded_inst.dest_reg, self.registers[decoded_inst.dest_reg] },
                            metadata,
                        );
                    }
                },
                .POP => {
                    self.logger.debug(
                        "Before instruction {any}: dest_reg={d}",
                        .{ decoded_inst, decoded_inst.dest_reg },
                        metadata,
                    );
                },
                else => {
                    self.logger.debug(
                        "Before instruction {any}",
                        .{decoded_inst},
                        metadata,
                    );
                },
            }
        }

        if (self.debug_mode) {
            // Only log result for instructions that modify registers
            if (decoded_inst.dest_reg < REGISTER_COUNT) {
                switch (decoded_inst.opcode) {
                    .LOAD, .ADD, .SUB, .MUL, .DIV, .MOD, .LOAD_MEM, .POP => {
                        self.logger.debug(
                            "After instruction: R{d}={d}",
                            .{ decoded_inst.dest_reg, self.registers[decoded_inst.dest_reg] },
                            metadata,
                        );
                    },
                    else => {},
                }
            }
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

test "Ziglet Fuzz Test" {
    // Konfiguration
    const config = .{
        .num_instructions = 20, // Reduziert von 50
        .num_iterations = 5,
        .debug_mode = false, // Debug-Logging deaktiviert
        .max_steps = 1000, // Verhindert unendliche Schleifen
    };

    std.debug.print("\nStarting Fuzz Test...\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var rng = std.Random.DefaultPrng.init(@intCast(std.time.nanoTimestamp()));

    const random = rng.random();

    // VM mit minimalem Logging
    var vm = try VM.initWithConfig(allocator, .{
        .debug_mode = config.debug_mode,
        .log_config = .{
            .min_level = .info,
            .enable_async = true,
            .buffer_size = 1024,
            .log_file_path = null, // Kein File-Logging
        },
    });
    defer vm.deinit();

    var instructions = try allocator.alloc(Instruction, config.num_instructions);
    defer allocator.free(instructions);

    var success_count: usize = 0;
    var error_count: usize = 0;

    // Reduzierter Befehlssatz für schnellere Tests
    const all_opcodes = [_]OpCode{ .LOAD, .ADD, .SUB, .MUL, .DIV, .MOD, .CMP, .HALT };

    for (0..config.num_iterations) |iteration| {
        std.debug.print("\rTesting {d}/{d}...", .{ iteration + 1, config.num_iterations });

        // Generiere Instruktionen
        for (instructions[0 .. config.num_instructions - 1], 0..) |*inst, i| {
            const randIndex = random.uintLessThan(usize, all_opcodes.len - 1); // Exclude HALT
            inst.opcode = all_opcodes[randIndex];
            inst.dest_reg = @intCast(random.uintLessThan(u8, REGISTER_COUNT));

            switch (inst.opcode) {
                .LOAD => {
                    inst.operand1 = random.uintLessThan(u32, 100); // Kleinere Zahlen
                    inst.operand2 = 0;
                },
                .ADD, .SUB, .MUL => {
                    inst.operand1 = random.uintLessThan(u32, REGISTER_COUNT);
                    inst.operand2 = random.uintLessThan(u32, REGISTER_COUNT);
                },
                .DIV, .MOD => {
                    inst.operand1 = random.uintLessThan(u32, REGISTER_COUNT);
                    inst.operand2 = random.uintLessThan(u32, REGISTER_COUNT);

                    // Stelle sicher, dass der Divisor nicht 0 ist
                    const preload = Instruction{
                        .opcode = .LOAD,
                        .dest_reg = @intCast(inst.operand2),
                        .operand1 = 1 + random.uintLessThan(u32, 10),
                        .operand2 = 0,
                    };
                    if (i > 0) {
                        instructions[i - 1] = preload;
                    }
                },
                else => {
                    inst.operand1 = random.uintLessThan(u32, REGISTER_COUNT);
                    inst.operand2 = random.uintLessThan(u32, REGISTER_COUNT);
                },
            }
        }

        // Letzte Instruktion ist HALT
        instructions[config.num_instructions - 1] = .{
            .opcode = .HALT,
            .dest_reg = 0,
            .operand1 = 0,
            .operand2 = 0,
        };

        try vm.loadProgram(instructions);

        vm.execute() catch |err| {
            error_count += 1;
            switch (err) {
                error.IntegerOverflow, error.IntegerUnderflow, error.DivisionByZero => {
                    // Diese Fehler sind erwartete Ergebnisse des Fuzzing
                    std.debug.print("\nExpected error in iteration {d}: {s}\n", .{ iteration + 1, @errorName(err) });
                },
                else => {
                    // Unerwartete Fehler sollten den Test fehlschlagen lassen
                    std.debug.print("\nUnexpected error in iteration {d}: {s}\n", .{ iteration + 1, @errorName(err) });
                    return err;
                },
            }
            continue;
        };

        success_count += 1;
    }

    std.debug.print("\n\nFuzz Test Complete:\n", .{});
    std.debug.print("  Successful: {d}/{d}\n", .{ success_count, config.num_iterations });
    std.debug.print("  Failed: {d}/{d}\n", .{ error_count, config.num_iterations });
}
