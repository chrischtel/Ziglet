//! Simple example demonstrating basic Ziglet VM usage
const std = @import("std");
const ziglet = @import("ziglet");
const Instruction = ziglet.Instruction;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var vm = try ziglet.VM.init(allocator);
    defer vm.deinit();

    // Get debug mode from command line arguments
    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    defer args.deinit();
    _ = args.skip(); // Skip program name

    // Enable debug mode if --debug flag is present
    const debug_mode = if (args.next()) |arg|
        std.mem.eql(u8, arg, "--debug")
    else
        false;

    vm.setDebugMode(debug_mode);

    // Create and run program
    const program = &[_]ziglet.Instruction{
        .{ .opcode = .LOAD, .dest_reg = 1, .operand1 = 5, .operand2 = 0 },
        .{ .opcode = .LOAD, .dest_reg = 2, .operand1 = 10, .operand2 = 0 },
        .{ .opcode = .ADD, .dest_reg = 3, .operand1 = 1, .operand2 = 2 },
        .{ .opcode = .HALT, .dest_reg = 0, .operand1 = 0, .operand2 = 0 },
    };

    try vm.loadProgram(program);
    try vm.execute();

    // Always print the final result
    const result = try vm.getRegister(3);
    std.debug.print("\nResult: {}\n", .{result});
}
