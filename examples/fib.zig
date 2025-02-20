const std = @import("std");
const ziglet = @import("ziglet");
const stdout = std.io.getStdOut().writer();
fn createFibProgram(
    allocator: *std.mem.Allocator,
    n: u32,
) ![]const ziglet.Instruction {
    const return_instruction = 15;
    const num_insts = 100;
    var program = try allocator.alloc(ziglet.Instruction, num_insts);
    // counter (R1) = 2
    program[0] = .{.opcode = .LOAD, .dest_reg = 1, .operand1= 2, .operand2 = 0};
    // n (R2)
    program[1] = .{.opcode = .LOAD, .dest_reg = 2, .operand1= n, .operand2 = 0};
    // current (R3) = 0
    program[2] = .{.opcode = .LOAD, .dest_reg = 3, .operand1= 0, .operand2 = 0};
    // prev1 (R4) = 0
    program[3] = .{.opcode = .LOAD, .dest_reg = 4, .operand1= 0, .operand2 = 0};
    // prev2 (R5) = 1
    program[4] = .{.opcode = .LOAD, .dest_reg = 5, .operand1= 1, .operand2 = 0};
    // const 2 (R6)
    program[5] = .{.opcode = .LOAD, .dest_reg = 6, .operand1= 2, .operand2 = 0};
    // const 1 (R7)
    program[6] = .{.opcode = .LOAD, .dest_reg = 7, .operand1= 1, .operand2 = 0};
    // return n if n < 2
    // compare n with 2 -> R2 R6
    program[7] = .{.opcode = .CMP, .dest_reg = 0, .operand1= 2, .operand2 = 6};
    // < if true, jump to line TODO proper line current = n; store no to memory 0
    program[8] = .{.opcode = .JLT, .dest_reg = 0, .operand1= 12, .operand2 = 0};
    // for _ in 2..(n + 1) do
    program[9] = .{.opcode = .CMP, .dest_reg = 0, .operand1= 1, .operand2 = 2};
    program[10] = .{.opcode = .JGT, .dest_reg = 0, .operand1= return_instruction, .operand2 = 0};
    // increment counter R1 by 1-> R1 = R1 + R7
    program[10] = .{.opcode = .ADD, .dest_reg = 1, .operand1= 1, .operand2 = 7};
    // check again to form a jump
    program[11] = .{.opcode = .JMP, .dest_reg = 0, .operand1= 9, .operand2 = 0};




    // current = n
    // store n to memory 0
    program[12] = .{.opcode = .STORE, .dest_reg = 2, .operand1= 0, .operand2 = 0};
    // load memory 0 into R3
    program[13] = .{.opcode = .LOAD_MEM, .dest_reg = 3, .operand1= 0, .operand2 = 0};
    // return n
    program[14] = .{.opcode = .JMP, .dest_reg = 0, .operand1= 12, .operand2 = 0};
    // End: Return on R3
    // TODO when we finish give it a proper number
    program[return_instruction] = .{.opcode = .HALT, .dest_reg = 0, .operand1= 0, .operand2 = 0};
    return program;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var vm = try ziglet.VM.init(allocator);
    defer vm.deinit();
    const program = try createFibProgram(@constCast(&allocator), 2);
    defer allocator.free(program);

    try vm.loadProgram(program);
    try vm.execute();
    const result = try vm.getRegister(3);
    try stdout.print("{d}\n", .{result});
}

