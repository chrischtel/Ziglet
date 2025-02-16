const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // The main library
    const lib = b.addStaticLibrary(.{
        .name = "ziglet",
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    // Create module for use as a dependency
    const ziglet_module = b.addModule("ziglet", .{
        .root_source_file = b.path("src/root.zig"),
    });

    // Unit tests
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    const examples = [_]struct { name: []const u8, path: []const u8 }{
        .{ .name = "simple", .path = "examples/simple.zig" },
        .{ .name = "calculator", .path = "examples/calculator.zig" },
        .{ .name = "jump", .path = "examples/jump_instructions.zig" },
    };

    const all_examples_step = b.step("all-examples", "Run all examples (for CI)");

    {
        for (examples) |example| {
            const exe = b.addExecutable(.{
                .name = example.name,
                .target = target,
                .optimize = optimize,
                .root_source_file = b.path(example.path),
            });
            exe.root_module.addImport("ziglet", ziglet_module);

            b.installArtifact(exe);

            const run_cmd = b.addRunArtifact(exe);
            run_cmd.step.dependOn(b.getInstallStep());
            if (b.args) |args| {
                run_cmd.addArgs(args);
            }

            const run_step = b.step(example.name, example.path);
            run_step.dependOn(&run_cmd.step);

            test_step.dependOn(&run_cmd.step);
            all_examples_step.dependOn(&run_cmd.step);
        }
    }
}
