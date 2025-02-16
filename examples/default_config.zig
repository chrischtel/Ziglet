const std = @import("std");
const ziglet = @import("ziglet"); // Module that exports VM, Instruction, etc.
const VM = ziglet.VM;
const Instruction = ziglet.Instruction;

/// Helper to create a simple arithmetic program:
///   LOAD R1, 2
///   LOAD R2, 3
///   ADD R3, R1, R2
///   HALT
fn createProgram(allocator: *std.mem.Allocator) ![]const Instruction {
    const num_insts = 4;
    var program = try allocator.alloc(Instruction, num_insts);
    program[0] = .{ .opcode = .LOAD, .dest_reg = 1, .operand1 = 2, .operand2 = 0 };
    program[1] = .{ .opcode = .LOAD, .dest_reg = 2, .operand1 = 3, .operand2 = 0 };
    program[2] = .{ .opcode = .ADD, .dest_reg = 3, .operand1 = 1, .operand2 = 2 };
    program[3] = .{ .opcode = .HALT, .dest_reg = 0, .operand1 = 0, .operand2 = 0 };
    return program;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    // Initialize the VM with default configuration.
    var vm = try VM.init(allocator);
    defer vm.deinit();

    const program = try createProgram(&allocator);
    defer allocator.free(program);

    try vm.loadProgram(program);
    try vm.execute();

    const result = try vm.getRegister(3);
    std.debug.print("Default Config Example: 2 + 3 = {d}\n", .{result});
}
