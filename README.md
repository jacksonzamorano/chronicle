# Chronicle

A Zig library for building interactive terminal UIs with progress indicators, text, and input fields.

## Installation

Add Chronicle as a dependency in your `build.zig.zon`:

```zig
.dependencies = .{
    .chronicle = .{
        .url = "https://github.com/jacksonzamorano/chronicle/archive/refs/tags/v0.1.0.tar.gz",
        .hash = "...",
    },
},
```

Then in your `build.zig`:

```zig
const chronicle = b.addModule("chronicle", .{
    .root_source_file = b.path("path/to/chronicle/src/root.zig"),
    .target = target,
});
```

## Quick Start

```zig
const std = @import("std");
const chronicle = @import("chronicle");

pub fn main() void {
    var app = chronicle.Application.init(std.heap.page_allocator);
    app.start();
    defer app.stop();

    // Add a text line
    const text = app.createText("Hello, Chronicle!");
    text.changeStyle(.bold);

    // Add a progress indicator
    var task = app.createIndeterminate("Loading...");
    task.setSpinner(.dots);
    task.sub("Please wait...");

    // Add an input field
    const input = app.createInput("Enter your name");
    input.setFinalizationBehavior(.{ .newPrompt = "Name saved" });
    app.focusInput(input);

    // Wait for input
    const value = input.join();
    _ = app.createText(value);

    // Complete the task
    task.complete("Done!");
}
```

## API Reference

### Application

The main entry point for creating terminal UIs.

- `init(allocator: std.mem.Allocator) Application` - Initialize a new application
- `start()` - Start the application (enters raw terminal mode)
- `stop()` - Stop the application and restore terminal
- `createText(text: []const u8) *Text` - Add a text line
- `createIndeterminate(title: []const u8) *InProgress` - Add an indeterminate progress indicator
- `createInput(prompt: []const u8) *Input` - Add an input field
- `focusInput(input: *Input)` - Focus on an input field for user interaction
- `addKeybind(key: u8, action: fn (*Application) void)` - Add a keyboard shortcut

### Text

Represents a line of styled text.

- `changeStyle(style: TextStyle)` - Change text style (regular, bold, dim)
- `changeText(text: []const u8)` - Update the text content

### InProgress

Represents a progress indicator.

- `complete(title: []const u8)` - Mark as completed successfully
- `sub(subtitle: []const u8)` - Add a subtitle
- `setSpinner(spinner: InProgressSpinner)` - Set spinner animation style

Available spinner types: `dots`, `breath`, `pulse`, `sparkle`, `noise`, `balloon`, `wave`, `grow`, `ping`, `arc`, `matrix`, `hourglass`

### Input

Represents a user input field.

- `join() []const u8` - Wait for and return the user's input
- `setFinalizationBehavior(behavior: InputFinalizationBehavior)` - Control what happens after input completion
- `setSeperator(sep: []const u8)` - Set the separator between prompt and input (default: ": ")

### TextStyle

Enum for text styling: `regular`, `bold`, `dim`

### InputFinalizationBehavior

Controls display after input completion:
- `.keep` - Show original prompt and value
- `.prompt` - Show only prompt
- `.value` - Show only value
- `.newPrompt([]const u8)` - Show new prompt
- `.newPromptAndValue([]const u8)` - Show new prompt with value

## Running the Example

```bash
zig build run
```

## Running Tests

```bash
zig build test
```
