//! Calculator example showing how to use Ziglet VM for arithmetic
const std = @import("std");
const ziglet = @import("ziglet");

// Helper function to create instructions
fn createProgram(a: u32, b: u32) []const ziglet.Instruction {
    return &[_]ziglet.Instruction{
        // Load first number into R1
        .{ .opcode = .LOAD, .dest_reg = 1, .operand1 = a, .operand2 = 0 },
        // Load second number into R2
        .{ .opcode = .LOAD, .dest_reg = 2, .operand1 = b, .operand2 = 0 },
        // Add them into R3
        .{ .opcode = .ADD, .dest_reg = 3, .operand1 = 1, .operand2 = 2 },
        // Subtract them into R4
        .{ .opcode = .SUB, .dest_reg = 4, .operand1 = 1, .operand2 = 2 },
        // Halt
        .{ .opcode = .HALT, .dest_reg = 0, .operand1 = 0, .operand2 = 0 },
    };
}

pub fn main() !void {
    // Get numbers from command line or use defaults
    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    defer args.deinit();

    // Skip program name
    _ = args.skip();

    // Get numbers or use defaults
    const a: u32 = if (args.next()) |num|
        try std.fmt.parseInt(u32, num, 10)
    else
        5;

    const b: u32 = if (args.next()) |num|
        try std.fmt.parseInt(u32, num, 10)
    else
        3;

    // Initialize VM
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var vm = try ziglet.VM.init(allocator);
    defer vm.deinit();

    // Create and run program
    const program = createProgram(a, b);
    try vm.loadProgram(program);
    try vm.execute();

    // Get and print results
    const sum = try vm.getRegister(3);
    const diff = try vm.getRegister(4);

    std.debug.print("Calculator Results:\n", .{});
    std.debug.print("{} + {} = {}\n", .{ a, b, sum });
    std.debug.print("{} - {} = {}\n", .{ a, b, diff });
}
