const std = @import("std");
const posix = std.posix;
const constants = @import("renderer/const.zig");

pub const InputMonitor = struct {
    buf: [constants.INPUT_BUFFER_SIZE]InputEvent = undefined,
    mutex: std.Thread.Mutex = .{},

    // Internal buffer
    head: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    tail: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
    // Lifecycle
    thread: ?std.Thread = null,
    cleanup: std.atomic.Value(bool),

    pub fn init() InputMonitor {
        return .{
            .cleanup = std.atomic.Value(bool).init(false),
        };
    }

    fn loop(monitor: *InputMonitor) !void {
        var read_buf: [1]u8 = undefined;
        while (!monitor.cleanup.load(.acquire)) {
            _ = try posix.read(posix.STDIN_FILENO, &read_buf);
            monitor.mutex.lock();
            defer monitor.mutex.unlock();

            const cTail = monitor.tail.load(.acquire);
            const cHead = monitor.head.load(.acquire);

            const next = (cTail + 1) % constants.INPUT_BUFFER_SIZE;
            if (next == cHead) {
                continue;
            }

            switch (read_buf[0]) {
                // 0x01...0x1F => monitor.buf[monitor.buf.len - 1] = .{
                //     .ctrl_key = ctrl(read_buf[0]),
                // },
                ctrl('C') => std.process.exit(0),
                '\r', '\n' => {
                    monitor.buf[cTail] = .{ .newline = {} };
                    monitor.tail.store(next, .release);
                },
                0x7f, ctrl('H') => {
                    monitor.buf[cTail] = .{ .backspace = {} };
                    monitor.tail.store(next, .release);
                },
                else => {
                    monitor.buf[cTail] = .{ .key = read_buf[0] };
                    monitor.tail.store(next, .release);
                },
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

    pub fn start(monitor: *InputMonitor) !void {
        monitor.thread = try std.Thread.spawn(.{}, loop, .{monitor});
    }
};

fn ctrl(comptime c: u8) u8 {
    return c & 0x1F;
}

pub const InputEvent = union(enum) {
    key: u8,
    ctrl_key: u8,
    newline,
    backspace,
};
