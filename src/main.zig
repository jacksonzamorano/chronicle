const std = @import("std");
const chronicle = @import("chronicle");

pub fn main(init: std.process.Init) void {
    var state = chronicle.Application.init(init.arena.allocator());
    state.start(init.io);
    defer state.stop(init.io);

    state.addKeybind('P', struct {
        fn action(s: *chronicle.Application, io: std.Io) void {
            const text = s.createText(io, "Pressed p!");
            _ = text;
        }
    }.action);

    var task = state.createIndeterminate(init.io, "Asking questions...");
    task.setSpinner(init.io, .dots);
    task.sub(init.io, "Waiting for response...");

    const input = state.createInput(init.io, "Enter a value");
    input.setFinalizationBehavior(init.io, .{ .newPrompt = "Value saved" });
    input.setSeperator(init.io, " => ");
    state.focusInput(init.io, input);

    const returnValue = input.join(init.io);
    var text = state.createText(init.io, returnValue);
    text.changeStyle(init.io, .bold);

    task.complete(init.io, "Done!");
}
