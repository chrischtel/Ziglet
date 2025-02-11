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

    // TODO: Add examples
    const examples = [_]struct { name: []const u8, path: []const u8 }{
        .{ .name = "simple", .path = "examples/simple.zig" },
        .{ .name = "calculator", .path = "examples/calculator.zig" },
    };

    // Create an example step
    const example_step = b.step("examples", "Build examples");

    // Add each example
    for (examples) |example| {
        const exe = b.addExecutable(.{
            .name = example.name,
            .root_source_file = b.path(example.path),
            .target = target,
            .optimize = optimize,
        });

        // Add ziglet as a module
        exe.root_module.addImport("ziglet", ziglet_module);

        const install_exe = b.addInstallArtifact(exe, .{});
        example_step.dependOn(&install_exe.step);
    }
}
