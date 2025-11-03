const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    var imports: [3]std.Build.Module.Import = undefined;
    inline for (&imports, .{ .{ "ct_utils", "src/ct_utils.zig" }, .{ "unicode", "src/unicode.zig" }, .{ "finite_automaton", "src/fa/finite_automaton.zig" } }) |*import, input| {
        import.* = .{
            .name = input.@"0",
            .module = b.createModule(.{
                .root_source_file = b.path(input.@"1"),
                .target = target,
                .optimize = optimize,
            }),
        };
    }
    imports[2].module.addImport(imports[1].name, imports[1].module);

    const lib = b.addLibrary(.{
        .name = "ctregex",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ctregex.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &imports,
        }),
        .linkage = .static,
    });
    b.installArtifact(lib);

    const test_step = b.step("test", "Run library tests");
    inline for (.{ "src/ctregex.zig", "src/fa/finite_automaton.zig" }) |test_path| {
        const test_ = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(test_path),
                .target = target,
                .optimize = optimize,
                .imports = &imports,
            }),
        });
        test_step.dependOn(&test_.step);
    }
}
