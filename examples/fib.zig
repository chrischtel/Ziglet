const std = @import("std");
const ziglet = @import("ziglet");

/// a fibonacci non recursive program
///
/// Ruby example
///
/// def fib(n)
///     return n if n < 2
///
///     current = 0
///     prev1 = 0
///     prev2 =  1
///
///     for _ in 2..(n + 1) do
///         current = prev1 + prev2
///         prev2 = prev1
///         prev1 = current
///     end
///
///     current
/// end
fn createFibProgram(
    allocator: *std.mem.Allocator,
    n: u32,
) ![]const ziglet.Instruction {
    const num_insts = 22;
    const return_instruction = 21;
    var program = try allocator.alloc(ziglet.Instruction, num_insts);
    // n
    const r_n = 2;
    program[0] = .{ .opcode = .LOAD, .dest_reg = r_n, .operand1 = n, .operand2 = 0 };
    // const 2
    const c_2 = 6;
    program[1] = .{ .opcode = .LOAD, .dest_reg = c_2, .operand1 = 2, .operand2 = 0 };
    // return n if n < 2
    // compare n with 2
    program[2] = .{ .opcode = .CMP, .dest_reg = 0, .operand1 = r_n, .operand2 = c_2 };
    // < if true, jump to line 19
    program[3] = .{ .opcode = .JLT, .dest_reg = 0, .operand1 = 19, .operand2 = 0 };
    // loop counter = 2
    const r_counter = 1;
    program[4] = .{ .opcode = .LOAD, .dest_reg = r_counter, .operand1 = 2, .operand2 = 0 };
    // current = 0
    const r_current = 3;
    program[5] = .{ .opcode = .LOAD, .dest_reg = r_current, .operand1 = 0, .operand2 = 0 };
    // prev1 = 0
    const r_prev1 = 4;
    program[6] = .{ .opcode = .LOAD, .dest_reg = r_prev1, .operand1 = 0, .operand2 = 0 };
    // prev2 = 1
    const r_prev2 = 5;
    program[7] = .{ .opcode = .LOAD, .dest_reg = r_prev2, .operand1 = 1, .operand2 = 0 };
    // const 1
    const c_1 = 7;
    program[8] = .{ .opcode = .LOAD, .dest_reg = c_1, .operand1 = 1, .operand2 = 0 };
    // n + 1
    const r_n_1 = 8;
    program[9] = .{ .opcode = .LOAD, .dest_reg = r_n_1, .operand1 = n + 1, .operand2 = 0 };

    // for _ in 2..(n + 1) do
    program[10] = .{ .opcode = .CMP, .dest_reg = 0, .operand1 = r_counter, .operand2 = r_n_1 };
    program[11] = .{ .opcode = .JGT, .dest_reg = 0, .operand1 = return_instruction, .operand2 = 0 };
    // current = prev1 + prev2
    program[12] = .{ .opcode = .ADD, .dest_reg = r_current, .operand1 = r_prev1, .operand2 = r_prev2 };
    // prev2 = prev1
    program[13] = .{ .opcode = .PUSH, .dest_reg = r_prev1, .operand1 = 0, .operand2 = 0 };
    program[14] = .{ .opcode = .POP, .dest_reg = r_prev2, .operand1 = 0, .operand2 = 0 };
    // prev1 = current
    program[15] = .{ .opcode = .PUSH, .dest_reg = r_current, .operand1 = 0, .operand2 = 0 };
    program[16] = .{ .opcode = .POP, .dest_reg = r_prev1, .operand1 = 0, .operand2 = 0 };
    // increment counter
    program[17] = .{ .opcode = .ADD, .dest_reg = r_counter, .operand1 = r_counter, .operand2 = c_1 };
    // check again to form a loop
    program[18] = .{ .opcode = .JMP, .dest_reg = 0, .operand1 = 10, .operand2 = 0 };
    // to return early
    // current = n
    program[19] = .{ .opcode = .PUSH, .dest_reg = r_n, .operand1 = 0, .operand2 = 0 };
    program[20] = .{ .opcode = .POP, .dest_reg = r_current, .operand1 = 0, .operand2 = 0 };
    // return n
    // End: Return on R3
    program[return_instruction] = .{ .opcode = .HALT, .dest_reg = 0, .operand1 = 0, .operand2 = 0 };
    return program;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var vm = try ziglet.VM.init(allocator);
    defer vm.deinit();
    const n = 47;
    const program = try createFibProgram(@constCast(&allocator), n);
    defer allocator.free(program);

    try vm.loadProgram(program);
    try vm.execute();
    const result = try vm.getRegister(3);
    try stdout.print("fib({d}) = {d}\n", .{ n, result });
}
