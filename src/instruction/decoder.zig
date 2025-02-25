//! Handles decoding and validation of instructions

const std = @import("std");
const types = @import("types.zig");
const VMError = @import("../error.zig").VMError;
const createError = @import("../error.zig").createError;
const Instructions = @import("set.zig").Instructions;
const VM = @import("../core/vm.zig").VM;

/// Decodes and executes a single instruction
pub fn decode(
    instruction: types.Instruction,
    vm: *VM,
) VMError!void {
    const registers = vm.registers[0..];

    switch (instruction.opcode) {
        .HALT => return,

        .LOAD => {
            try Instructions.load(
                registers,
                instruction.dest_reg,
                instruction.operand1,
            );
        },

        .ADD => {
            try Instructions.add(
                registers,
                instruction.dest_reg,
                @intCast(instruction.operand1),
                @intCast(instruction.operand2),
            );
        },

        .SUB => {
            try Instructions.sub(
                registers,
                instruction.dest_reg,
                @intCast(instruction.operand1),
                @intCast(instruction.operand2),
            );
        },

        .MUL => {
            try Instructions.mul(
                registers,
                instruction.dest_reg,
                @intCast(instruction.operand1),
                @intCast(instruction.operand2),
            );
        },

        .DIV => {
            try Instructions.div(
                registers,
                instruction.dest_reg,
                @intCast(instruction.operand1),
                @intCast(instruction.operand2),
            );
        },

        .MOD => {
            try Instructions.mod(
                registers,
                instruction.dest_reg,
                @intCast(instruction.operand1),
                @intCast(instruction.operand2),
            );
        },

        .CMP => {
            try Instructions.cmp(
                registers,
                vm,
                @intCast(instruction.operand1),
                @intCast(instruction.operand2),
            );
        },

        .JMP => try Instructions.jmp(vm, instruction.operand1),

        .JEQ => try Instructions.jeq(vm, instruction.operand1),

        .JNE => try Instructions.jne(vm, instruction.operand1),

        .JGT => try Instructions.jgt(vm, instruction.operand1),

        .JLT => try Instructions.jlt(vm, instruction.operand1),

        .JGE => try Instructions.jge(vm, instruction.operand1),

        .PUSH => {
            try Instructions.push(
                registers,
                vm,
                instruction.dest_reg,
            );
        },

        .POP => {
            try Instructions.pop(
                registers,
                vm,
                instruction.dest_reg,
            );
        },

        .STORE => {
            try Instructions.store(
                vm,
                instruction.dest_reg,
                instruction.operand1,
            );
        },

        .LOAD_MEM => {
            try Instructions.loadMem(
                vm,
                instruction.dest_reg,
                instruction.operand1,
            );
        },

        .MEMCPY => {
            try Instructions.memcpy(
                vm,
                instruction.dest_reg,
                instruction.operand1,
                instruction.operand2,
            );
        },
    }
}
