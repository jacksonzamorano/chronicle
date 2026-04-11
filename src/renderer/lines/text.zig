const Pass = @import("../pass.zig").Pass;

pub const TextStyle = enum {
    regular,
    bold,
    dim,

    const RESET = "\x1b[0m";

    fn toCode(style: TextStyle) []const u8 {
        return switch (style) {
            .regular => .{},
            .bold => .{"\x1b[1m"},
            .dim => .{"\x1b[2m"},
        };
    }
};

pub const Text = struct {
    text: []const u8,
    style: TextStyle,

    pub fn init(text: []const u8) Text {
        return .{
            .text = text,
            .style = .regular,
        };
    }

    pub fn render(text: Text, pass: *Pass) !void {
        try pass.startLine();
        try pass.write(TextStyle.toCode(text.style));
        try pass.write(text.text);
        try pass.write(TextStyle.RESET);
    }
};
