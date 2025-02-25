// src/debug/debug.zig
const std = @import("std");
const VM = @import("../core/vm.zig").VM;
const tracer = @import("tracer.zig");
const visualizer = @import("visualizer.zig");
const profiler = @import("profiler.zig");

pub const ExecutionTracer = tracer.ExecutionTracer;
pub const TraceLevel = tracer.TraceLevel;
pub const StateVisualizer = visualizer.StateVisualizer;
pub const VisualizerConfig = visualizer.VisualizerConfig;
pub const Profiler = profiler.Profiler;
pub const ProfilerConfig = profiler.ProfilerConfig;

pub const DebugConfig = struct {
    enabled: bool = true,
    trace_level: TraceLevel = .standard,
    visualizer_config: VisualizerConfig = .{},
    profiler_config: ProfilerConfig = .{},
    auto_save_trace: bool = false,
    auto_save_profile: bool = false,
    trace_file_path: ?[]const u8 = "debug/trace.log",
    profile_file_path: ?[]const u8 = "debug/profile.log",
};

pub const DebugSystem = struct {
    allocator: std.mem.Allocator,
    config: DebugConfig,
    tracer: ?ExecutionTracer = null,
    visualizer: ?StateVisualizer = null,
    profiler: ?Profiler = null,

    pub fn init(allocator: std.mem.Allocator, config: DebugConfig) !DebugSystem {
        var system = DebugSystem{
            .allocator = allocator,
            .config = config,
        };

        if (config.enabled) {
            if (config.trace_level != .none) {
                system.tracer = try ExecutionTracer.init(allocator, config.trace_level);
            }

            system.visualizer = StateVisualizer.init(allocator, config.visualizer_config);

            if (config.profiler_config.enabled) {
                system.profiler = try Profiler.init(allocator, config.profiler_config);
            }

            if (config.auto_save_trace or config.auto_save_profile) {
                try std.fs.cwd().makePath("debug");
            }
        }

        return system;
    }

    pub fn deinit(self: *DebugSystem) void {
        if (self.tracer) |*t| t.deinit();
        if (self.profiler) |*p| p.deinit();
    }

    pub fn beginInstruction(self: *DebugSystem, vm: *const VM) void {
        if (!self.config.enabled) return;

        if (self.tracer) |*t| t.beginInstruction(vm);
        if (self.profiler) |*p| p.startInstruction(vm.pc, vm.program[vm.pc].opcode);
    }

    pub fn endInstruction(self: *DebugSystem, vm: *const VM) !void {
        if (!self.config.enabled) return;

        if (self.tracer) |*t| try t.endInstruction(vm);
        if (self.profiler) |*p| try p.endInstruction();
    }

    pub fn recordMemoryAccess(self: *DebugSystem, address: usize, is_write: bool, size: u8, value: u32) !void {
        if (!self.config.enabled) return;

        if (self.tracer) |*t| try t.recordMemoryAccess(address, is_write, size, value);
        if (self.profiler) |*p| try p.recordMemoryAccess(address, is_write);
    }

    pub fn saveTraceToFile(self: *DebugSystem) !void {
        if (!self.config.enabled or self.tracer == null or self.config.trace_file_path == null)
            return;

        const report = try self.tracer.?.generateReport();
        defer self.allocator.free(report);

        // Use the new writeFile API with options struct
        try std.fs.cwd().writeFile(.{
            .sub_path = self.config.trace_file_path.?,
            .data = report,
        });
    }

    pub fn saveProfileToFile(self: *DebugSystem) !void {
        if (!self.config.enabled or self.profiler == null or self.config.profile_file_path == null)
            return;

        const report = try self.profiler.?.generateReport();
        defer self.allocator.free(report);

        // Use the new writeFile API with options struct
        try std.fs.cwd().writeFile(.{
            .sub_path = self.config.profile_file_path.?,
            .data = report,
        });
    }

    pub fn visualizeState(self: *DebugSystem, vm: *const VM) ![]u8 {
        if (!self.config.enabled or self.visualizer == null)
            return &[_]u8{};

        return self.visualizer.?.renderState(vm);
    }
};
