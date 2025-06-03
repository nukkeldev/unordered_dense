//! Copyright (c) 2025 nukkeldev
//! This script is MIT licensed; see [LICENSE] for the full text.

const std = @import("std");

pub fn build(b: *std.Build) void {
    // Get the upstream's file tree.
    const upstream = b.dependency("upstream", .{}).path(".");
    if (b.verbose) std.log.info("Upstream Path: {}", .{upstream.dependency.dependency.builder.build_root});

    // Get the version from the `build.zig.zon`.
    const version = getVersion(b.allocator);
    std.log.info("Configuring build for `unordered_dense` version {}!", .{version});

    // Mark include header as installable.
    const install = b.addInstallFileWithDir(upstream.path(b, "include/ankerl/unordered_dense.h"), .header, "ankerl/unordered_dense.h");
    b.getInstallStep().dependOn(&install.step);

    // -- Other Steps --

    // Create an unpack step to view the source code we are using.
    const unpack = b.step("unpack", "Installs the unpacked source");
    unpack.dependOn(&b.addInstallDirectory(.{
        .source_dir = upstream,
        .install_dir = .{ .custom = "unpacked" },
        .install_subdir = "",
    }).step);

    // Remove the `zig-out` folder.
    const clean = b.step("clean", "Deletes the `zig-out` folder");
    clean.dependOn(&b.addRemoveDirTree(b.path("zig-out")).step);
}

// Version

/// Get the .version field of the `build.zig.zon`.
fn getVersion(allocator: std.mem.Allocator) std.SemanticVersion {
    const @"build.zig.zon" = @embedFile("build.zig.zon");
    var lines = std.mem.splitScalar(u8, @"build.zig.zon", '\n');
    while (lines.next()) |line| if (std.mem.startsWith(u8, std.mem.trimLeft(u8, line, " \t"), ".version")) {
        const end = std.mem.lastIndexOfScalar(u8, line, '"').?;
        const start = std.mem.lastIndexOfScalar(u8, line[0..end], '"').? + 1;
        const version = allocator.dupe(u8, line[start..end]) catch oom();
        return std.SemanticVersion.parse(version) catch unreachable;
    };
    unreachable;
}

// Logging

fn oom() noreturn {
    fatalNoData("Out-Of-Memory");
}

fn fatalNoData(comptime format: []const u8) noreturn {
    const stderr = std.io.getStdErr();
    const w = stderr.writer();

    const tty_config = std.io.tty.detectConfig(stderr);
    tty_config.setColor(w, .red) catch {};
    stderr.writeAll("error: " ++ format) catch {};
    tty_config.setColor(w, .reset) catch {};

    std.process.exit(1);
}
