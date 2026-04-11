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
