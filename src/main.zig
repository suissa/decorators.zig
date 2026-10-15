const std = @import("std");
const decorators = @import("decorators.zig");

fn prompt(text: []const u8) []const u8 {
    return text;
}

const PromptBehavior = struct {
    fn before(args: anytype) void {
        std.debug.print("prompt called with {s}\n", .{args[0]});
    }

    fn after(args: anytype, result: []const u8) void {
        _ = args;
        std.debug.print("publish event: execute.prompt.user.success => {s}\n", .{result});
    }
};

const Prompt = decorators.Decorator(prompt, PromptBehavior);

pub fn main() void {
    const result = Prompt.call(.{"hello from Zig"});
    std.debug.print("handler returned: {s}\n", .{result});
}
