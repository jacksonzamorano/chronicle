const std = @import("std");
const constants = @import("ansi.zig");

pub const Pass = struct {
    output: std.ArrayList(u8),
    allocator: std.mem.Allocator,
    prevLines: usize = 0,
    currentLines: usize = 0,

    pub fn init(allocator: std.mem.Allocator) Pass {
        return .{
            .output = .empty,
            .allocator = allocator,
        };
    }

    pub fn startLine(pass: *Pass) void {
        pass.currentLines += 1;
        pass.write("\n ∟ ");
    }

    pub fn subLine(pass: *Pass) void {
        pass.write("\n   ");
        pass.currentLines += 1;
    }

    pub fn write(pass: *Pass, bytes: []const u8) void {
        pass.output.appendSlice(pass.allocator, bytes) catch unreachable;
    }

    pub fn flush(pass: *Pass, io: std.Io) void {
        const stdout = std.Io.File.stdout();
        var escape: [24]u8 = undefined;
        if (pass.prevLines > 0) {
            const seq = std.fmt.bufPrint(&escape, "\x1b[{d}F\x1b[0J", .{pass.prevLines}) catch unreachable;
            stdout.writeStreamingAll(io, seq) catch unreachable;
        } else {
            const seq = std.fmt.bufPrint(&escape, "\x1B[2K\r", .{}) catch unreachable;
            stdout.writeStreamingAll(io, seq) catch unreachable;
        }
        stdout.writeStreamingAll(io, pass.output.items) catch unreachable;
        pass.output.clearRetainingCapacity();
        pass.prevLines = pass.currentLines;
        pass.currentLines = 0;
    }
};
