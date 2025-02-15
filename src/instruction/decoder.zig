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
            std.debug.print("LOAD R{}, {}\n", .{ instruction.dest_reg, instruction.operand1 });
            try Instructions.load(
                registers,
                instruction.dest_reg,
                instruction.operand1,
            );
        },

        .ADD => {
            std.debug.print("ADD R{}, R{}, R{}\n", .{
                instruction.dest_reg,
                instruction.operand1,
                instruction.operand2,
            });
            try Instructions.add(
                registers,
                instruction.dest_reg,
                @intCast(instruction.operand1),
                @intCast(instruction.operand2),
            );
        },

        .SUB => {
            std.debug.print("SUB R{}, R{}, R{}\n", .{
                instruction.dest_reg,
                instruction.operand1,
                instruction.operand2,
            });
            try Instructions.sub(
                registers,
                instruction.dest_reg,
                @intCast(instruction.operand1),
                @intCast(instruction.operand2),
            );
        },

        .MUL => {
            std.debug.print("MUL R{}, R{}, R{}\n", .{
                instruction.dest_reg,
                instruction.operand1,
                instruction.operand2,
            });
            try Instructions.mul(
                registers,
                instruction.dest_reg,
                @intCast(instruction.operand1),
                @intCast(instruction.operand2),
            );
        },

        .DIV => {
            std.debug.print("DIV R{}, R{}, R{}\n", .{
                instruction.dest_reg,
                instruction.operand1,
                instruction.operand2,
            });
            try Instructions.div(
                registers,
                instruction.dest_reg,
                @intCast(instruction.operand1),
                @intCast(instruction.operand2),
            );
        },

        .MOD => {
            std.debug.print("MOD R{}, R{}, R{}\n", .{
                instruction.dest_reg,
                instruction.operand1,
                instruction.operand2,
            });
            try Instructions.mod(
                registers,
                instruction.dest_reg,
                @intCast(instruction.operand1),
                @intCast(instruction.operand2),
            );
        },

        .CMP => {
            std.debug.print("CMP R{}, R{}\n", .{
                instruction.operand1,
                instruction.operand2,
            });
            try Instructions.cmp(
                registers,
                vm,
                @intCast(instruction.operand1),
                @intCast(instruction.operand2),
            );
        },

        .JMP => {
            std.debug.print("JMP {}\n", .{instruction.operand1});
            try Instructions.jmp(vm, instruction.operand1);
        },

        .JEQ => {
            std.debug.print("JEQ {}\n", .{instruction.operand1});
            try Instructions.jeq(vm, instruction.operand1);
        },

        .JNE => {
            std.debug.print("JNE {}\n", .{instruction.operand1});
            try Instructions.jne(vm, instruction.operand1);
        },

        .JGT => {
            std.debug.print("JGT {}\n", .{instruction.operand1});
            try Instructions.jgt(vm, instruction.operand1);
        },

        .JLT => {
            std.debug.print("JLT {}\n", .{instruction.operand1});
            try Instructions.jlt(vm, instruction.operand1);
        },

        .JGE => {
            std.debug.print("JGE {}\n", .{instruction.operand1});
            try Instructions.jge(vm, instruction.operand1);
        },

        .PUSH => {
            std.debug.print("PUSH R{}\n", .{instruction.dest_reg});
            try Instructions.push(
                registers,
                vm,
                instruction.dest_reg,
            );
        },

        .POP => {
            std.debug.print("POP R{}\n", .{instruction.dest_reg});
            try Instructions.pop(
                registers,
                vm,
                instruction.dest_reg,
            );
        },
    }
}
