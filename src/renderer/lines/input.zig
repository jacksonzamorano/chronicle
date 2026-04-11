pub const Input = struct {
    prompt: []const u8,
    value: []const u8,
    validation: ?*const fn (value: []const u8) bool,

    pub fn init(prompt: []const u8) Input {
        return .{
            .prompt = prompt,
            .value = "",
            .validation = null,
        };
    }
};
