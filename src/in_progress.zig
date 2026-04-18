const std = @import("std");
const Pass = @import("pass.zig").Pass;
const constants = @import("ansi.zig");

pub const InProgressStatus = enum {
    in_progress,
    success,
    failure,
};

pub const InProgressType = union(enum) {
    indeterminate: InProgressSpinner,
    determinate,
};

pub const InProgressSpinner = enum {
    dots,
    breath,
    pulse,
    sparkle,
    noise,
    balloon,
    wave,
    grow,
    ping,
    arc,
    matrix,
    hourglass,

    fn chars(spinner: InProgressSpinner) []const []const u8 {
        return switch (spinner) {
            .dots => &.{ "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
            .breath => &.{ "·", "•", "◦", "○", "◦", "•" },
            .pulse => &.{ "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█", "▇", "▆", "▅", "▄", "▃", "▂" },
            .sparkle => &.{ "✦", "✧", "✶", "✷", "✸", "✺", "✹", "✸", "✷", "✶", "✧" },
            .noise => &.{ "░", "▒", "▓", "█", "▓", "▒", "░" },
            .balloon => &.{ ".", "o", "O", "@", "*", "O", "o" },
            .wave => &.{ "▁", "▂", "▄", "▆", "█", "▆", "▄", "▂" },
            .grow => &.{ "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█" },
            .ping => &.{ "∙", "·", "○", "◎", "⊙", "◎", "○", "·" },
            .arc => &.{ "◜", "◠", "◝", "◞", "◡", "◟" },
            .matrix => &.{ "⡿", "⣟", "⣯", "⣷", "⣾", "⣽", "⣻", "⢿" },
            .hourglass => &.{ "⧗", "⧗", "⧗", "⧖", "⧖", "⧖" },
        };
    }
};

pub const InProgress = struct {
    lock: *std.Io.Mutex,

    title: []const u8,
    subtitle: ?[]const u8,
    status: InProgressStatus,
    type: InProgressType,
    value: f32,
    max: f32,
    phase: usize = 0,
    phase_speed: usize = 6, // Frames per phase

    pub fn complete(line: *InProgress, io: std.Io, title: []const u8) void {
        line.lock.lock(io) catch return;
        defer line.lock.unlock(io);
        line.status = .success;
        line.title = title;
    }

    pub fn sub(line: *InProgress, io: std.Io, subtitle: []const u8) void {
        line.lock.lock(io) catch return;
        defer line.lock.unlock(io);
        line.subtitle = subtitle;
    }

    pub fn setSpinner(line: *InProgress, io: std.Io, spinner: InProgressSpinner) void {
        line.lock.lock(io) catch return;
        defer line.lock.unlock(io);
        line.type = .{ .indeterminate = spinner };
    }

    pub fn render(line: *InProgress, pass: *Pass) void {
        pass.startLine();
        switch (line.status) {
            .in_progress => {
                switch (line.type) {
                    .indeterminate => |spinner| {
                        pass.write(spinner.chars()[line.phase / line.phase_speed]);
                        line.phase += 1;
                        if (line.phase / line.phase_speed >= spinner.chars().len) {
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
