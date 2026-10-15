//! Generic decorator factory for Zig 0.16.
//!
//! Zig has no user-defined decorator syntax. This module composes compile-time
//! handlers with before/after behavior and keeps transport/event metadata in
//! ordinary values that a router can register.

const std = @import("std");

pub const Channel = enum {
    html,
    ws,
    grpc,
};

pub const Binding = struct {
    event: []const u8,
    channel: Channel,

    pub fn successEvent(self: Binding, allocator: anytype) ![]u8 {
        return try std.fmt.allocPrint(allocator, "{s}.success", .{self.event});
    }
};

/// Factory that wraps a function with a behavior type.
///
/// Behavior.before(args) runs before the handler.
/// Behavior.after(args, result) runs after it and receives the exact result,
/// including an error union if the handler returns one.
///
/// The generated call function preserves the handler's return type.
pub fn Decorator(comptime handler: anytype, comptime Behavior: type) type {
    return struct {
        pub fn call(args: anytype) @TypeOf(@call(.auto, handler, args)) {
            Behavior.before(args);
            const result = @call(.auto, handler, args);
            Behavior.after(args, result);
            return result;
        }
    };
}

/// Context-aware variant, useful when the transport connection/request must
/// be available to the behavior that publishes the result.
pub fn ContextDecorator(comptime handler: anytype, comptime Behavior: type) type {
    return struct {
        pub fn call(context: anytype, args: anytype) @TypeOf(@call(.auto, handler, args)) {
            Behavior.before(context, args);
            const result = @call(.auto, handler, args);
            Behavior.after(context, args, result);
            return result;
        }
    };
}

test "decorator executes before and after and preserves return value" {
    const State = struct {
        var before_called: bool = false;
        var after_called: bool = false;
    };

    const handler = struct {
        fn run(value: u32) u32 {
            return value * 2;
        }
    }.run;

    const Behavior = struct {
        fn before(args: anytype) void {
            _ = args;
            State.before_called = true;
        }

        fn after(args: anytype, result: u32) void {
            _ = args;
            State.after_called = result == 42;
        }
    };

    const Wrapped = Decorator(handler, Behavior);
    State.before_called = false;
    State.after_called = false;

    try std.testing.expectEqual(@as(u32, 42), Wrapped.call(.{@as(u32, 21)}));
    try std.testing.expect(State.before_called);
    try std.testing.expect(State.after_called);
}

test "binding creates the conventional success event" {
    const allocator = std.testing.allocator;
    const binding = Binding{ .event = "execute.prompt.user", .channel = .html };
    const event = try binding.successEvent(allocator);
    defer allocator.free(event);
    try std.testing.expectEqualStrings("execute.prompt.user.success", event);
}
