//! Ziglet - A minimal virtual machine implementation in Zig
//! This root file ensures all modules are compiled and exports the public API

const std = @import("std");

// Import all modules that need to be compiled
const vm_mod = @import("core/vm.zig");
const error_mod = @import("error.zig");
const instruction_types = @import("instruction/types.zig");
const instruction_decoder = @import("instruction/decoder.zig");
const instruction_set = @import("instruction/set.zig");

// Re-export public types and functions
pub const VM = vm_mod.VM;
pub const Error = error_mod.Error;
pub const VMError = error_mod.VMError;
pub const createError = error_mod.createError;

pub const Instruction = instruction_types.Instruction;
pub const OpCode = instruction_types.OpCode;
pub const REGISTER_COUNT = instruction_types.REGISTER_COUNT;

comptime {
    // Verify our modules compile
    _ = vm_mod;
    _ = error_mod;
    _ = instruction_types;
    _ = instruction_decoder;
    _ = instruction_set;
}

// Optional: Add tests that exercise the public API
test {
    // This will run all tests in our modules
    std.testing.refAllDecls(@This());
}
