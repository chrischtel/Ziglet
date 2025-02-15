//! Common types used for instruction handling

const std = @import("std");

/// Maximum number of registers
pub const REGISTER_COUNT = 16;

/// Basic instruction set for our first prototype
pub const OpCode = enum(u8) {
    HALT = 0,
    LOAD = 1, // LOAD Rx, immediate_value
    ADD = 2, // ADD Rx, Ry, Rz
    SUB = 3, // SUB Rx, Ry, Rz
    MUL = 4, // Multiplication
    DIV = 5, // Division
    MOD = 6, // Modulo
    CMP = 7, // Compare
    JMP = 8, // Unconditional jump
    JEQ = 9, // Jump if equal
    JNE = 10, // Jump if not equal
    JGT = 11, // Jump if greater than
    JLT = 12,
    JGE = 13, // Added JGE
    PUSH = 14,
    POP = 15,
    STORE = 16, // Store value to memory
    LOAD_MEM = 17, // Load value from memory
    MEMCPY = 18, // Copy memory region
};

pub const Instruction = struct {
    opcode: OpCode,
    dest_reg: u8,
    operand1: u32,
    operand2: u32,

    pub fn format(
        self: Instruction,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("{s} dest_reg={}, op1={}, op2={}", .{
            @tagName(self.opcode),
            self.dest_reg,
            self.operand1,
            self.operand2,
        });
    }
};
