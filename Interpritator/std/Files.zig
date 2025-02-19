const std = @import("std");
const fs = std.fs;
const heap = std.heap;

export fn writeFile(path: [*:0]const u8, content: [*:0]const u8) c_int {
    const file = fs.cwd().createFile(std.mem.span(path), .{}) catch return -1;
    defer file.close();
    file.writeAll(std.mem.span(content)) catch return -1;
    return 0;
}

export fn readFile(path: [*:0]const u8, buffer: [*]u8, size: usize) c_int {
    const file = fs.cwd().openFile(std.mem.span(path), .{}) catch return -1;
    defer file.close();
    const bytes_read = file.readAll(buffer[0..size]) catch return -1;
    return @intCast(bytes_read);
}

export fn listDir(path: [*:0]const u8, buffer: [*]u8, size: usize) c_int {
    var dir = fs.cwd().openDir(std.mem.span(path), .{ .iterate = true }) catch return -1;
    defer dir.close();

    var written: usize = 0;
    var iter = dir.iterate();
    while (iter.next() catch return -1) |entry| {
        if (written + entry.name.len + 1 > size) break;
        @memcpy(buffer[written .. written + entry.name.len], entry.name);
        buffer[written + entry.name.len] = 0;
        written += entry.name.len + 1;
    }
    return @intCast(written);
}
export fn createDir(path: [*:0]const u8) c_int {
    fs.cwd().makeDir(std.mem.span(path)) catch return -1;
    return 0;
}

export fn removeDir(path: [*:0]const u8) c_int {
    fs.cwd().deleteTree(std.mem.span(path)) catch return -1;
    return 0;
}

export fn copyFile(src: [*:0]const u8, dst: [*:0]const u8) c_int {
    fs.cwd().copyFile(std.mem.span(src), fs.cwd(), std.mem.span(dst), .{}) catch return -1;
    return 0;
}

export fn moveFile(src: [*:0]const u8, dst: [*:0]const u8) c_int {
    fs.cwd().rename(std.mem.span(src), std.mem.span(dst)) catch return -1;
    return 0;
}

export fn deleteFile(path: [*:0]const u8) c_int {
    fs.cwd().deleteFile(std.mem.span(path)) catch return -1;
    return 0;
}

export fn fileInfo(path: [*:0]const u8, stat: *fs.File.Stat) c_int {
    const file = fs.cwd().openFile(std.mem.span(path), .{}) catch return -1;
    defer file.close();
    stat.* = file.stat() catch return -1;
    return 0;
}

export fn fileExists(path: [*:0]const u8) c_int {
    fs.cwd().access(std.mem.span(path), .{}) catch return 0;
    return 1;
}

export fn appendFile(path: [*:0]const u8, content: [*:0]const u8) c_int {
    const file = fs.cwd().openFile(std.mem.span(path), .{ .mode = .read_write }) catch return -1;
    defer file.close();
    file.seekFromEnd(0) catch return -1;
    file.writeAll(std.mem.span(content)) catch return -1;
    return 0;
}

export fn setFilePerms(path: [*:0]const u8, perms: c_int) c_int {
    const file = fs.cwd().openFile(std.mem.span(path), .{}) catch return -1;
    defer file.close();
    file.chmod(@intCast(perms)) catch return -1;
    return 0;
}

export fn isDir(path: [*:0]const u8) c_int {
    var dir = fs.cwd().openDir(std.mem.span(path), .{}) catch return 0;
    dir.close();
    return 1;
}

export fn isFile(path: [*:0]const u8) c_int {
    const file = fs.cwd().openFile(std.mem.span(path), .{}) catch return 0;
    defer file.close();
    return 1;
}
