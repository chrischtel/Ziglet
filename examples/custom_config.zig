const std = @import("std");
const ziglet = @import("ziglet"); // Module that exports VM, VMConfig, Instruction, etc.
const VM = ziglet.VM;
const VMConfig = ziglet.VMConfig;
const Instruction = ziglet.Instruction;

/// Helper to create a simple arithmetic program:
///   LOAD R1, 5
///   LOAD R2, 10
///   ADD R3, R1, R2
///   HALT
fn createProgram(allocator: *std.mem.Allocator) ![]const Instruction {
    const num_insts = 4;
    var program = try allocator.alloc(Instruction, num_insts);
    program[0] = .{ .opcode = .LOAD, .dest_reg = 1, .operand1 = 5, .operand2 = 0 };
    program[1] = .{ .opcode = .LOAD, .dest_reg = 2, .operand1 = 10, .operand2 = 0 };
    program[2] = .{ .opcode = .ADD, .dest_reg = 3, .operand1 = 1, .operand2 = 2 };
    program[3] = .{ .opcode = .HALT, .dest_reg = 0, .operand1 = 0, .operand2 = 0 };
    return program;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    // Create a custom VM configuration.
    const customConfig = VMConfig{
        .memory_size = 1024 * 64, // 64KB memory
        .debug_mode = true, // Enable debug mode
        .log_config = .{
            .min_level = .debug,
            .enable_colors = true,
            .buffer_size = 16384, // Larger buffer size
            .log_file_path = "logs/custom_vm.log", // Custom log file for this VM
            .max_file_size = 10 * 1024 * 1024,
            .max_rotated_files = 5,
            .enable_rotation = true,
            .enable_async = true,
            .enable_metadata = true,
        },
    };

    // Initialize the VM using our custom configuration.
    var vm = try VM.initWithConfig(allocator, customConfig);
    defer vm.deinit();

    const program = try createProgram(&allocator);
    defer allocator.free(program);

    try vm.loadProgram(program);
    try vm.execute();

    const result = try vm.getRegister(3);
    std.debug.print("Custom Config Example: 5 + 10 = {d}\n", .{result});
}
