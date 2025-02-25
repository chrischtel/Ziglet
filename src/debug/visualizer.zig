// src/debug/visualizer.zig
const std = @import("std");
const VM = @import("../core/vm.zig").VM;

pub const VisualizerConfig = struct {
    show_registers: bool = true,
    show_stack: bool = true,
    show_memory: bool = true,
    memory_start: usize = 0,
    memory_length: usize = 64,
    show_execution_stats: bool = true,
    compact_mode: bool = false,
    show_color: bool = true,
};

pub const StateVisualizer = struct {
    allocator: std.mem.Allocator,
    config: VisualizerConfig,

    pub fn init(allocator: std.mem.Allocator, config: VisualizerConfig) StateVisualizer {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn renderState(self: *const StateVisualizer, vm: *const VM) ![]u8 {
        var buffer = std.ArrayList(u8).init(self.allocator);
        defer buffer.deinit();

        const writer = buffer.writer();

        if (self.config.compact_mode) {
            try self.renderCompactState(vm, writer);
        } else {
            try self.renderFullState(vm, writer);
        }

        return buffer.toOwnedSlice();
    }

    fn renderFullState(self: *const StateVisualizer, vm: *const VM, writer: anytype) !void {
        try writer.print("VM State - PC: {d}\n", .{vm.pc});
        try writer.print("----------------\n", .{});

        if (self.config.show_registers) {
            try writer.print("\nRegisters:\n", .{});
            for (vm.registers, 0..) |reg, i| {
                const color_start = if (self.config.show_color) "\x1b[32m" else "";
                const color_end = if (self.config.show_color) "\x1b[0m" else "";

                try writer.print("  R{d:2}: {s}{d:10}{s}", .{
                    i, color_start, reg, color_end,
                });

                if (i % 4 == 3) try writer.print("\n", .{});
            }
            try writer.print("\n", .{});
        }

        if (self.config.show_stack and vm.stack.items.len > 0) {
            try writer.print("\nStack ({d} items):\n", .{vm.stack.items.len});

            const max_items = @min(vm.stack.items.len, 16);
            const start = if (vm.stack.items.len > 16) vm.stack.items.len - 16 else 0;

            // Use max_items to limit the number of displayed items
            for (vm.stack.items[start..][0..max_items], start..) |item, i| {
                const color_start = if (self.config.show_color) "\x1b[33m" else "";
                const color_end = if (self.config.show_color) "\x1b[0m" else "";

                try writer.print("  [{d:3}]: {s}{d:10}{s}\n", .{
                    i, color_start, item, color_end,
                });
            }
        }

        if (self.config.show_memory) {
            const end = @min(self.config.memory_start + self.config.memory_length, vm.memory.len);

            try writer.print("\nMemory [{d}..{d}]:\n", .{
                self.config.memory_start, end,
            });

            var i: usize = self.config.memory_start;
            while (i < end) {
                try writer.print("  {d:6}: ", .{i});

                var j: usize = 0;
                while (j < 16 and i + j < end) : (j += 1) {
                    const byte = vm.memory[i + j];
                    const color_start = if (self.config.show_color and byte != 0) "\x1b[36m" else "";
                    const color_end = if (self.config.show_color and byte != 0) "\x1b[0m" else "";

                    try writer.print("{s}{X:2}{s} ", .{
                        color_start, byte, color_end,
                    });
                }

                try writer.print("  ", .{});

                j = 0;
                while (j < 16 and i + j < end) : (j += 1) {
                    const byte = vm.memory[i + j];
                    const c = if (std.ascii.isPrint(byte)) byte else '.';
                    try writer.print("{c}", .{c});
                }

                try writer.print("\n", .{});
                i += 16;
            }
        }

        if (self.config.show_execution_stats) {
            try writer.print("\nExecution Stats:\n", .{});
            try writer.print("  Compare Flag: {d}\n", .{vm.cmp_flag});
            try writer.print("  Instructions executed: {d}\n", .{vm.pc});
            try writer.print("  Cached instructions: {d}\n", .{vm.instruction_cache.count()});
        }
    }

    fn renderCompactState(self: *const StateVisualizer, vm: *const VM, writer: anytype) !void {
        try writer.print("PC={d} | ", .{vm.pc});

        if (self.config.show_registers) {
            try writer.print("Regs: ", .{});
            for (vm.registers, 0..) |reg, i| {
                if (reg != 0) {
                    try writer.print("R{d}={d} ", .{ i, reg });
                }
            }
        }

        if (self.config.show_stack and vm.stack.items.len > 0) {
            try writer.print("| Stack({d}): [", .{vm.stack.items.len});
            const max_items = @min(vm.stack.items.len, 3);
            const start = if (vm.stack.items.len > 3) vm.stack.items.len - 3 else 0;

            for (vm.stack.items[start..][0..max_items], 0..) |item, i| {
                try writer.print("{d}", .{item});
                if (i < max_items - 1) try writer.print(",", .{});
            }

            if (vm.stack.items.len > 3) {
                try writer.print("...]", .{});
            } else {
                try writer.print("]", .{});
            }
        }

        if (self.config.show_execution_stats) {
            try writer.print(" | CMP={d}", .{vm.cmp_flag});
        }
    }
};
