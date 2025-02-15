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

pub const Instruction = instruction_types.Instruction;
pub const OpCode = instruction_types.OpCode;
pub const REGISTER_COUNT = instruction_types.REGISTER_COUNT;

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

        pub fn format(
            self: DebugInfo,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.print(
                "Instructions executed: {}\n" ++
                    "Stack depth: {}\n",
                .{
                    self.instruction_count,
                    self.stack_depth,
                },
            );

            if (self.last_instruction) |inst| {
                try writer.print("Last instruction: {}\n", .{inst});
            }
        }
    };

    pub fn getDebugInfo(self: *VM) DebugInfo {
        return .{
            .instruction_count = self.pc,
            .last_instruction = if (self.pc > 0) self.program[self.pc - 1] else null,
            .stack_depth = self.stack.items.len,
        };
    }
    /// Initialize a new VM
    /// Initialize a new VM
    pub fn init(allocator: std.mem.Allocator) !*VM {
        const default_memory_size = 1024 * 64; // 64KB
        const memory = try allocator.alloc(u8, default_memory_size);

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
            .memory_size = default_memory_size,
            .debug_mode = false,
            .instruction_cache = instruction_cache,
            .execution_count = execution_count,
        };
        return vm;
    }
    /// Enable or disable debug mode
    pub fn setDebugMode(self: *VM, enable: bool) void {
        self.debug_mode = enable;
    }
    /// Clean up VM resources
    pub fn deinit(self: *VM) void {
        self.allocator.free(self.memory);
        self.stack.deinit();
        self.instruction_cache.deinit();
        self.execution_count.deinit();
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
        if (self.program.len == 0) {
            return createError(
                error.InvalidInstruction,
                "executing program",
                "No program loaded",
                "Load a program before executing",
                null,
            );
        }

        if (self.debug_mode) {
            std.debug.print("Executing program with {} instructions\n", .{self.program.len});
        }

        self.running = true;
        while (self.running and self.pc < self.program.len) {
            if (self.debug_mode) {
                std.debug.print("Executing instruction at PC={}: {}\n", .{ self.pc, self.program[self.pc] });
            }

            try self.execution_count.put(self.pc, (self.execution_count.get(self.pc) orelse 0) + 1);

            try self.executeInstruction(self.program[self.pc]);
            self.pc += 1;

            if (self.pc % 1000 == 0) {
                try self.optimizeHotPaths();
            }
        }

        // Print debug info at the end if in debug mode
        if (self.debug_mode) {
            std.debug.print("\nDebug Info:\n{}", .{self.getDebugInfo()});
        }
    }

    /// Execute a single instruction
    fn executeInstruction(self: *VM, inst: instruction_types.Instruction) !void {
        if (inst.opcode == .HALT) {
            self.running = false;
            return;
        }
        try decoder.decode(inst, self);
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
