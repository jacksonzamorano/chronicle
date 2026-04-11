const std = @import("std");
const posix = std.posix;
const constants = @import("ansi.zig");

pub const InputMonitor = struct {
    buf: [constants.INPUT_BUFFER_SIZE]InputEvent = undefined,
    mutex: std.Thread.Mutex = .{},

    head: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    tail: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    thread: ?std.Thread = null,
    cleanup: std.atomic.Value(bool),

    pub fn init() InputMonitor {
        return .{
            .cleanup = std.atomic.Value(bool).init(false),
        };
    }

    fn loop(monitor: *InputMonitor) void {
        var read_buf: [1]u8 = undefined;
        while (!monitor.cleanup.load(.acquire)) {
            _ = posix.read(posix.STDIN_FILENO, &read_buf) catch unreachable;
            monitor.mutex.lock();
            defer monitor.mutex.unlock();

            const cTail = monitor.tail.load(.acquire);
            const cHead = monitor.head.load(.acquire);

            const next = (cTail + 1) % constants.INPUT_BUFFER_SIZE;
            if (next == cHead) {
                continue;
            }

            if (parseInput(read_buf[0])) |ev| {
                monitor.buf[cTail] = ev;
                monitor.tail.store(next, .release);
            }
        }
    }

    pub fn read(monitor: *InputMonitor, buf: *[constants.INPUT_BUFFER_SIZE]InputEvent) usize {
        monitor.mutex.lock();
        defer monitor.mutex.unlock();
        var cHead = monitor.head.load(.acquire);
        const cTail = monitor.tail.load(.acquire);

        var idx: usize = 0;
        while (cHead != cTail) {
            buf[idx] = monitor.buf[cHead];
            cHead = (cHead + 1) % constants.INPUT_BUFFER_SIZE;
            idx += 1;
        }

        monitor.head.store(cHead, .release);
        return idx;
    }

    pub fn start(monitor: *InputMonitor) void {
        monitor.thread = std.Thread.spawn(.{}, loop, .{monitor}) catch unreachable;
    }
};

fn ctrl(comptime c: u8) u8 {
    return c & 0x1F;
}

fn parseInput(byte: u8) ?InputEvent {
    return switch (byte) {
        '\r', '\n' => .{ .newline = {} },
        0x7f, ctrl('H') => .{ .backspace = {} },
        9 => .{ .tab = {} },
        ctrl('L') => .{ .clear = {} },
        ctrl('U') => .{ .kill_line = {} },
        ctrl('W') => .{ .delete_word = {} },
        1...7, // ctrl+A through ctrl+G
        11, // ctrl+K
        14...20, // ctrl+N through ctrl+T
        22, // ctrl+V
        24...26, // ctrl+X through ctrl+Z
        => .{ .ctrl_key = byte + '@' },
        '\x1b' => blk: {
            var seq_buf: [2]u8 = undefined;
            _ = posix.read(posix.STDIN_FILENO, &seq_buf) catch unreachable;
            break :blk if (seq_buf[0] == '[')
                switch (seq_buf[1]) {
                    'A' => InputEvent{ .arrow_up = {} },
                    'B' => InputEvent{ .arrow_down = {} },
                    'C' => InputEvent{ .arrow_right = {} },
                    'D' => InputEvent{ .arrow_left = {} },
                    else => null,
                }
            else
                null;
        },
        else => .{ .key = byte },
    };
}

pub const InputEvent = union(enum) {
    key: u8,
    ctrl_key: u8,
    newline,
    backspace,
    tab,
    clear,
    kill_line,
    delete_word,
    arrow_up,
    arrow_down,
    arrow_left,
    arrow_right,
};
