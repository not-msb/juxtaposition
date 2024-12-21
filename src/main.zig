const std = @import("std");

extern fn print(i32) void;

export const width: u32 = 800;
export const height: u32 = 600;
export var image: [4*width*height]u8 = undefined;

fn drawBotTriangle(proj: [3][2]f32, color: [4]u8) void {
    const lslope = (proj[1][0] - proj[0][0]) / (proj[1][1] - proj[0][1]);
    const rslope = (proj[2][0] - proj[0][0]) / (proj[2][1] - proj[0][1]);

    var lproj = proj[0][0];
    var rproj = proj[0][0];

    const pixels: *[width*height][4]u8 = @ptrCast(&image);
    const ystart: usize = @intFromFloat(proj[0][1]);
    const yend: usize = @intFromFloat(proj[1][1]);

    for (ystart..yend+1) |scanline| {
        if (scanline >= height) break;
        const lproji: usize = @intFromFloat(@min(width, @max(0, lproj)));
        const rproji: usize = @intFromFloat(@min(width, @max(0, rproj)));
        const slice = switch (lproji <= rproji) {
            true => pixels[scanline*width+@min(width, lproji)..scanline*width+@min(width, rproji)],
            false => pixels[scanline*width+@min(width, rproji)..scanline*width+@min(width, lproji)],
        };
        @memset(slice, color);

        lproj += lslope;
        rproj += rslope;
    }
}

fn drawTopTriangle(proj: [3][2]f32, color: [4]u8) void {
    const lslope = (proj[2][0] - proj[0][0]) / (proj[2][1] - proj[0][1]);
    const rslope = (proj[2][0] - proj[1][0]) / (proj[2][1] - proj[1][1]);

    var lproj = proj[0][0];
    var rproj = proj[1][0];

    const pixels: *[width*height][4]u8 = @ptrCast(&image);
    const ystart: usize = @intFromFloat(proj[0][1]);
    const yend: usize = @intFromFloat(proj[2][1]);

    for (ystart..yend+1) |scanline| {
        if (scanline >= height) break;
        const lproji: usize = @intFromFloat(@min(width, @max(0, lproj)));
        const rproji: usize = @intFromFloat(@min(width, @max(0, rproj)));
        const slice = switch (lproji <= rproji) {
            true => pixels[scanline*width+lproji..scanline*width+rproji],
            false => pixels[scanline*width+rproji..scanline*width+lproji],
        };
        @memset(slice, color);

        lproj += lslope;
        rproj += rslope;
    }
}

fn drawTriangle(points: [3][3]f32, color: [4]u8) void {
    const gen = struct {
        fn lessThanFn(context: void, lhs: [2]f32, rhs: [2]f32) bool {
            _ = context;
            return lhs[1] < rhs[1];
        }
    };

    var proj: [3][2]f32 = .{
        .{ points[0][0] / points[0][2] + width/2, points[0][1] / points[0][2] + height/2 },
        .{ points[1][0] / points[1][2] + width/2, points[1][1] / points[1][2] + height/2 },
        .{ points[2][0] / points[2][2] + width/2, points[2][1] / points[2][2] + height/2 },
    };
    std.mem.sort([2]f32, &proj, {}, gen.lessThanFn);

    if (proj[1][1] == proj[2][1])
        drawBotTriangle(proj, color)
    else if (proj[0][1] == proj[1][1])
        drawTopTriangle(proj, color)
    else {
        const split = [2]f32{
            proj[0][0] + ((proj[1][1] - proj[0][1]) / (proj[2][1] - proj[0][1])) * (proj[2][0] - proj[0][0]),
            proj[1][1]
        };
        drawBotTriangle(.{ proj[0], proj[1], split }, color);
        drawTopTriangle(.{ proj[1], split, proj[2] }, color);
    }

    //drawDownTriangle(points, color);
}

export fn init() void {
    for (0..width*height) |i| {
        image[4*i+3] = 0xff;
    }
}

export fn draw() void {
    //const S = struct {
    //    var p0: [3]f32 = .{ 75, 50, 1 };
    //};

    @memset(&image, 0);
    for (0..width*height) |i| {
        image[4*i+3] = 0xff;
    }

    //S.p0[0] -= 1;
    ////S.p0[1] += 1;

    //drawTriangle(.{
    //    S.p0,
    //    //.{ 75, 50, 1 },
    //    .{ 50, 500, 1 },
    //    .{ 500, 500, 1 },
    //}, .{ 0xff, 0, 0, 0xff });

    //drawTriangle(.{
    //    .{ 50, 100, 1 },
    //    .{ 100, 100, 1 },
    //    .{ 200, 300, 1 },
    //}, .{ 0, 0, 0xff, 0xff });

    const S = struct {
        var z: f32 = 2;
        var dx: f32 = 0;
    };

    //S.z += 0.5;
    S.dx -= 1;

    const sq0 = [3][3]f32 {
        [3]f32{ S.dx+50, 50, S.z },
        [3]f32{ S.dx+50, 500, 1 },
        [3]f32{ S.dx+500, 500, 1 },
    };

    const sq1 = [3][3]f32 {
        [3]f32{ S.dx+50, 50, S.z },
        [3]f32{ S.dx+500, 50, S.z },
        [3]f32{ S.dx+500, 500, 1 },
    };

    drawTriangle(sq0, .{ 0xff, 0, 0, 0xff });
    drawTriangle(sq1, .{ 0, 0, 0xff, 0xff });
}
