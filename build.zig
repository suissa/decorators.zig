const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "decorators-server",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });
    exe.root_module.addCSourceFiles(.{
        .files = &.{
            "src/http_ws_server.cpp",
            "src/grpc_server.cpp",
            "src/server_main.cpp",
        },
        .flags = &.{"-std=c++17"},
    });
    exe.linkSystemLibrary("grpc++");
    exe.linkSystemLibrary("grpc");
    exe.linkSystemLibrary("protobuf");
    exe.linkSystemLibrary("crypto");
    b.installArtifact(exe);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/decorators.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const handler_module = b.createModule(.{
        .root_source_file = b.path("src/transport_handler.zig"),
        .target = target,
        .optimize = optimize,
    });
    const transport_test_module = b.createModule(.{
        .root_source_file = b.path("tests/transport_handler.zig"),
        .target = target,
        .optimize = optimize,
    });
    transport_test_module.addImport("transport_handler", handler_module);
    const transport_tests = b.addTest(.{ .root_module = transport_test_module });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const run_transport_tests = b.addRunArtifact(transport_tests);
    const test_step = b.step("test", "Run unit and transport contract tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_transport_tests.step);
}
