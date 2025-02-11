//! Simple example demonstrating basic Ziglet VM usage
const std = @import("std");
const ziglet = @import("ziglet");

pub fn main() !void {
    // Initialize VM
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var vm = try ziglet.VM.init(allocator);
    defer vm.deinit();

    // Create a simple program that:
    // 1. Loads 5 into R1
    // 2. Loads 10 into R2
    // 3. Adds R1 and R2, stores result in R3
    // 4. Subtracts R1 from R2, stores result in R4
    const program = &[_]ziglet.Instruction{
        .{ .opcode = .LOAD, .dest_reg = 1, .operand1 = 5, .operand2 = 0 },
        .{ .opcode = .LOAD, .dest_reg = 2, .operand1 = 10, .operand2 = 0 },
        .{ .opcode = .ADD, .dest_reg = 3, .operand1 = 1, .operand2 = 2 },
        .{ .opcode = .SUB, .dest_reg = 4, .operand1 = 2, .operand2 = 1 },
        .{ .opcode = .HALT, .dest_reg = 0, .operand1 = 0, .operand2 = 0 },
    };

    // Load and execute the program
    try vm.loadProgram(program);
    try vm.execute();

    // Print results
    const r3 = try vm.getRegister(3); // Should be 15 (5 + 10)
    const r4 = try vm.getRegister(4); // Should be 5 (10 - 5)

    std.debug.print("Results:\n", .{});
    std.debug.print("R3 (5 + 10) = {}\n", .{r3});
    std.debug.print("R4 (10 - 5) = {}\n", .{r4});
}
