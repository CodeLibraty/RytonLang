const std = @import("std");
const Allocator = std.mem.Allocator;

export fn collect(gc: *GarbageCollector) void {
    gc.collect() catch {};
}

export fn allocate(gc: *GarbageCollector, size: usize) ?*anyopaque {
    return gc.allocate(size) catch null;
}

pub const GCStats = extern struct {
    total_allocated: usize,
    objects_count: usize,
};

pub const GCAlgorithm = enum(c_int) {
    MarkSweep,
    Reference,
    Generational,
    Incremental,
};

pub export fn init_collector(algorithm: c_int, heap_size: usize, threshold: usize) ?*GarbageCollector {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const config = GCConfig{
        .algorithm = @enumFromInt(algorithm),
        .heap_size = heap_size,
        .threshold = threshold,
    };

    const gc = allocator.create(GarbageCollector) catch return null;
    gc.* = GarbageCollector.init(allocator, config) catch return null;
    return gc;
}

export fn get_stats(gc: *GarbageCollector) GCStats {
    return .{
        .total_allocated = gc.total_allocated,
        .objects_count = gc.objects.count(),
    };
}

pub const GCConfig = struct {
    algorithm: GCAlgorithm,
    heap_size: usize,
    threshold: usize,
};

pub const ObjectHeader = struct {
    size: usize,
    marked: bool,
    refs: usize,
    generation: u8,
};

pub const GarbageCollector = struct {
    allocator: Allocator,
    objects: std.AutoHashMap(usize, *ObjectHeader),
    config: GCConfig,
    total_allocated: usize,

    pub fn init(allocator: Allocator, config: GCConfig) !GarbageCollector {
        return GarbageCollector{
            .allocator = allocator,
            .objects = std.AutoHashMap(usize, *ObjectHeader).init(allocator),
            .config = config,
            .total_allocated = 0,
        };
    }

    pub fn allocate(self: *GarbageCollector, size: usize) !*anyopaque {
        if (self.total_allocated >= self.config.threshold) {
            try self.collect();
        }

        const aligned_size = size + @sizeOf(ObjectHeader);
        const ptr = try self.allocator.alignedAlloc(u8, @alignOf(ObjectHeader), aligned_size);

        const header = @as(*ObjectHeader, @ptrCast(ptr));

        header.* = .{
            .size = size,
            .marked = false,
            .refs = 1,
            .generation = 0,
        };

        const ptr_value = @intFromPtr(@as(*anyopaque, ptr.ptr));
        try self.objects.put(ptr_value, header);

        self.total_allocated += aligned_size;

        return @as(*anyopaque, @ptrCast(ptr.ptr + @sizeOf(ObjectHeader)));
    }

    pub fn collect(self: *GarbageCollector) !void {
        switch (self.config.algorithm) {
            .MarkSweep => try self.markSweepCollect(),
            .Reference => try self.referenceCollect(),
            .Generational => try self.generationalCollect(),
            .Incremental => try self.incrementalCollect(),
        }
    }

    fn markSweepCollect(self: *GarbageCollector) !void {
        var it = self.objects.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.*.refs > 0) {
                entry.value_ptr.*.marked = true;
            }
        }

        it = self.objects.iterator();
        while (it.next()) |entry| {
            if (!entry.value_ptr.*.marked) {
                const ptr = @as([*]u8, @ptrFromInt(entry.key_ptr.*));
                self.total_allocated -= entry.value_ptr.*.size + @sizeOf(ObjectHeader);
                self.allocator.free(ptr[0..entry.value_ptr.*.size]);
                _ = self.objects.remove(entry.key_ptr.*);
            } else {
                entry.value_ptr.*.marked = false;
            }
        }
    }

    fn referenceCollect(self: *GarbageCollector) !void {
        var it = self.objects.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.*.refs == 0) {
                const ptr = @as([*]u8, @ptrFromInt(entry.key_ptr.*));
                self.total_allocated -= entry.value_ptr.*.size + @sizeOf(ObjectHeader);
                self.allocator.free(ptr[0..entry.value_ptr.*.size]);
                _ = self.objects.remove(entry.key_ptr.*);
            }
        }
    }

    fn generationalCollect(self: *GarbageCollector) !void {
        var it = self.objects.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.*.generation > 2) {
                entry.value_ptr.*.marked = true;
            }
        }
        try self.markSweepCollect();
    }

    fn incrementalCollect(self: *GarbageCollector) !void {
        var count: usize = 0;
        var it = self.objects.iterator();
        while (it.next()) |entry| {
            if (count > 100) break;
            if (!entry.value_ptr.*.marked) {
                const ptr = @as([*]u8, @ptrFromInt(entry.key_ptr.*));
                self.total_allocated -= entry.value_ptr.*.size + @sizeOf(ObjectHeader);
                self.allocator.free(ptr[0..entry.value_ptr.*.size]);
                _ = self.objects.remove(entry.key_ptr.*);
            }
            count += 1;
        }
    }
};
