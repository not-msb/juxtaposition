// Simple parser, that *only* parses a subset of correct obj files
// Im not the one that should validate them
// All given example obj should WORK 100% of the time.

// This is a *BUILD SCRIPT*, this generates artifacts for the main program to use

const std = @import("std");
const cwd = std.fs.cwd;
const ArrayList = std.ArrayList;

const allocator = std.heap.page_allocator;

pub fn main() !void {
    var dir = try cwd().openDir("src/build/obj", .{ .iterate = true });
    defer dir.close();

    var files = dir.iterate();

    std.log.info("Starting obj baking", .{});
    defer std.log.info("Done with obj baking", .{});

    var map = ArrayList(Objs.Entry).init(allocator);
    defer map.deinit();

    while (try files.next()) |file| {
        std.log.info("Scanning file: {s}", .{file.name});
        if (file.kind != .file or !std.mem.endsWith(u8, file.name, ".obj")) continue;

        const source = try dir.readFileAlloc(allocator, file.name, std.math.maxInt(usize));
        defer allocator.free(source);

        const obj = try Obj.new(source);
        try map.append(.{ .key = file.name, .value = obj });
    }

    const cake = try cwd().createFile("src/build/objects.bin", .{});
    defer cake.close();

    const objs = Objs{ .map = map.items };
    try objs.writeToFile(cake);
    //try cake.writer().writeStruct(objs);
}

const Objs = struct {
    // I trust filenames to *not* duplicate keys
    map: []const Entry,

    const Entry = struct {
        key: []const u8,
        value: Obj,
    };

    fn writeToFile(self: Objs, file: std.fs.File) !void {
        const writer = file.writer();

        try writer.writeInt(u64, self.map.len, .little);
        for (self.map) |entry| {
            try writer.writeInt(u64, entry.key.len, .little);
            try writer.writeAll(entry.key);

            {
                const ptr: [*]const u8 = @ptrCast(entry.value.vertices.ptr);
                const len = entry.value.vertices.len * @sizeOf(Obj.Vec3);
                try writer.writeInt(u64, len, .little);
                try writer.writeAll(ptr[0..len]);
            }

            {
                const ptr: [*]const u8 = @ptrCast(entry.value.faces.ptr);
                const len = entry.value.faces.len * @sizeOf(Obj.Vec3);
                try writer.writeInt(u64, len, .little);
                try writer.writeAll(ptr[0..len]);
            }
        }
    }
};

const Obj = struct {
    vertices: []const Vec3,
    faces: []const UVec3,
    //normals: []const Vec3,

    const Vec3 = [3]f32;
    const UVec3 = [3]u32;

    pub fn new(source: []const u8) !Obj {
        var lines = std.mem.tokenizeScalar(u8, source, '\n');
        var vertices = ArrayList(Vec3).init(allocator);
        var faces = ArrayList(UVec3).init(allocator);

        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "#")) continue;
            if (std.mem.startsWith(u8, line, "vn")) continue; // Ignoring it for now

            if (std.mem.startsWith(u8, line, "v")) {
                const space0 = std.mem.indexOfPos(u8, line, 2, " ").?;
                const space1 = std.mem.indexOfPos(u8, line, space0+1, " ").?;
                const space2 = std.mem.indexOfPos(u8, line, space1+1, " ") orelse line.len;

                const n0 = try std.fmt.parseFloat(f32, line[2..space0]);
                const n1 = try std.fmt.parseFloat(f32, line[space0+1..space1]);
                const n2 = try std.fmt.parseFloat(f32, line[space1+1..space2]);

                try vertices.append(.{ n0, n1, n2 });
            }

            // This only parses faces of the form `f 3//1 7//1 8//1`
            //                        or the form `f 3 7 8`
            // This is cuz my examples used it, full parsing is *not* my goal rn
            if (std.mem.startsWith(u8, line, "f")) {
                const space0 = std.mem.indexOfPos(u8, line, 2, " ").?;
                const space1 = std.mem.indexOfPos(u8, line, space0+1, " ").?;
                const space2 = std.mem.indexOfPos(u8, line, space1+1, " ") orelse line.len;

                const slash0 = std.mem.indexOfPos(u8, line, 2, "/") orelse line.len;
                const slash1 = std.mem.indexOfPos(u8, line, space0+1, "/") orelse line.len;
                const slash2 = std.mem.indexOfPos(u8, line, space1+1, "/") orelse line.len;

                switch (std.mem.containsAtLeast(u8, line, 1, "/")) {
                    true => {
                        const n0 = try std.fmt.parseInt(u32, line[2..slash0], 10);
                        const n1 = try std.fmt.parseInt(u32, line[space0+1..slash1], 10);
                        const n2 = try std.fmt.parseInt(u32, line[space1+1..slash2], 10);

                        try faces.append(.{ n0, n1, n2 });
                    },
                    false => {
                        const n0 = try std.fmt.parseInt(u32, line[2..space0], 10);
                        const n1 = try std.fmt.parseInt(u32, line[space0+1..space1], 10);
                        const n2 = try std.fmt.parseInt(u32, line[space1+1..space2], 10);

                        try faces.append(.{ n0, n1, n2 });
                    },
                }
            }
        }

        return Obj{
            .vertices = try vertices.toOwnedSlice(),
            .faces = try faces.toOwnedSlice(),
        };
    }
};
