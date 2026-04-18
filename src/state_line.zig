pub const InProgress = @import("in_progress.zig").InProgress;
pub const InProgressStatus = @import("in_progress.zig").InProgressStatus;
pub const InProgressType = @import("in_progress.zig").InProgressType;
pub const Input = @import("input.zig").Input;
pub const Text = @import("text.zig").Text;
const std = @import("std");

pub const StateLine = union(enum) {
    in_progress: *InProgress,
    input: *Input,
    text: *Text,

    pub fn render(line: *StateLine, pass: *@import("pass.zig").Pass) void {
        switch (line.*) {
            inline else => |*l| l.*.render(pass),
        }
    }
};
