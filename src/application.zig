pub const Application = struct {
    lines: std.ArrayList(StateLine),
    currentFocus: ?StateLine = undefined,
    pass: Pass,
    input: InputMonitor,

    lock: std.Thread.Mutex,
    allocator: std.mem.Allocator,

    tick_time: u64 = 60,
    debug: bool = false,

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

    fn renderAll(state: *Application) void {
        for (state.lines.items) |line| {
            switch (line) {
                inline else => |l| {
                    if (@hasDecl(@TypeOf(l.*), "render")) {
                        l.render(&state.pass);
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

    fn loop(state: *Application) void {
        state.input.start();
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
            state.renderAll();
            state.pass.flush(if (state.debug) tick else 0);
            state.lock.unlock();
            std.Thread.sleep(state.tick_time * std.time.ns_per_ms);
        }

        state.renderAll();
        state.pass.flush(0);
        const stdout = std.fs.File.stdout();
        stdout.writeAll("\n") catch unreachable;
    }

    fn addLine(state: *Application, line: StateLine) void {
        state.lock.lock();
        defer state.lock.unlock();
        state.lines.append(state.allocator, line) catch unreachable;
    }

    pub fn createIndeterminate(state: *Application, title: []const u8) *InProgress {
        const loader = state.allocator.create(InProgress) catch unreachable;
        loader.* = .{
            .lock = &state.lock,
            .title = title,
            .subtitle = null,
            .status = .in_progress,
            .type = .indeterminate,
            .max = 0,
            .value = 0,
        };
        state.addLine(.{ .in_progress = loader });
        return loader;
    }

    pub fn createText(state: *Application, t: []const u8) *Text {
        const text = state.allocator.create(Text) catch unreachable;
        text.* = .{
            .lock = &state.lock,
            .text = t,
            .style = .regular,
        };
        state.addLine(.{ .text = text });
        return text;
    }

    pub fn createInput(state: *Application, prompt: []const u8) *Input {
        const input = state.allocator.create(Input) catch unreachable;
        input.* = .{
            .lock = &state.lock,
            .allocator = state.allocator,
            .prompt = prompt,
            .value = undefined,
            .temporaryValue = .{},
            .validation = null,
            .completed = .{},
        };
        state.addLine(.{ .input = input });
        return input;
    }

    pub fn start(state: *Application) void {
        const original = posix.tcgetattr(posix.STDIN_FILENO) catch unreachable;
        var raw = original;

        raw.iflag.BRKINT = false;
        raw.iflag.ICRNL = false;
        raw.iflag.INPCK = false;
        raw.iflag.ISTRIP = false;
        raw.iflag.IXON = false;

        raw.cflag.CSIZE = .CS8;

        raw.lflag.ECHO = false;
        raw.lflag.ICANON = false;
        raw.lflag.IEXTEN = false;
        raw.lflag.ISIG = false;

        raw.cc[@intFromEnum(posix.V.MIN)] = 1;
        raw.cc[@intFromEnum(posix.V.TIME)] = 0;

        posix.tcsetattr(posix.STDIN_FILENO, .FLUSH, raw) catch unreachable;
        state.thread = std.Thread.spawn(.{}, loop, .{state}) catch unreachable;
        state.og_mode = original;
    }

    pub fn stop(state: *Application) void {
        if (state.og_mode) |original| {
            posix.tcsetattr(posix.STDIN_FILENO, .FLUSH, original) catch unreachable;
        }
        state.cleanup.store(true, .release);
        if (state.thread) |t| t.join();
    }
};

const std = @import("std");
const posix = std.posix;

const Pass = @import("pass.zig").Pass;
const StateLine = @import("state_line.zig").StateLine;
const InProgress = @import("in_progress.zig").InProgress;
const Text = @import("text.zig").Text;
const Input = @import("input.zig").Input;
const InputMonitor = @import("input_monitor.zig").InputMonitor;
const InputEvent = @import("input_monitor.zig").InputEvent;
const constants = @import("ansi.zig");
