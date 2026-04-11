pub const InProgressStatus = @import("in_progress.zig").InProgressStatus;
pub const InProgressType = @import("in_progress.zig").InProgressType;
pub const InProgress = @import("in_progress.zig").InProgress;

pub const Text = @import("text.zig").Text;

pub const Input = @import("input.zig").Input;

pub const StateLine = union(enum) {
    in_progress: *InProgress,
    input: *Input,
    text: *Text,
};
