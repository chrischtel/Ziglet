//! Calculator example showing how to use Ziglet VM for arithmetic
const std = @import("std");
const ziglet = @import("ziglet");

// Helper function to create instructions
fn createProgram(
    allocator: *std.mem.Allocator,
    a: u32,
    b: u32,
) ![]const ziglet.Instruction {
    const num_insts = 5;
    var program = try allocator.alloc(ziglet.Instruction, num_insts);
    program[0] = .{ .opcode = .LOAD, .dest_reg = 1, .operand1 = a, .operand2 = 0 };
    program[1] = .{ .opcode = .LOAD, .dest_reg = 2, .operand1 = b, .operand2 = 0 };
    program[2] = .{ .opcode = .ADD, .dest_reg = 3, .operand1 = 1, .operand2 = 2 };
    program[3] = .{ .opcode = .SUB, .dest_reg = 4, .operand1 = 1, .operand2 = 2 };
    program[4] = .{ .opcode = .HALT, .dest_reg = 0, .operand1 = 0, .operand2 = 0 };
    return program;
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

    var vm = try ziglet.VM.initWithConfig(allocator, .{ .debug_mode = true, .log_config = .{
        .log_file_path = "logs/calc.log",
    } });
    defer vm.deinit();

    // Create and run program
    const program = try createProgram(@constCast(&allocator), a, b);
    defer allocator.free(program);
    try vm.loadProgram(program);
    try vm.execute();

    // Get and print results
    const sum = try vm.getRegister(3);
    const diff = try vm.getRegister(4);

    std.debug.print("Calculator Results:\n", .{});
    std.debug.print("{} + {} = {}\n", .{ a, b, sum });
    std.debug.print("{} - {} = {}\n", .{ a, b, diff });
}
