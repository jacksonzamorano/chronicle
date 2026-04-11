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
    lock: *std.Thread.Mutex,
    allocator: std.mem.Allocator,

    prompt: []const u8,
    value: []const u8,
    seperator: []const u8 = ": ",

    finalizationBehavior: InputFinalizationBehavior = .keep,

    temporaryValue: std.ArrayList(u8),
    validation: ?*const fn (value: []const u8) bool,
    completed: std.Thread.Condition,
    done: bool = false,

    pub fn join(input: *Input) []const u8 {
        input.lock.lock();
        while (!input.done) input.completed.wait(input.lock);
        const result = input.value;
        input.lock.unlock();
        return result;
    }

    pub fn setFinalizationBehavior(input: *Input, behavior: InputFinalizationBehavior) void {
        input.lock.lock();
        defer input.lock.unlock();
        input.finalizationBehavior = behavior;
    }

    pub fn setSeperator(input: *Input, sep: []const u8) void {
        input.lock.lock();
        defer input.lock.unlock();
        input.seperator = sep;
    }

    fn finalize(input: *Input) void {
        input.value = input.temporaryValue.toOwnedSlice(input.allocator) catch &[_]u8{};
        input.done = true;
        input.completed.signal();
    }

    pub fn onInput(input: *Input, char: InputEvent) bool {
        input.lock.lock();
        defer input.lock.unlock();
        switch (char) {
            .newline => {
                input.finalize();
                return true;
            },
            .backspace => {
                if (input.temporaryValue.items.len > 0) {
                    _ = input.temporaryValue.pop();
                }
            },
            .key => |c| {
                input.temporaryValue.append(input.allocator, c) catch return false;
            },
            else => {},
        }
        return false;
    }

    fn writePrompt(input: *Input, pass: *Pass, prompt: []const u8, sep: bool) !void {
        try pass.write(prompt);
        if (sep) {
            try pass.write(input.seperator);
        }
    }

    pub fn render(input: *Input, pass: *Pass) !void {
        try pass.startLine();
        if (input.done) {
            switch (input.finalizationBehavior) {
                .keep => {
                    try input.writePrompt(pass, input.prompt, true);
                    try pass.write(input.value);
                },
                .prompt => try input.writePrompt(pass, input.prompt, false),
                .value => try pass.write(input.value),
                .newPrompt => |prompt| {
                    try input.writePrompt(pass, prompt, false);
                },
                .newPromptAndValue => |prompt| {
                    try input.writePrompt(pass, prompt, true);
                    try pass.write(input.value);
                },
            }
        } else {
            try input.writePrompt(pass, input.prompt, true);
            try pass.write(input.temporaryValue.items);
        }
    }
};
