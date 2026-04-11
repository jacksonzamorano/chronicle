const std = @import("std");
const progressive = @import("progressive");

pub fn main() !void {
    var state = progressive.renderer.State.init(std.heap.page_allocator);
    // state.debug = true;
    try state.start();
    defer state.stop();

    var task = state.createIndeterminate("Checking permissions...") catch unreachable;
    task.sub("Logging in...");

    var text = try state.createText("Hello, world!");
    text.changeText("Hello, world!");
    text.changeStyle(.bold);

    std.Thread.sleep(3 * std.time.ns_per_s);

    task.sub("Verifying permissions...");
    var task2 = state.createIndeterminate("Validating status...") catch unreachable;
    task2.sub("Checking status...");

    std.Thread.sleep(3 * std.time.ns_per_s);

    task2.sub("Verifying mergeability...");
    task.complete("Permissions verified!");

    std.Thread.sleep(std.time.ns_per_s);
    task2.complete("Ready to merge!");
}

