// src/debug/profiler.zig
const std = @import("std");
const VM = @import("../core/vm.zig").VM;
const Instruction = @import("../instruction/types.zig").Instruction;
const OpCode = @import("../instruction/types.zig").OpCode;

pub const ProfilerConfig = struct {
    enabled: bool = true,
    track_hot_instructions: bool = true,
    track_opcode_stats: bool = true,
    track_memory_pattern: bool = true,
};

pub const InstructionStats = struct {
    execution_count: usize = 0,
    total_time_ns: u64 = 0,
    min_time_ns: u64 = std.math.maxInt(u64),
    max_time_ns: u64 = 0,
};

pub const OpcodeStats = struct {
    execution_count: usize = 0,
    total_time_ns: u64 = 0,
};

pub const MemoryAccessPattern = struct {
    read_count: std.AutoHashMap(usize, usize),
    write_count: std.AutoHashMap(usize, usize),

    pub fn init(allocator: std.mem.Allocator) MemoryAccessPattern {
        return .{
            .read_count = std.AutoHashMap(usize, usize).init(allocator),
            .write_count = std.AutoHashMap(usize, usize).init(allocator),
        };
    }

    pub fn deinit(self: *MemoryAccessPattern) void {
        self.read_count.deinit();
        self.write_count.deinit();
    }
};

pub const Profiler = struct {
    allocator: std.mem.Allocator,
    config: ProfilerConfig,
    instruction_stats: std.AutoHashMap(usize, InstructionStats),
    opcode_stats: std.AutoHashMap(OpCode, OpcodeStats),
    memory_pattern: MemoryAccessPattern,
    timer: std.time.Timer,
    current_pc: ?usize = null,
    current_opcode: ?OpCode = null, // Store the current opcode

    pub fn init(allocator: std.mem.Allocator, config: ProfilerConfig) !Profiler {
        return Profiler{
            .allocator = allocator,
            .config = config,
            .instruction_stats = std.AutoHashMap(usize, InstructionStats).init(allocator),
            .opcode_stats = std.AutoHashMap(OpCode, OpcodeStats).init(allocator),
            .memory_pattern = MemoryAccessPattern.init(allocator),
            .timer = try std.time.Timer.start(),
        };
    }

    pub fn deinit(self: *Profiler) void {
        self.instruction_stats.deinit();
        self.opcode_stats.deinit();
        self.memory_pattern.deinit();
    }

    pub fn startInstruction(self: *Profiler, pc: usize, opcode: OpCode) void {
        if (!self.config.enabled) return;

        self.current_pc = pc;
        self.current_opcode = opcode; // Store the opcode

        self.timer.reset();
    }

    pub fn endInstruction(self: *Profiler) !void {
        if (!self.config.enabled or self.current_pc == null) return;

        const elapsed = self.timer.read();
        const pc = self.current_pc.?;
        const opcode = self.current_opcode orelse return;

        self.current_pc = null;

        if (self.config.track_hot_instructions) {
            var entry = self.instruction_stats.get(pc) orelse InstructionStats{};
            entry.execution_count += 1;
            entry.total_time_ns += elapsed;
            entry.min_time_ns = @min(entry.min_time_ns, elapsed);
            entry.max_time_ns = @max(entry.max_time_ns, elapsed);
            try self.instruction_stats.put(pc, entry);
        }

        if (self.config.track_opcode_stats) {
            var entry = self.opcode_stats.get(opcode) orelse OpcodeStats{};
            entry.execution_count += 1;
            entry.total_time_ns += elapsed;
            try self.opcode_stats.put(opcode, entry);
        }
    }

    pub fn recordMemoryAccess(self: *Profiler, address: usize, is_write: bool) !void {
        if (!self.config.enabled or !self.config.track_memory_pattern) return;

        var map = if (is_write)
            &self.memory_pattern.write_count
        else
            &self.memory_pattern.read_count;

        const count = map.get(address) orelse 0;
        try map.put(address, count + 1);
    }

    // Fix for src/debug/profiler.zig
    pub fn generateReport(self: *const Profiler) ![]u8 {
        if (!self.config.enabled) return &[_]u8{};

        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        const writer = buffer.writer();

        try writer.print("VM Profiler Report\n", .{});
        try writer.print("=================\n\n", .{});

        if (self.config.track_hot_instructions) {
            try writer.print("Hot Instructions:\n", .{});
            try writer.print("----------------\n", .{});

            // Define the entry type first
            const InstructionEntry = struct { pc: usize, stats: InstructionStats };

            // Use the named type in the ArrayList
            var entries = std.ArrayList(InstructionEntry).init(self.allocator);
            defer entries.deinit();

            var it = self.instruction_stats.iterator();
            while (it.next()) |entry| {
                try entries.append(.{ .pc = entry.key_ptr.*, .stats = entry.value_ptr.* });
            }

            // Sort entries by execution count (descending)
            std.sort.insertion(InstructionEntry, entries.items, {}, struct {
                fn lessThan(_: void, a: InstructionEntry, b: InstructionEntry) bool {
                    return a.stats.execution_count > b.stats.execution_count;
                }
            }.lessThan);

            const show_count = @min(entries.items.len, 10);
            for (entries.items[0..show_count], 0..) |entry, i| {
                const avg_time = if (entry.stats.execution_count > 0)
                    entry.stats.total_time_ns / entry.stats.execution_count
                else
                    0;

                try writer.print("{d}: PC={d} | Count={d} | Avg={d}ns | Min={d}ns | Max={d}ns\n", .{
                    i + 1,
                    entry.pc,
                    entry.stats.execution_count,
                    avg_time,
                    entry.stats.min_time_ns,
                    entry.stats.max_time_ns,
                });
            }
            try writer.print("\n", .{});
        }

        if (self.config.track_opcode_stats) {
            try writer.print("Opcode Statistics:\n", .{});
            try writer.print("-----------------\n", .{});

            // Define the entry type first
            const OpcodeEntry = struct { opcode: OpCode, stats: OpcodeStats };

            // Use the named type in the ArrayList
            var entries = std.ArrayList(OpcodeEntry).init(self.allocator);
            defer entries.deinit();

            var it = self.opcode_stats.iterator();
            while (it.next()) |entry| {
                try entries.append(.{ .opcode = entry.key_ptr.*, .stats = entry.value_ptr.* });
            }

            // Sort entries by execution count (descending)
            std.sort.insertion(OpcodeEntry, entries.items, {}, struct {
                fn lessThan(_: void, a: OpcodeEntry, b: OpcodeEntry) bool {
                    return a.stats.execution_count > b.stats.execution_count;
                }
            }.lessThan);

            for (entries.items) |entry| {
                const avg_time = if (entry.stats.execution_count > 0)
                    entry.stats.total_time_ns / entry.stats.execution_count
                else
                    0;

                try writer.print("{s}: Count={d} | Total={d}ns | Avg={d}ns\n", .{
                    @tagName(entry.opcode),
                    entry.stats.execution_count,
                    entry.stats.total_time_ns,
                    avg_time,
                });
            }
            try writer.print("\n", .{});
        }

        return buffer.toOwnedSlice();
    }
};
