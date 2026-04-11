pub const COLOR_GREEN = "\x1b[32m";
pub const COLOR_RED = "\x1b[31m";
pub const COLOR_DIM = "\x1b[2m";
pub const COLOR_RESET = "\x1b[0m";

pub const TEXT_BOLD = "\x1b[1m";

pub const TextStyle = enum {
    regular,
    bold,
    dim,

    pub fn toCode(style: TextStyle) []const u8 {
        return switch (style) {
            .regular => "",
            .bold => TEXT_BOLD,
            .dim => COLOR_DIM,
        };
    }
};
