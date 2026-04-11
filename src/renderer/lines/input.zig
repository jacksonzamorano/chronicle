const InputMonitor = @import("../../input.zig").InputMonitor;
pub const Input = struct {
    prompt: []const u8,
    value: []const u8,
    validation: ?*const fn (value: []const u8) bool,

    input: InputMonitor,

    fn render() void {

    }
};
