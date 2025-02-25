// src/debug/tracer.zig
const std = @import("std");
const VM = @import("../core/vm.zig").VM;
const Instruction = @import("../instruction/types.zig").Instruction;

pub const TraceLevel = enum {
    none, // No tracing
    minimal, // Just instruction execution
    standard, // Instructions + register changes
    verbose, // Full state changes after each instruction
    profile, // Include timing information
};

pub const TraceEntry = struct {
    pc: usize,
    instruction: Instruction,
    registers_before: ?[16]u32 = null,
    registers_after: ?[16]u32 = null,
    stack_depth: ?usize = null,
    cmp_flag: ?i8 = null,
    execution_time_ns: ?u64 = null,
    memory_accesses: ?[]MemoryAccess = null,

    pub const MemoryAccess = struct {
        address: usize,
        is_write: bool,
        size: u8,
        value: u32,
    };
};

pub const ExecutionTracer = struct {
    allocator: std.mem.Allocator,
    level: TraceLevel,
    trace_buffer: std.ArrayList(TraceEntry),
    current_entry: ?TraceEntry = null,
    timer: std.time.Timer,
    enabled: bool,
    memory_access_buffer: std.ArrayList(TraceEntry.MemoryAccess),

    pub fn init(allocator: std.mem.Allocator, level: TraceLevel) !ExecutionTracer {
        const timer = try std.time.Timer.start();
        return ExecutionTracer{
            .allocator = allocator,
            .level = level,
            .trace_buffer = std.ArrayList(TraceEntry).init(allocator),
            .timer = timer,
            .enabled = level != .none,
            .memory_access_buffer = std.ArrayList(TraceEntry.MemoryAccess).init(allocator),
        };
    }

    pub fn deinit(self: *ExecutionTracer) void {
        self.trace_buffer.deinit();
        self.memory_access_buffer.deinit();
    }

    pub fn beginInstruction(self: *ExecutionTracer, vm: *const VM) void {
        if (!self.enabled) return;

        self.timer.reset();

        var entry = TraceEntry{
            .pc = vm.pc,
            .instruction = vm.program[vm.pc],
        };

        if (self.level == .standard or self.level == .verbose or self.level == .profile) {
            entry.registers_before = vm.registers;
            entry.stack_depth = vm.stack.items.len;
            entry.cmp_flag = vm.cmp_flag;
        }

        self.current_entry = entry;
        self.memory_access_buffer.clearRetainingCapacity();
    }

    pub fn endInstruction(self: *ExecutionTracer, vm: *const VM) !void {
        if (!self.enabled or self.current_entry == null) return;

        var entry = self.current_entry.?;

        if (self.level == .standard or self.level == .verbose or self.level == .profile) {
            entry.registers_after = vm.registers;
        }

        if (self.level == .profile) {
            entry.execution_time_ns = self.timer.read();
        }

        if (self.level == .verbose) {
            if (self.memory_access_buffer.items.len > 0) {
                const accesses = try self.allocator.alloc(TraceEntry.MemoryAccess, self.memory_access_buffer.items.len);
                @memcpy(accesses, self.memory_access_buffer.items);
                entry.memory_accesses = accesses;
            }
        }

        try self.trace_buffer.append(entry);
    }

    pub fn recordMemoryAccess(self: *ExecutionTracer, address: usize, is_write: bool, size: u8, value: u32) !void {
        if (!self.enabled or self.level != .verbose) return;

        try self.memory_access_buffer.append(.{
            .address = address,
            .is_write = is_write,
            .size = size,
            .value = value,
        });
    }

    pub fn generateReport(self: *const ExecutionTracer) ![]u8 {
        if (self.trace_buffer.items.len == 0) return &[_]u8{};

        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        const writer = buffer.writer();

        try writer.print("Execution Trace ({d} instructions)\n", .{self.trace_buffer.items.len});
        try writer.print("----------------------------------------\n", .{});

        for (self.trace_buffer.items, 0..) |entry, i| {
            try writer.print("{d}: [PC={d}] {any}", .{ i, entry.pc, entry.instruction });

            if (entry.registers_before != null) {
                try writer.print("\n  Regs before: ", .{});
                for (entry.registers_before.?, 0..) |reg, j| {
                    if (reg != 0) {
                        try writer.print("R{d}={d} ", .{ j, reg });
                    }
                }
            }

            if (entry.registers_after != null) {
                try writer.print("\n  Regs after:  ", .{});
                for (entry.registers_after.?, 0..) |reg, j| {
                    if (reg != 0) {
                        try writer.print("R{d}={d} ", .{ j, reg });
                    }
                }
            }

            if (entry.stack_depth != null) {
                try writer.print("\n  Stack depth: {d}", .{entry.stack_depth.?});
            }

            if (entry.execution_time_ns != null) {
                try writer.print("\n  Exec time: {d}ns", .{entry.execution_time_ns.?});
            }

            if (entry.memory_accesses != null) {
                try writer.print("\n  Memory accesses:", .{});
                for (entry.memory_accesses.?) |access| {
                    try writer.print("\n    {s} addr={d} size={d} value={d}", .{
                        if (access.is_write) "WRITE" else "READ",
                        access.address,
                        access.size,
                        access.value,
                    });
                }
            }

            try writer.print("\n", .{});
        }

        return buffer.toOwnedSlice();
    }
};
