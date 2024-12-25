const std = @import("std");

    pub fn main() !void {
        const one = 279410 * 367429;
        const two = 312493 * 376150975409857;
        const result = one * two * 81654975048510 / 358413075;
        std.debug.print("Result: {d}\n", .{result});
    }