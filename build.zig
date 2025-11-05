const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ct_utils = b.createModule(.{
        .root_source_file = b.path("src/ct_utils.zig"),
        .target = target,
    });

    const unicode = b.createModule(.{
        .root_source_file = b.path("src/unicode.zig"),
        .target = target,
    });

    const mod = b.addModule("ctregex", .{
        .root_source_file = b.path("src/ctregex.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "ct_utils", .module = ct_utils },
            .{ .name = "unicode", .module = unicode },
            .{
                .name = "finite_automaton",
                .module = b.createModule(.{
                    .root_source_file = b.path("src/fa/finite_automaton.zig"),
                    .target = target,
                    .imports = &.{
                        .{ .name = "ct_utils", .module = ct_utils },
                        .{ .name = "unicode", .module = unicode },
                    },
                }),
            },
        },
    });

    const lib = b.addLibrary(.{
        .name = "ctregex",
        .root_module = mod,
        .linkage = .static,
    });
    b.installArtifact(lib);

    const test_step = b.step("test", "Run library tests");
    const mod_tests = b.addTest(.{ .root_module = mod });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    test_step.dependOn(&run_mod_tests.step);
}
