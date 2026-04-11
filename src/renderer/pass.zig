const std = @import("std");
pub const Pass = struct {
    output: std.ArrayList(u8),
    lineCount: usize = 0,

    pub fn init(allocator: *std.mem.Allocator) Pass {
        return .{
            .output = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn startLine(pass: *Pass) !void {
        pass.write("\n|\n");
        try pass.write("\n");
        pass.lineCount += 2;
    }

    pub fn write(pass: *Pass, bytes: []const u8) !usize {
        return pass.output.appendSlice(bytes);
    }
};
