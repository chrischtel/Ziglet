//! Defines the instruction set and their implementations

const std = @import("std");
const types = @import("types.zig");
const VMError = @import("../error.zig").VMError;
const createError = @import("../error.zig").createError;

/// Validates register index
pub fn validateRegister(reg: u8) VMError!void {
    if (reg >= types.REGISTER_COUNT) {
        return createError(
            error.InvalidInstruction,
            "validating register",
            "Invalid register number",
            "Use registers 0 through 15",
            null,
        );
    }
}

/// Instruction implementations
pub const Instructions = struct {
    /// LOAD Rx, immediate_value
    pub fn load(registers: []u32, dest: u8, value: u32) VMError!void {
        try validateRegister(dest);
        registers[dest] = value;
    }

    /// ADD Rx, Ry, Rz
    pub fn add(registers: []u32, dest: u8, src1: u8, src2: u8) VMError!void {
        try validateRegister(dest);
        try validateRegister(src1);
        try validateRegister(src2);
        // Get values from source registers and store result in dest register
        registers[dest] = registers[src1] + registers[src2];
    }

    /// SUB Rx, Ry, Rz
    pub fn sub(registers: []u32, dest: u8, src1: u8, src2: u8) VMError!void {
        try validateRegister(dest);
        try validateRegister(src1);
        try validateRegister(src2);
        // Get values from source registers and store result in dest register
        registers[dest] = registers[src1] - registers[src2];
    }
};
