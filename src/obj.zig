const std = @import("std");
const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;

pub const Obj = struct {
    vertices: []const Vec3,
    faces: []const UVec3,
    //normals: []const Vec3,

    const Vec3 = [3]f32;
    const UVec3 = [3]u32;
};

pub const Objs = struct {
    map: StringHashMap(Obj),

    const Entry = struct {
        key: []const u8,
        value: Obj,
    };

    pub fn readFromFile(allocator: Allocator, comptime filename: []const u8) !Objs {
        var stream = std.io.fixedBufferStream(@embedFile(filename));
        const reader = stream.reader();

        const len = try reader.readInt(u64, .little);
        const list = try allocator.alloc(Entry, @intCast(len));

        for (list) |*entry| {
            const obj_len = try reader.readInt(u64, .little);
            const obj_key = try allocator.alloc(u8, @intCast(obj_len));
            _ = try reader.read(obj_key);

            const vertices_len = try reader.readInt(u64, .little);
            const vertices = try allocator.alloc(u8, @intCast(vertices_len));
            _ = try reader.read(vertices);

            const faces_len = try reader.readInt(u64, .little);
            const faces = try allocator.alloc(u8, @intCast(faces_len));
            _ = try reader.read(faces);

            entry.key = obj_key;
            entry.value.vertices = @as([*]const Obj.Vec3, @alignCast(@ptrCast(vertices.ptr)))[0..@intCast(vertices_len/@sizeOf(Obj.Vec3))];
            entry.value.faces = @as([*]const Obj.UVec3, @alignCast(@ptrCast(faces.ptr)))[0..@intCast(faces_len/@sizeOf(Obj.UVec3))];
        }

        var map = StringHashMap(Obj).init(allocator);
        for (list) |entry| try map.put(entry.key, entry.value);
        return .{ .map = map };
    }
};
