const std = @import("std");
const cwd = std.fs.cwd;
const Objs = @import("obj.zig").Objs;
const Obj = @import("obj.zig").Obj;

const Mode = enum(u32) {
    flat = 0,
    wireframe = 1,
};

extern fn print(f32) void;

const width = 800;
const height = 600;
var mode = Mode.flat;
var zbuffer: [width*height]f32 = undefined;

export const wasm_width: u32 = width;
export const wasm_height: u32 = height;
export var image: [4*width*height]u8 = undefined;

// Source: https://en.wikipedia.org/wiki/Dot_product#Coordinate_definition
fn dot(lhs: [2]f32, rhs: [2]f32) f32 {
    return lhs[0]*rhs[0] + lhs[1]*rhs[1];
}

// Source: https://gamedev.stackexchange.com/a/63203
fn barycentric(points: [3][2]f32, point: [2]f32) [3]f32 {
    const v0 = [2]f32{ points[1][0] - points[0][0], points[1][1] - points[0][1] };
    const v1 = [2]f32{ points[2][0] - points[0][0], points[2][1] - points[0][1] };
    const v2 = [2]f32{ point[0] - points[0][0], point[1] - points[0][1] };

    const d00 = dot(v0, v0);
    const d01 = dot(v0, v1);
    const d11 = dot(v1, v1);
    const d20 = dot(v2, v0);
    const d21 = dot(v2, v1);
    const det = (d00 * d11 - d01 * d01);

    const x = (d11 * d20 - d01 * d21) / det;
    const y = (d00 * d21 - d01 * d20) / det;
    return [3]f32{ x, y, 1 - x - y };
}

fn drawTriangle(points: [3][3]f32, color: [4]u8) void {
    const gen = struct {
        fn lessThanFn(context: void, lhs: [2]f32, rhs: [2]f32) bool {
            _ = context;
            return lhs[1] > rhs[1];
        }
    };

    var proj: [3][2]f32 = .{
        .{ ((points[0][0] / (1-points[0][2])) + 1) * width/2, ((points[0][1] / (1-points[0][2])) + 1) * height/2 },
        .{ ((points[1][0] / (1-points[1][2])) + 1) * width/2, ((points[1][1] / (1-points[1][2])) + 1) * height/2 },
        .{ ((points[2][0] / (1-points[2][2])) + 1) * width/2, ((points[2][1] / (1-points[2][2])) + 1) * height/2 },
    };
    std.mem.sort([2]f32, &proj, {}, gen.lessThanFn);

    const pixels: *[height][width][4]u8 = @ptrCast(&image);

    const xmin: u32 = @intFromFloat(@round(std.math.clamp(@min(@min(proj[0][0], proj[1][0]), proj[2][0]), 0, width-1)));
    const ymin: u32 = @intFromFloat(@round(std.math.clamp(@min(@min(proj[0][1], proj[1][1]), proj[2][1]), 0, height-1)));
    const xmax: u32 = @intFromFloat(@round(std.math.clamp(@max(@max(proj[0][0], proj[1][0]), proj[2][0]), 0, width-1)));
    const ymax: u32 = @intFromFloat(@round(std.math.clamp(@max(@max(proj[0][1], proj[1][1]), proj[2][1]), 0, height-1)));

    for (ymin..ymax) |y| for (xmin..xmax) |x| {
        const xf: f32 = @floatFromInt(x);
        const yf: f32 = @floatFromInt(y);
        const bc = barycentric(proj, [2]f32{ xf, yf });

        // Source: https://stackoverflow.com/a/2049712
        if (!(bc[0] >= 0 and bc[1] >= 0 and bc[0]+bc[1] <= 1)) continue;

        const z = points[0][2]*bc[0] + points[1][2]*bc[1] + points[2][2]*bc[2];
        if (z >= 1 and z<zbuffer[y*width+x]) {
            zbuffer[y*width+x] = z;
            pixels[y][x] = color;
        }
    };
}

