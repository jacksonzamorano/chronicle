const std = @import("std");
const InputEvent = @import("input_monitor.zig").InputEvent;
const Pass = @import("pass.zig").Pass;

pub const InputFinalizationBehavior = union(enum) {
    keep,
    prompt,
    value,
    newPrompt: []const u8,
    newPromptAndValue: []const u8,
};

pub const Input = struct {
    lock: *std.Io.Mutex,
    allocator: std.mem.Allocator,

    prompt: []const u8,
    value: []const u8,
    seperator: []const u8 = ": ",

    finalizationBehavior: InputFinalizationBehavior = .keep,

    temporaryValue: std.ArrayList(u8),
    validation: ?*const fn (value: []const u8) bool,
    completed: std.Io.Condition,
    done: bool = false,

    pub fn join(input: *Input, io: std.Io) []const u8 {
        input.lock.lock(io) catch unreachable;
        while (!input.done) input.completed.wait(io, input.lock) catch return "";
        const result = input.value;
        input.lock.unlock(io);
        return result;
    }

    pub fn setFinalizationBehavior(input: *Input, io: std.Io, behavior: InputFinalizationBehavior) void {
        input.lock.lock(io) catch unreachable;
        defer input.lock.unlock(io);
        input.finalizationBehavior = behavior;
    }

    pub fn setSeperator(input: *Input, io: std.Io, sep: []const u8) void {
        input.lock.lock(io) catch unreachable;
        defer input.lock.unlock(io);
        input.seperator = sep;
    }

    fn finalize(input: *Input, io: std.Io) void {
        input.value = input.temporaryValue.toOwnedSlice(input.allocator) catch unreachable;
        input.done = true;
        input.completed.signal(io);
    }

    pub fn onInput(input: *Input, io: std.Io, char: InputEvent) bool {
        input.lock.lock(io) catch unreachable;
        defer input.lock.unlock(io);
        switch (char) {
            .newline => {
                input.finalize(io);
                return true;
            },
            .backspace => {
                if (input.temporaryValue.items.len > 0) {
                    _ = input.temporaryValue.pop();
                }
            },
            .key => |c| {
                input.temporaryValue.append(input.allocator, c) catch unreachable;
            },
            else => {},
        }
        return false;
    }

    fn writePrompt(input: *Input, pass: *Pass, prompt: []const u8, sep: bool) void {
        pass.write(prompt);
        if (sep) {
            pass.write(input.seperator);
        }
    }

    pub fn render(input: *Input, pass: *Pass) void {
        pass.startLine();
        if (input.done) {
            switch (input.finalizationBehavior) {
                .keep => {
                    input.writePrompt(pass, input.prompt, true);
                    pass.write(input.value);
                },
                .prompt => input.writePrompt(pass, input.prompt, false),
                .value => pass.write(input.value),
                .newPrompt => |prompt| {
                    input.writePrompt(pass, prompt, false);
                },
                .newPromptAndValue => |prompt| {
                    input.writePrompt(pass, prompt, true);
                    pass.write(input.value);
                },
            }
        } else {
            input.writePrompt(pass, input.prompt, true);
            pass.write(input.temporaryValue.items);
        }
    }
};
