//! Defines the instruction set and their implementations using the new error system

const std = @import("std");
const types = @import("types.zig");
const VMError = @import("../error.zig").VMError;
const createRuntimeError = @import("../error.zig").createRuntimeError;
const VM = @import("../core/vm.zig").VM;

/// Validates register index.
pub fn validateRegister(reg: u8) VMError!void {
    if (reg >= types.REGISTER_COUNT) {
        return createRuntimeError(error.InvalidInstruction, "validating register", "Invalid register number", "Use registers 0 through 15");
    }
}

/// Validates jump target.
pub fn validateJumpTarget(vm: *VM, target: u32) VMError!void {
    if (target >= vm.program.len) {
        return createRuntimeError(error.InvalidInstruction, "validating jump target", "Invalid jump target", "Ensure the target is within program bounds");
    }
}

/// Instruction implementations.
pub const Instructions = struct {
    /// LOAD Rx, immediate_value
    pub fn load(registers: []u32, dest: u8, value: u32) VMError!void {
        try validateRegister(dest);
        registers[dest] = value;
    }

    /// ADD Rx, Ry, Rz
    pub fn add(registers: []u32, dest: u8, src1: u8, src2: u8) VMError!void {
        try validateRegister(dest);
        try validateRegister(src1);
        try validateRegister(src2);

        const val1 = registers[src1];
        const val2 = registers[src2];
        const result = @addWithOverflow(val1, val2);
        if (result[1] == 1) {
            registers[dest] = std.math.maxInt(u32);
            return createRuntimeError(
                error.IntegerOverflow,
                "addition operation",
                "Addition would result in overflow",
                "Ensure operands don't cause overflow",
            );
        }
        registers[dest] = result[0];
    }

    /// SUB Rx, Ry, Rz
    pub fn sub(registers: []u32, dest: u8, src1: u8, src2: u8) VMError!void {
        try validateRegister(dest);
        try validateRegister(src1);
        try validateRegister(src2);
        const val1 = registers[src1];
        const val2 = registers[src2];

        // Check für Unterlauf
        if (val2 > val1) {
            registers[dest] = 0; // Oder einen anderen Minimalwert setzen
            return createRuntimeError(
                error.IntegerUnderflow,
                "subtraction operation",
                "Subtraction would result in negative value",
                "Ensure operands don't cause underflow",
            );
        }
        registers[dest] = registers[src1] - registers[src2];
    }

    /// MUL Rx, Ry, Rz
    pub fn mul(registers: []u32, dest: u8, src1: u8, src2: u8) VMError!void {
        try validateRegister(dest);
        try validateRegister(src1);
        try validateRegister(src2);

        const val1 = registers[src1];
        const val2 = registers[src2];
        const result = @mulWithOverflow(val1, val2);
        if (result[1] == 1) {
            registers[dest] = std.math.maxInt(u32);
            return createRuntimeError(
                error.IntegerOverflow,
                "multiplication operation",
                "Multiplication would result in overflow",
                "Ensure operands don't cause overflow",
            );
        }
        registers[dest] = result[0];
    }

    /// DIV Rx, Ry, Rz
    pub fn div(registers: []u32, dest: u8, src1: u8, src2: u8) VMError!void {
        try validateRegister(dest);
        try validateRegister(src1);
        try validateRegister(src2);
        if (registers[src2] == 0) {
            return createRuntimeError(error.DivisionByZero, "division operation", "Attempted to divide by zero", "Ensure the divisor is not zero");
        }
        registers[dest] = registers[src1] / registers[src2];
    }

    /// CMP Rx, Ry – Compare registers and set flag.
    pub fn cmp(registers: []u32, vm: *VM, src1: u8, src2: u8) VMError!void {
        try validateRegister(src1);
        try validateRegister(src2);
        if (registers[src1] == registers[src2]) {
            vm.cmp_flag = 0;
        } else if (registers[src1] > registers[src2]) {
            vm.cmp_flag = 1;
        } else {
            vm.cmp_flag = -1;
        }
    }

    /// PUSH Rx – Push register value to stack.
    pub fn push(registers: []u32, vm: *VM, src: u8) VMError!void {
        try validateRegister(src);
        try vm.stack.append(registers[src]);
        vm.sp += 1;
    }

    /// POP Rx – Pop value from stack to register.
    pub fn pop(registers: []u32, vm: *VM, dest: u8) VMError!void {
        try validateRegister(dest);
        if (vm.sp == 0) {
            return createRuntimeError(error.InvalidInstruction, "pop operation", "Stack is empty", "Ensure the stack has values before popping");
        }
        vm.sp -= 1;
        const popped = vm.stack.pop();

        if (@TypeOf(popped) == ?u32) {
            registers[dest] = popped orelse unreachable;
        } else {
            registers[dest] = popped;
        }
    }

    /// JMP – Unconditional jump.
    pub fn jmp(vm: *VM, target: u32) VMError!void {
        try validateJumpTarget(vm, target);
        vm.pc = target - 1; // Adjust for pc increment.
    }

    /// JEQ – Jump if equal (cmp_flag == 0).
    pub fn jeq(vm: *VM, target: u32) VMError!void {
        try validateJumpTarget(vm, target);
        if (vm.cmp_flag == 0) {
            vm.pc = target - 1;
        }
    }

    /// JNE – Jump if not equal (cmp_flag != 0).
    pub fn jne(vm: *VM, target: u32) VMError!void {
        try validateJumpTarget(vm, target);
        if (vm.cmp_flag != 0) {
            vm.pc = target - 1;
        }
    }

    /// JGT – Jump if greater than (cmp_flag > 0).
    pub fn jgt(vm: *VM, target: u32) VMError!void {
        try validateJumpTarget(vm, target);
        if (vm.cmp_flag > 0) {
            vm.pc = target - 1;
        }
    }

    /// JLT – Jump if less than (cmp_flag < 0).
    pub fn jlt(vm: *VM, target: u32) VMError!void {
        try validateJumpTarget(vm, target);
        if (vm.cmp_flag < 0) {
            vm.pc = target - 1;
        }
    }

    /// JGE – Jump if greater than or equal (cmp_flag >= 0).
    pub fn jge(vm: *VM, target: u32) VMError!void {
        try validateJumpTarget(vm, target);
        if (vm.cmp_flag >= 0) {
            vm.pc = target - 1;
        }
    }

    /// MOD Rx, Ry, Rz – Modulo.
    pub fn mod(registers: []u32, dest: u8, src1: u8, src2: u8) VMError!void {
        try validateRegister(dest);
        try validateRegister(src1);
        try validateRegister(src2);
        if (registers[src2] == 0) {
            return createRuntimeError(error.DivisionByZero, "modulo operation", "Attempted to modulo by zero", "Ensure the divisor is not zero");
        }
        registers[dest] = registers[src1] % registers[src2];
    }

    /// MEMCPY – Copy a memory region.
    pub fn memcpy(vm: *VM, dest: u32, src: u32, len: u32) VMError!void {
        if (dest >= vm.memory_size or src >= vm.memory_size or dest + len > vm.memory_size or src + len > vm.memory_size) {
            return createRuntimeError(error.MemoryAccessViolation, "memory copy operation", "Memory access out of bounds", "Ensure addresses and length are within bounds");
        }
        @memcpy(vm.memory[dest..][0..len], vm.memory[src..][0..len]);
    }

    /// STORE – Store value from register to memory.
    pub fn store(vm: *VM, reg: u8, address: u32) VMError!void {
        try validateRegister(reg);
        if (address >= vm.memory_size - 3) {
            return createRuntimeError(error.MemoryAccessViolation, "store operation", "Memory address out of bounds", "Use an address within memory bounds");
        }
        const value = vm.registers[reg];
        @memcpy(vm.memory[address..][0..4], std.mem.asBytes(&value));
    }

    /// LOAD_MEM – Load a value from memory to register.
    pub fn loadMem(vm: *VM, reg: u8, address: u32) VMError!void {
        try validateRegister(reg);
        if (address >= vm.memory_size - 3) {
            return createRuntimeError(error.MemoryAccessViolation, "load operation", "Memory address out of bounds", "Use an address within memory bounds");
        }
        var value: u32 = undefined;
        @memcpy(std.mem.asBytes(&value), vm.memory[address..][0..4]);
        vm.registers[reg] = value;
    }

    /// CALL address – Call subroutine.
    pub fn call(vm: *VM, address: u32) VMError!void {
        try validateJumpTarget(vm, address);
        try vm.stack.append(@intCast(vm.pc + 1)); // Save return address.
        vm.pc = address - 1;
    }

    /// RET – Return from subroutine.
    pub fn ret(vm: *VM) VMError!void {
        if (vm.stack.items.len == 0) {
            return createRuntimeError(error.InvalidInstruction, "return operation", "Stack is empty, no return address", "Ensure CALL before RET");
        }
        vm.pc = vm.stack.pop() orelse unreachable;
    }
};
