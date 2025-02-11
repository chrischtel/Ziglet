//! Handles decoding and validation of instructions

const std = @import("std");
const types = @import("types.zig");
const VMError = @import("../error.zig").VMError;
const createError = @import("../error.zig").createError;
const Instructions = @import("set.zig").Instructions;

/// Decodes and executes a single instruction
pub fn decode(
    instruction: types.Instruction,
    registers: []u32,
) VMError!void {
    switch (instruction.opcode) {
        .HALT => return,
        .LOAD => try Instructions.load(
            registers,
            instruction.dest_reg,
            instruction.operand1,
        ),
        .ADD => try Instructions.add(
            registers,
            instruction.dest_reg,
            @intCast(instruction.operand1),
            @intCast(instruction.operand2),
        ),
        .SUB => try Instructions.sub(
            registers,
            instruction.dest_reg,
            @intCast(instruction.operand1),
            @intCast(instruction.operand2),
        ),
    }
}
