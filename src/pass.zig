const std = @import("std");
const constants = @import("ansi.zig");

pub const Pass = struct {
    output: std.ArrayList(u8),
    allocator: std.mem.Allocator,
    prevLines: usize = 0,
    currentLines: usize = 0,

    pub fn init(allocator: std.mem.Allocator) Pass {
        return .{
            .output = .{},
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

    pub fn flush(pass: *Pass, time: i128) void {
        const stdout = std.fs.File.stdout();
        var escape: [24]u8 = undefined;
        if (pass.prevLines > 0) {
            const seq = std.fmt.bufPrint(&escape, "\x1b[{d}F\x1b[0J", .{pass.prevLines}) catch unreachable;
            stdout.writeAll(seq) catch unreachable;
        } else {
            const seq = std.fmt.bufPrint(&escape, "\x1B[2K\r", .{}) catch unreachable;
            stdout.writeAll(seq) catch unreachable;
        }
        stdout.writeAll(pass.output.items) catch unreachable;
        pass.output.clearRetainingCapacity();
        pass.prevLines = pass.currentLines;
        pass.currentLines = 0;
        if (time > 0) {
            pass.prevLines += 1;
            var buf: [32]u8 = undefined;
            const elapsed_ms = @as(f64, @floatFromInt(std.time.nanoTimestamp() - time)) / @as(f64, @floatFromInt(std.time.ns_per_ms));
            const s = std.fmt.bufPrint(&buf, "\n{s}render: {d:.2} ms{s}", .{ constants.COLOR_DIM, elapsed_ms, constants.COLOR_RESET }) catch unreachable;
            stdout.writeAll(s) catch unreachable;
        }
    }
};
