const std = @import("std");
const progressive = @import("progressive");

pub fn main() void {
    var state = progressive.Application.init(std.heap.page_allocator);
    // state.debug = true;
    state.start();
    defer state.stop();

    var task = state.createIndeterminate("Asking questions...");
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
