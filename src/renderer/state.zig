const Pass = @import("pass.zig").Pass;
pub const State = struct {
    lines: []StateLine,
};

pub const StateLine = union(enum) {
    in_progress: InProgress,
    input: Input,
    text: Text,
};

const TextStyle = enum {
    regular,
    bold,
    dim,

    const RESET = "\x1b[0m";

    fn to_code(style: TextStyle) []const u8 {
        return switch (style) {
            .regular => .{},
            .bold => .{ "\x1b[1m" },
            .dim => .{ "\x1b[2m" },
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
        try pass.write(TextStyle.to_code(text.style));
        try pass.write(text.text);
        try pass.write(TextStyle.RESET);
        try pass.endLine();
    }
};

pub const InProgressStatus = enum {
    in_progress,
    success,
    failure,
};
pub const InProgressType = enum {
    indeterminate,
    determinate,
};
pub const InProgress = struct {
    title: []const u8,
    status: InProgressStatus,
    type: InProgressType,
    value: f32,
    max: f32,

    pub fn indeterminate(title: []const u8) InProgress {
        return .{
            .title = title,
            .status = .in_progress,
            .type = .indeterminate,
            .value = 0,
            .max = 0,
        };
    }

    pub fn determinate(title: []const u8, value: f32, max: f32) InProgress {
        return .{
            .title = title,
            .status = .in_progress,
            .type = .determinate,
            .value = value,
            .max = max,
        };
    }
};

pub const Input = struct {
    prompt: []const u8,
    value: []const u8,
    validation: ?*const fn (value: []const u8) bool,

    pub fn init(prompt: []const u8) Input {
        return .{
            .prompt = prompt,
            .value = "",
            .validation = null,
        };
    }
};
