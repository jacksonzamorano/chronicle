const InputEvent = @import("../../input.zig").InputEvent;
const Pass = @import("../pass.zig").Pass;
const std = @import("std");
pub const Input = struct {
    lock: *std.Thread.Mutex,
    allocator: std.mem.Allocator,

    prompt: []const u8,
    value: std.ArrayList(u8),
    validation: ?*const fn (value: []const u8) bool,
    completed: std.Thread.Condition,
    done: bool = false,

    pub fn join(input: *Input) []const u8 {
        input.lock.lock();
        while (!input.done) input.completed.wait(input.lock);
        const result = input.value.toOwnedSlice(input.allocator) catch &[_]u8{};
        input.lock.unlock();
        return result;
    }

    pub fn onInput(input: *Input, char: InputEvent) bool {
        input.lock.lock();
        defer input.lock.unlock();
        switch (char) {
            .key => |c| {
                if (c == '\n') {
                    input.done = true;
                    input.completed.signal();
                    return true;
                } else {
                    input.value.append(input.allocator, c) catch return false;
                }
            },
            .ctrl_key => |c| {
                if (c == 'C') {
                    input.done = true;
                    input.completed.signal();
                    return true;
                }
            },
        }
        return false;
    }

    pub fn render(input: *Input, pass: *Pass) !void {
        try pass.startLine();
        try pass.write(input.prompt);
        try pass.write(" : ");
        try pass.write(input.value.items);
    }
};
