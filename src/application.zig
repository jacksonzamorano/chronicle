const Keybind = struct {
    key: u8,
    action: *const fn (*Application, std.Io) void,
};
pub const Application = struct {
    lines: std.ArrayList(StateLine),
    currentFocus: ?StateLine = undefined,
    keybinds: std.ArrayList(Keybind),
    pass: Pass,
    input: Keyboard,

    lock: std.Io.Mutex,
    allocator: std.mem.Allocator,

    tick_time: u64 = 16,
    default_indeterminate: InProgressSpinner = .dots,
    debug: bool = false,

    og_mode: ?posix.termios = null,
    task: ?std.Io.Future(void) = null,

    pub fn init(allocator: std.mem.Allocator) Application {
        return .{
            .lines = .empty,
            .pass = Pass.init(allocator),
            .keybinds = .empty,
            .lock = .init,
            .allocator = allocator,
            .input = .init,
        };
    }

    fn renderAll(state: *Application) void {
        for (state.lines.items) |*line| {
            line.render(&state.pass);
        }
    }

    pub fn focusInput(state: *Application, io: std.Io, input: *Input) void {
        state.lock.lock(io) catch return;
        defer state.lock.unlock(io);
        state.currentFocus = .{ .input = input };
    }

    fn loop(state: *Application, io: std.Io) void {
        var inputBuf: [constants.INPUT_BUFFER_SIZE]InputEvent = undefined;
        var inputBufIdx: usize = 0;
        while (true) : (inputBufIdx = 0) {
            io.checkCancel() catch break;
            const inputCount = state.input.read(io, &inputBuf);
            input_loop: while (inputBufIdx < inputCount) {
                const input = inputBuf[inputBufIdx];
                switch (input) {
                    .ctrl_key => |c| {
                        for (state.keybinds.items) |keybind| {
                            if (keybind.key == c) {
                                keybind.action(state, io);
                                inputBufIdx += 1;
                                continue :input_loop;
                            }
                        }
                        if (c == 'C') {
                            std.process.exit(0);
                        }
                    },
                    else => {},
                }

                if (state.currentFocus) |focus| {
                    switch (focus) {
                        inline else => |f| {
                            if (@hasDecl(@TypeOf(f.*), "onInput")) {
                                const done = f.onInput(io, inputBuf[inputBufIdx]);
                                if (done) {
                                    state.currentFocus = null;
                                    break;
                                }
                                inputBufIdx += 1;
                            }
                        },
                    }
                }
            }
            state.lock.lock(io) catch return;
            state.renderAll();
            state.pass.flush(io);
            state.lock.unlock(io);
            io.sleep(.fromMilliseconds(16), .real) catch break;
        }

        state.renderAll();
        state.pass.flush(io);
        if (state.og_mode) |original| {
            posix.tcsetattr(posix.STDIN_FILENO, .FLUSH, original) catch unreachable;
        }
        const stdout = std.Io.File.stdout();
        stdout.writeStreamingAll(io, "\n") catch unreachable;
    }

    fn addLine(state: *Application, io: std.Io, line: StateLine) void {
        state.lock.lock(io) catch return;
        defer state.lock.unlock(io);
        state.lines.append(state.allocator, line) catch unreachable;
    }

    pub fn createIndeterminate(state: *Application, io: std.Io, title: []const u8) *InProgress {
        const loader = state.allocator.create(InProgress) catch unreachable;
        loader.* = .{
            .lock = &state.lock,
            .title = title,
            .subtitle = null,
            .status = .in_progress,
            .type = .{ .indeterminate = state.default_indeterminate },
            .max = 0,
            .value = 0,
        };
        state.addLine(io, .{ .in_progress = loader });
        return loader;
    }

    pub fn createText(state: *Application, io: std.Io, t: []const u8) *Text {
        const text = state.allocator.create(Text) catch unreachable;
        text.* = .{
            .lock = &state.lock,
            .text = t,
            .style = .regular,
        };
        state.addLine(io, .{ .text = text });
        return text;
    }

    pub fn createInput(state: *Application, io: std.Io, prompt: []const u8) *Input {
        const input = state.allocator.create(Input) catch unreachable;
        input.* = .{
            .lock = &state.lock,
            .allocator = state.allocator,
            .prompt = prompt,
            .value = undefined,
            .temporaryValue = .empty,
            .validation = null,
            .completed = .init,
        };
        state.addLine(io, .{ .input = input });
        return input;
    }

    pub fn start(state: *Application, io: std.Io) void {
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

        state.input.start(io) catch unreachable;
        state.og_mode = original;
        if (io.concurrent(loop, .{ state, io })) |t| {
            state.task = t;
        } else |_| {
            state.stop(io);

            const stdout = std.Io.File.stdout();
            stdout.writeStreamingAll(io, "Loop crashed.") catch unreachable;
        }
    }

    pub fn stop(state: *Application, io: std.Io) void {
        if (state.task) |*t| t.cancel(io);
    }

    pub fn addKeybind(state: *Application, key: u8, action: *const fn (*Application, std.Io) void) void {
        state.keybinds.append(state.allocator, .{ .key = key, .action = action }) catch unreachable;
    }
};

const std = @import("std");
const posix = std.posix;

const Pass = @import("pass.zig").Pass;
const StateLine = @import("state_line.zig").StateLine;
const InProgress = @import("in_progress.zig").InProgress;
const InProgressSpinner = @import("in_progress.zig").InProgressSpinner;
const Text = @import("text.zig").Text;
const Input = @import("input.zig").Input;
const Keyboard = @import("input_monitor.zig").Keyboard;
const InputEvent = @import("input_monitor.zig").InputEvent;
const constants = @import("ansi.zig");
