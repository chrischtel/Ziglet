//! Common types used for instruction handling

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
    PUSH = 12, // Push to stack
    POP = 13, // Pop from stack
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
