//! Common types used for instruction handling

/// Maximum number of registers
pub const REGISTER_COUNT = 16;

/// Basic instruction set for our first prototype
pub const OpCode = enum(u8) {
    HALT = 0,
    LOAD = 1, // LOAD Rx, immediate_value
    ADD = 2, // ADD Rx, Ry, Rz
    SUB = 3, // SUB Rx, Ry, Rz
    // We can add more opcodes here
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