fn drawPoint(comptime T: type, point: [2]T, color: [4]u8) void {
    const pixels: *[height][width][4]u8 = @ptrCast(&image);

    switch (T) {
        usize => pixels[point[1]][point[0]] = color,
        f32 => {
            const x = std.math.clamp(point[0], 0, width-1);
            const y = std.math.clamp(point[1], 0, height-1);
            const xu: usize = @intFromFloat(x);
            const yu: usize = @intFromFloat(y);
            pixels[yu][xu] = color;
        },
        else => @compileError("Cant draw point with the provided type"),
    }
}

// Source: https://en.wikipedia.org/wiki/Bresenham's_line_algorithm
fn drawLine(p0: [2]f32, p1: [2]f32, color: [4]u8) void {
    const dx = @abs(p1[0]-p0[0]);
    const dy = -@abs(p1[1]-p0[1]);
    const sx: f32 = if (p0[0] < p1[0]) 1 else -1;
    const sy: f32 = if (p0[1] < p1[1]) 1 else -1;

    var x = p0[0];
    var y = p0[1];
    var err = 2 * (dx + dy);

    const llimit = std.math.clamp(p0[0], 0, width-1);
    const rlimit = std.math.clamp(p1[0], 0, width-1);
    var llu: usize = @intFromFloat(llimit);
    var rlu: usize = @intFromFloat(rlimit);
    if (llu > rlu) std.mem.swap(usize, &llu, &rlu);

    for (llu..rlu) |_| {
        drawPoint(f32, .{ x, y }, color);

        if (err >= dy) {
            err += 2*dy;
            x += sx;
        }

        if (err <= dx) {
            err += 2*dx;
            y += sy;
        }
    }
}

var objs: Objs = undefined;

export fn init() void {
    for (0..width*height) |i| {
        image[4*i+3] = 0xff;
    }

    objs = Objs.readFromFile(std.heap.wasm_allocator, "build/objects.bin") catch @panic("Bruh");
}

// You are expected to invoke this from the browser console
export fn setMode(request: u32) void {
    mode = @enumFromInt(request);
}

export fn draw() void {
    @memset(&zbuffer, std.math.inf(f32));
    @memset(&image, 0);
    for (0..width*height) |i| {
        image[4*i+3] = 0xff;
    }

    const S = struct {
        var dz: f32 = 5;

        var colors = [12][4]u8{
            .{ 165, 0, 33, 0xff },
            .{ 251, 96, 127, 0xff },
            .{ 220, 20, 60, 0xff },
            .{ 255, 192, 203, 0xff },
            .{ 255, 145, 164, 0xff },
            .{ 197, 30, 58, 0xff },
            .{ 190, 0, 50, 0xff },
            .{ 220, 52, 59, 0xff },
            .{ 150, 0, 24, 0xff },
            .{ 230, 0, 38, 0xff },
            .{ 218, 44, 67, 0xff },
            .{ 88, 17, 26, 0xff },
        };
    };

    //const obj = objs.map.get("example.obj").?;
    const obj = objs.map.get("teapot.obj").?;
    //const obj = objs.map.get("tsodinCupLowPoly.obj").?;

    S.dz += 0.005;

    for (obj.faces, 0..) |face, fi| switch (mode) {
        .flat => {
            var sq = [3][3]f32 {
                obj.vertices[face[0]-1],
                obj.vertices[face[1]-1],
                obj.vertices[face[2]-1],
            };

            sq[0][2] += S.dz;
            sq[1][2] += S.dz;
            sq[2][2] += S.dz;

            drawTriangle(sq, S.colors[fi%S.colors.len]);
        },
        .wireframe => {
            for (0..3) |i| {
                const v0 = obj.vertices[face[i]-1];
                const v1 = obj.vertices[face[(i+1)%3]-1];
                const p0 = .{
                    ((v0[0]/(1-v0[2]-S.dz))+1)*width/2,
                    ((v0[1]/(1-v0[2]-S.dz))+1)*height/2,
                };
                const p1 = .{
                    ((v1[0]/(1-v1[2]-S.dz))+1)*width/2,
                    ((v1[1]/(1-v1[2]-S.dz))+1)*height/2,
                };
                drawLine(p0, p1, .{ 0xff, 0xff, 0xff, 0xff });
            }
        },
    };
}
