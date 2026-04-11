const std = @import("std");
const Pass = @import("pass.zig").Pass;
const constants = @import("ansi.zig");

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
    const SPINNER_CHARS = [_][]const u8{ "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" };

    lock: *std.Thread.Mutex,

    title: []const u8,
    subtitle: ?[]const u8,
    status: InProgressStatus,
    type: InProgressType,
    value: f32,
    max: f32,
    phase: usize = 0,

    pub fn complete(line: *InProgress, title: []const u8) void {
        line.lock.lock();
        defer line.lock.unlock();
        line.status = .success;
        line.title = title;
    }

    pub fn sub(line: *InProgress, subtitle: []const u8) void {
        line.lock.lock();
        defer line.lock.unlock();
        line.subtitle = subtitle;
    }

    pub fn render(line: *InProgress, pass: *Pass) void {
        pass.startLine();
        switch (line.status) {
            .in_progress => {
                switch (line.type) {
                    .indeterminate => {
                        pass.write(SPINNER_CHARS[line.phase]);
                        line.phase += 1;
                        if (line.phase >= SPINNER_CHARS.len) {
                            line.phase = 0;
                        }
                    },
                    .determinate => {
                        var buf: [10]u8 = undefined;
                        const value = std.fmt.bufPrint(&buf, "{}%", .{line.value * 100 / line.max}) catch unreachable;
                        pass.write(value);
                    },
                }
            },
            .success => {
                pass.write(constants.COLOR_GREEN);
                pass.write("✔");
                pass.write(constants.COLOR_RESET);
            },
            .failure => {
                pass.write(constants.COLOR_RED);
                pass.write("✘");
                pass.write(constants.COLOR_RESET);
            },
        }
        pass.write(" ");
        pass.write(line.title);
        if (line.status == .in_progress) {
            if (line.subtitle) |subtitle| {
                pass.subLine();
                pass.write(constants.COLOR_DIM);
                pass.write(subtitle);
                pass.write(constants.COLOR_RESET);
            }
        }
    }
};
