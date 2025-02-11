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

/// Maximum number of registers
pub const REGISTER_COUNT = 16;

/// Basic instruction set for our first prototype
pub const OpCode = enum(u8) {
    HALT = 0,
    LOAD = 1, // LOAD Rx, immediate_value
    ADD = 2, // ADD Rx, Ry, Rz
    SUB = 3, // SUB Rx, Ry, Rz
};

/// Represents a single instruction
pub const Instruction = struct {
    opcode: OpCode,
    // For LOAD: dest_reg, immediate_value, unused
    // For ADD/SUB: dest_reg, src_reg1, src_reg2
    dest_reg: u8,
    operand1: u32,
    operand2: u32,
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

    /// Initialize a new VM
    pub fn init(allocator: std.mem.Allocator) !*VM {
        const vm = try allocator.create(VM);
        vm.* = VM{
            .registers = [_]u32{0} ** REGISTER_COUNT,
            .pc = 0,
            .program = &[_]Instruction{},
            .allocator = allocator,
            .running = false,
        };
        return vm;
    }

    /// Clean up VM resources
    pub fn deinit(self: *VM) void {
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

        self.running = true;
        while (self.running and self.pc < self.program.len) {
            try self.executeInstruction(self.program[self.pc]);
            self.pc += 1;
        }
    }

    /// Execute a single instruction
    fn executeInstruction(self: *VM, instruction: Instruction) !void {
        // Validate register indices
        if (instruction.dest_reg >= REGISTER_COUNT) {
            return createError(
                error.InvalidInstruction,
                "executing instruction",
                "Invalid destination register",
                "Use registers 0 through 15",
                null,
            );
        }

        switch (instruction.opcode) {
            .HALT => self.running = false,
            .LOAD => {
                self.registers[instruction.dest_reg] = @intCast(instruction.operand1);
            },
            .ADD => {
                if (instruction.operand1 >= REGISTER_COUNT or
                    instruction.operand2 >= REGISTER_COUNT)
                {
                    return createError(
                        error.InvalidInstruction,
                        "executing ADD instruction",
                        "Invalid source register",
                        "Use registers 0 through 15",
                        null,
                    );
                }
                self.registers[instruction.dest_reg] =
                    self.registers[instruction.operand1] +
                    self.registers[instruction.operand2];
            },
            .SUB => {
                if (instruction.operand1 >= REGISTER_COUNT or
                    instruction.operand2 >= REGISTER_COUNT)
                {
                    return createError(
                        error.InvalidInstruction,
                        "executing SUB instruction",
                        "Invalid source register",
                        "Use registers 0 through 15",
                        null,
                    );
                }
                self.registers[instruction.dest_reg] =
                    self.registers[instruction.operand1] -
                    self.registers[instruction.operand2];
            },
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
