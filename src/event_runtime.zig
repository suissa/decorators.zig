//! Transport-neutral event result dispatcher.
//! Concrete HTTP, WebSocket and gRPC adapters can implement the Sink contract.

const std = @import("std");
const decorators = @import("decorators");

pub fn Dispatcher(comptime Sink: type) type {
    return struct {
        allocator: std.mem.Allocator,
        sink: *Sink,

        pub fn dispatch(
            self: *@This(),
            binding: decorators.Binding,
            payload: []const u8,
        ) !void {
            const success_event = try binding.successEvent(self.allocator);
            defer self.allocator.free(success_event);
            try self.sink.publish(binding.channel, success_event, payload);
        }
    };
}
