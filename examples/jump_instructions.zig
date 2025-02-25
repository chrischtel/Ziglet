//! Loop example showing how to use Ziglet VM for control flow with debugging
//! This program counts from 0 to a target number, demonstrating jumps and comparisons
//! along with the enhanced debugging and tracing capabilities

const std = @import("std");
const ziglet = @import("ziglet");
const debug = @import("ziglet").debug; // Import debug module

// Helper function to create a program that counts up to target number
fn createCounterProgram(
    allocator: std.mem.Allocator,
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

    // Get debug level from arguments
    const debug_level_arg = args.next();
    const debug_level: debug.TraceLevel = if (debug_level_arg) |level|
        std.meta.stringToEnum(debug.TraceLevel, level) orelse .standard
    else
        .standard;

    // Initialize VM with debug configuration
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create debug directories if needed
    try std.fs.cwd().makePath("debug");

    // Configure VM with debugging enabled
    var vm = try ziglet.VM.initWithConfig(allocator, .{
        .debug_mode = false,
        .debug_config = .{
            .enabled = true,
            .trace_level = debug_level,
            .visualizer_config = .{
                .show_registers = true,
                .show_stack = true,
                .show_memory = true,
                .memory_start = 0,
                .memory_length = 64,
                .show_color = true,
                .compact_mode = false,
            },
            .profiler_config = .{
                .enabled = true,
                .track_hot_instructions = true,
                .track_opcode_stats = true,
                .track_memory_pattern = true,
            },
            .auto_save_trace = true,
            .auto_save_profile = true,
            .trace_file_path = "debug/counter_trace.log",
            .profile_file_path = "debug/counter_profile.log",
        },
    });
    defer vm.deinit();

    // Create and run program
    const program = try createCounterProgram(allocator, target);
    defer allocator.free(program);

    try vm.loadProgram(program);

    std.debug.print("\nStarting counter loop to {}\n", .{target});
    std.debug.print("Debug level: {s}\n", .{@tagName(debug_level)});
    std.debug.print("Executing program...\n\n", .{});

    // Print initial state
    const initial_count = try vm.getRegister(1);
    std.debug.print("Initial count: {}\n", .{initial_count});

    // Execute with full trace enabled
    const start_time = std.time.milliTimestamp();
    try vm.execute();
    const end_time = std.time.milliTimestamp();

    // Print execution time
    std.debug.print("\nExecution took {} ms\n", .{end_time - start_time});

    // Get and print final counter value
    const final_count = try vm.getRegister(1);

    std.debug.print("\nLoop Results:\n", .{});
    std.debug.print("Target: {}\n", .{target});
    std.debug.print("Final Count: {}\n", .{final_count});
    std.debug.print("Loop completed successfully!\n", .{});

    // Print VM state using our visualization system
    if (vm.debug) |*d| {
        const state_dump = try d.visualizeState(vm);
        defer allocator.free(state_dump);
        std.debug.print("\nFinal VM State:\n{s}\n", .{state_dump});

        std.debug.print("\nDebug files written to:\n", .{});
        std.debug.print("- Trace: debug/counter_trace.log\n", .{});
        std.debug.print("- Profile: debug/counter_profile.log\n", .{});
    }

    // Interactive debugging demo
    try interactiveDebugDemo(vm, allocator);
}

// Optional interactive debugging demo function
fn interactiveDebugDemo(vm: *ziglet.VM, allocator: std.mem.Allocator) !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    try stdout.print("\n=== Interactive Debug Demo ===\n", .{});
    try stdout.print("Options:\n", .{});
    try stdout.print("  1. View execution trace\n", .{});
    try stdout.print("  2. View profile summary\n", .{});
    try stdout.print("  3. Exit\n", .{});

    var buffer: [16]u8 = undefined;

    while (true) {
        try stdout.print("\nChoose an option (1-3): ", .{});
        const line = try stdin.readUntilDelimiterOrEof(&buffer, '\n');
        if (line == null) break;

        const choice = std.fmt.parseInt(u8, std.mem.trim(u8, line.?, &std.ascii.whitespace), 10) catch continue;

        switch (choice) {
            1 => {
                if (vm.debug) |*d| {
                    if (d.tracer) |*t| {
                        const report = try t.generateReport();
                        defer allocator.free(report);

                        try stdout.print("\n--- Execution Trace Excerpt ---\n", .{});

                        // Print only the first 500 characters to avoid flooding the terminal
                        const excerpt_len = @min(report.len, 500);
                        try stdout.print("{s}", .{report[0..excerpt_len]});

                        if (report.len > excerpt_len) {
                            try stdout.print("\n... [truncated, see full trace in debug/counter_trace.log]\n", .{});
                        }
                    } else {
                        try stdout.print("Tracing not enabled\n", .{});
                    }
                }
            },
            2 => {
                if (vm.debug) |*d| {
                    if (d.profiler) |*p| {
                        const report = try p.generateReport();
                        defer allocator.free(report);
                        try stdout.print("\n--- Profile Summary ---\n{s}\n", .{report});
                    } else {
                        try stdout.print("Profiling not enabled\n", .{});
                    }
                }
            },
            3 => break,
            else => try stdout.print("Invalid option\n", .{}),
        }
    }

    try stdout.print("\nExiting debug demo\n", .{});
}
