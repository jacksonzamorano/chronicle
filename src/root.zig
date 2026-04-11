//! By convention, root.zig is the root source file when making a library.
pub const Application = @import("application.zig").Application;
pub const TextStyle = @import("ansi.zig").TextStyle;
pub const Text = @import("text.zig").Text;
pub const Input = @import("input.zig").Input;
pub const InputFinalizationBehavior = @import("input.zig").InputFinalizationBehavior;
pub const InProgress = @import("in_progress.zig").InProgress;
pub const InProgressStatus = @import("in_progress.zig").InProgressStatus;
pub const InProgressType = @import("in_progress.zig").InProgressType;
