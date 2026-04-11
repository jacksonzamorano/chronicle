pub const State = struct {
    lines: std.ArrayList(StateLine),
    pass: *Pass,

    pub fn init(allocator: *std.mem.Allocator) !State {
        var pass = try Pass.init(allocator);
        return .{
            .lines = std.ArrayList(StateLine).init(allocator),
            .pass = &pass,
        };
    }
};

pub fn render(comptime line: anytype, pass: *Pass) !void {
    if (@hasDecl(line, "render")) {
        try line.render(pass);
    } else {
        @compileError("Line must have a render function");
    }
}

const std = @import("std");

const Pass = @import("pass.zig").Pass;
pub const StateLine = @import("lines.zig").StateLine;
