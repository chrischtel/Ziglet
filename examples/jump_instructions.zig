//! Loop example showing how to use Ziglet VM for control flow
//! This program counts from 0 to a target number, demonstrating jumps and comparisons

const std = @import("std");
const ziglet = @import("ziglet");

// Helper function to create a program that counts up to target number
fn createCounterProgram(
    allocator: *std.mem.Allocator,
    target: u32,
) ![]const ziglet.Instruction {
    const num_insts = 8;
    var program = try allocator.alloc(ziglet.Instruction, num_insts);

    // Initialize counter (R1) to 0
    program[0] = .{ .opcode = .LOAD, .dest_reg = 1, .operand1 = 0, .operand2 = 0 };

    // Load target value into R2
    program[1] = .{ .opcode = .LOAD, .dest_reg = 2, .operand1 = target, .operand2 = 0 };

    // Load increment value (1) into R3
    program[2] = .{ .opcode = .LOAD, .dest_reg = 3, .operand1 = 1, .operand2 = 0 };

    // Compare counter (R1) with target (R2)
    program[3] = .{ .opcode = .CMP, .dest_reg = 0, .operand1 = 1, .operand2 = 2 };

    // If counter >= target, jump to end (instruction 7)
    program[4] = .{ .opcode = .JGE, .dest_reg = 0, .operand1 = 7, .operand2 = 0 };

    // Add 1 to counter
    program[5] = .{ .opcode = .ADD, .dest_reg = 1, .operand1 = 1, .operand2 = 3 };

    // Jump back to compare (instruction 3)
    program[6] = .{ .opcode = .JMP, .dest_reg = 0, .operand1 = 3, .operand2 = 0 };

    // End: Store final count in result register (R4)
    program[7] = .{ .opcode = .HALT, .dest_reg = 0, .operand1 = 0, .operand2 = 0 };

    return program;
}

pub fn main() !void {
    // Get target number from command line or use default
    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    defer args.deinit();

    // Skip program name
    _ = args.skip();

    // Get target number or use default
    const target: u32 = if (args.next()) |num|
        try std.fmt.parseInt(u32, num, 10)
    else
        5;

    // Initialize VM
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var vm = try ziglet.VM.init(allocator);
    defer vm.deinit();

    // Create and run program
    const program = try createCounterProgram(@constCast(&allocator), target);
    defer allocator.free(program);

    try vm.loadProgram(program);
    vm.setDebugMode(false);

    std.debug.print("\nStarting counter loop to {}\n", .{target});
    std.debug.print("Executing program...\n\n", .{});

    // Print initial state
    const initial_count = try vm.getRegister(1);
    std.debug.print("Initial count: {}\n", .{initial_count});

    try vm.execute();

    // Get and print final counter value
    const final_count = try vm.getRegister(1);

    std.debug.print("\nLoop Results:\n", .{});
    std.debug.print("Target: {}\n", .{target});
    std.debug.print("Final Count: {}\n", .{final_count});
    std.debug.print("Loop completed successfully!\n", .{});
}
