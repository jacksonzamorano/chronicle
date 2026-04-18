const std = @import("std");
const Pass = @import("pass.zig").Pass;
const TextStyle = @import("ansi.zig").TextStyle;
const COLOR_RESET = @import("ansi.zig").COLOR_RESET;

pub const Text = struct {
    lock: *std.Io.Mutex,
    text: []const u8,
    style: TextStyle,

    pub fn render(text: Text, pass: *Pass) void {
        pass.startLine();
        pass.write(TextStyle.toCode(text.style));
        pass.write(text.text);
        pass.write(COLOR_RESET);
    }

    pub fn changeStyle(text: *Text, io: std.Io, style: TextStyle) void {
        text.lock.lock(io) catch unreachable;
        defer text.lock.unlock(io);
        text.style = style;
    }

    pub fn changeText(text: *Text, io: std.Io, t: []const u8) void {
        text.lock.lock(io);
        defer text.lock.unlock(io);
        text.text = t;
    }
};
