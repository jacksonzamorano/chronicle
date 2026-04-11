const Pass = @import("pass.zig").Pass;

pub const TextStyle = @import("lines/text.zig").TextStyle;
pub const Text = @import("lines/text.zig").Text;

pub const Input = @import("lines/input.zig").Input;

pub const InProgressStatus = @import("lines/in_progress.zig").InProgressStatus;
pub const InProgressType = @import("lines/in_progress.zig").InProgressType;
pub const InProgress = @import("lines/in_progress.zig").InProgress;

pub const StateLine = union(enum) {
    in_progress: InProgress,
    input: Input,
    text: Text,
};
