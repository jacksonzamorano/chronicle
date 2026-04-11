const std = @import("std");
const progressive = @import("progressive");

pub fn main() void {
    var state = progressive.Application.init(std.heap.page_allocator);
    // state.debug = true;
    state.start();
    defer state.stop();

    state.addKeybind('P', struct {
        fn action(s: *progressive.Application) void {
            const text = s.createText("Pressed p!");
            _ = text;
        }
    }.action);

    var task = state.createIndeterminate("Asking questions...");
    task.setSpinner(.dots);
    task.sub("Waiting for response...");

    const input = state.createInput("Enter a value");
    input.setFinalizationBehavior(.{ .newPrompt = "Value saved" });
    input.setSeperator(" => ");
    state.focusInput(input);

    const returnValue = input.join();
    var text = state.createText(returnValue);
    text.changeStyle(.bold);

    task.complete("Done!");
}
