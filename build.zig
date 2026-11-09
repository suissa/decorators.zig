const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "decorators-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/decorators.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const decorators_module = b.createModule(.{
        .root_source_file = b.path("src/decorators.zig"),
        .target = target,
        .optimize = optimize,
    });
    const event_runtime_module = b.createModule(.{
        .root_source_file = b.path("src/event_runtime.zig"),
        .target = target,
        .optimize = optimize,
    });
    event_runtime_module.addImport("decorators", decorators_module);

    const integration_module = b.createModule(.{
        .root_source_file = b.path("tests/integration.zig"),
        .target = target,
        .optimize = optimize,
    });
    integration_module.addImport("decorators", decorators_module);
    integration_module.addImport("event_runtime", event_runtime_module);
    const integration_tests = b.addTest(.{
        .root_module = integration_module,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const run_integration_tests = b.addRunArtifact(integration_tests);
    const test_step = b.step("test", "Run unit and integration tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_integration_tests.step);
}
