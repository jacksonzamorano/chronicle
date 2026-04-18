const std = @import("std");
const posix = std.posix;
const constants = @import("ansi.zig");

pub const Keyboard = struct {
    buf: [constants.INPUT_BUFFER_SIZE]InputEvent = undefined,
    mutex: std.Io.Mutex = .init,

    head: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    tail: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),

    task: ?std.Io.Future(void) = null,

    pub const init: Keyboard = .{};

    fn loop(monitor: *Keyboard, io: std.Io) void {
        const stdin = std.Io.File.stdin();
        var read_buf: [1]u8 = undefined;
        while (true) {
            io.checkCancel() catch break;
            const n = stdin.readStreaming(io, &.{read_buf[0..]}) catch break;
            if (n == 0) break;
            monitor.mutex.lock(io) catch unreachable;
            defer monitor.mutex.unlock(io);

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

    pub fn read(monitor: *Keyboard, io: std.Io, buf: *[constants.INPUT_BUFFER_SIZE]InputEvent) usize {
        monitor.mutex.lock(io) catch return 0;
        defer monitor.mutex.unlock(io);
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

    pub fn start(monitor: *Keyboard, io: std.Io) void {
        if (io.concurrent(Keyboard.loop, .{ monitor, io })) |t| {
            monitor.task = t;
        } else |_| {
            @panic("Failed to start input monitor");
        }
    }

    pub fn stop(monitor: *Keyboard, io: std.Io) void {
        if (monitor.task) |*t| t.cancel(io);
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
