const InputEvent = @import("../../input.zig").InputEvent;
const Pass = @import("../pass.zig").Pass;
const std = @import("std");

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

    pub fn render(input: *Input, pass: *Pass) !void {
        try pass.startLine();
        try pass.write(input.prompt);
        try pass.write(": ");
        if (input.done) {
            try pass.write(input.value);
        } else {
            try pass.write(input.temporaryValue.items);
        }
    }
};
