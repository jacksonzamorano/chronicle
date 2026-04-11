pub const Application = struct {
    lines: std.ArrayList(StateLine),
    currentFocus: ?StateLine = undefined,
    pass: Pass,
    input: InputMonitor,

    // Memory & thread safety
    lock: std.Thread.Mutex,
    allocator: std.mem.Allocator,

    // Configuration
    tick_time: u64 = 60,
    debug: bool = false,

    // Lifecycle
    cleanup: std.atomic.Value(bool),
    thread: ?std.Thread = null,
    og_mode: ?posix.termios = null,

    pub fn init(allocator: std.mem.Allocator) Application {
        const input = InputMonitor.init();
        return .{
            .lines = .{},
            .pass = Pass.init(allocator),
            .lock = .{},
            .allocator = allocator,
            .cleanup = std.atomic.Value(bool).init(false),
            .input = input,
        };
    }

    fn renderAll(state: *Application) !void {
        for (state.lines.items) |line| {
            switch (line) {
                inline else => |l| {
                    if (@hasDecl(@TypeOf(l.*), "render")) {
                        try l.render(&state.pass);
                    }
                },
            }
        }
    }

    pub fn focusInput(state: *Application, input: *Input) void {
        state.lock.lock();
        defer state.lock.unlock();
        state.currentFocus = .{ .input = input };
    }

    fn loop(state: *Application) !void {
        state.input.start() catch {};
        var inputBuf: [constants.INPUT_BUFFER_SIZE]InputEvent = undefined;
        var inputBufIdx: usize = 0;
        while (!state.cleanup.load(.acquire)) : (inputBufIdx = 0) {
            const inputCount = state.input.read(&inputBuf);
            if (state.currentFocus) |focus| {
                switch (focus) {
                    inline else => |f| {
                        if (@hasDecl(@TypeOf(f.*), "onInput")) {
                            while (inputBufIdx < inputCount) {
                                const done = f.onInput(inputBuf[inputBufIdx]);
                                if (done) {
                                    state.currentFocus = null;
                                    break;
                                }
                                inputBufIdx += 1;
                            }
                        }
                    },
                }
            }
            state.lock.lock();
            const tick = std.time.nanoTimestamp();
            try state.renderAll();
            try state.pass.flush(if (state.debug) tick else 0);
            state.lock.unlock();
            std.Thread.sleep(state.tick_time * std.time.ns_per_ms);
        }

        try state.renderAll();
        try state.pass.flush(0);
        const stdout = std.fs.File.stdout();
        try stdout.writeAll("\n");
    }

    fn addLine(state: *Application, line: StateLine) !void {
        state.lock.lock();
        defer state.lock.unlock();
        try state.lines.append(state.allocator, line);
    }

    pub fn createIndeterminate(state: *Application, title: []const u8) !*InProgress {
        const loader = try state.allocator.create(InProgress);
        loader.* = .{
            .lock = &state.lock,
            .title = title,
            .subtitle = null,
            .status = .in_progress,
            .type = .indeterminate,
            .max = 0,
            .value = 0,
        };
        try state.addLine(.{ .in_progress = loader });
        return loader;
    }

    pub fn createText(state: *Application, t: []const u8) !*Text {
        const text = try state.allocator.create(Text);
        text.* = .{
            .lock = &state.lock,
            .text = t,
            .style = .regular,
        };
        try state.addLine(.{ .text = text });
        return text;
    }

    pub fn createInput(state: *Application, prompt: []const u8) !*Input {
        const input = try state.allocator.create(Input);
        input.* = .{
            .lock = &state.lock,
            .allocator = state.allocator,
            .prompt = prompt,
            .value = undefined,
            .temporaryValue = .{},
            .validation = null,
            .completed = .{},
        };
        try state.addLine(.{ .input = input });
        return input;
    }

    pub fn start(state: *Application) !void {
        const original = try posix.tcgetattr(posix.STDIN_FILENO);
        var raw = original;

        // Input flags
        raw.iflag.BRKINT = false;
        raw.iflag.ICRNL = false;
        raw.iflag.INPCK = false;
        raw.iflag.ISTRIP = false;
        raw.iflag.IXON = false;

        // Control flags
        raw.cflag.CSIZE = .CS8;

        // Local flags
        raw.lflag.ECHO = false;
        raw.lflag.ICANON = false;
        raw.lflag.IEXTEN = false;
        raw.lflag.ISIG = false;

        // Read settings: return after 1 byte, no timeout
        raw.cc[@intFromEnum(posix.V.MIN)] = 1;
        raw.cc[@intFromEnum(posix.V.TIME)] = 0;

        try posix.tcsetattr(posix.STDIN_FILENO, .FLUSH, raw);
        state.thread = try std.Thread.spawn(.{}, loop, .{state});
        state.og_mode = original;
    }

    pub fn stop(state: *Application) void {
        if (state.og_mode) |original| {
            posix.tcsetattr(posix.STDIN_FILENO, .FLUSH, original) catch {};
        }
        state.cleanup.store(true, .release);
        if (state.thread) |t| t.join();
    }
};

const std = @import("std");
const posix = std.posix;

const Pass = @import("pass.zig").Pass;
pub const StateLine = @import("lines.zig").StateLine;
const InProgress = @import("lines/in_progress.zig").InProgress;
const Text = @import("lines/text.zig").Text;
const Input = @import("lines/input.zig").Input;
const InputMonitor = @import("../input.zig").InputMonitor;
const InputEvent = @import("../input.zig").InputEvent;
const constants = @import("const.zig");
