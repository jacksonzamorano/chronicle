const std = @import("std");
const Pass = @import("../pass.zig").Pass;
const TextStyle = @import("../const.zig").TextStyle;
const COLOR_RESET = @import("../const.zig").COLOR_RESET;

pub const Text = struct {
    lock: *std.Thread.Mutex,
    text: []const u8,
    style: TextStyle,

    pub fn render(text: Text, pass: *Pass) !void {
        try pass.startLine();
        try pass.write(TextStyle.toCode(text.style));
        try pass.write(text.text);
        try pass.write(COLOR_RESET);
    }

    pub fn changeStyle(text: *Text, style: TextStyle) void {
        text.lock.lock();
        defer text.lock.unlock();
        text.style = style;
    }

    pub fn changeText(text: *Text, t: []const u8) void {
        text.lock.lock();
        defer text.lock.unlock();
        text.text = t;
    }
};
