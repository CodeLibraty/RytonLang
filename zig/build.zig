
    const std = @import("std");

    pub fn build(b: *std.build.Builder) void {
        const target = b.standardTargetOptions(.{});
        const optimize = b.standardOptimizeOption(.{});
        
        const exe = b.addExecutable(.{
            .name = "temp",
            .root_source_file = .{ .path = "./zig/src/temp.zig" },
            .target = target,
            .optimize = optimize,
        });
        
        b.installArtifact(exe);
    }
    