const std = @import("std");
const decorators = @import("decorators");
const runtime = @import("event_runtime");

const RecordingSink = struct {
    expected_channel: decorators.Channel,
    expected_event: []const u8,
    expected_payload: []const u8,
    called: bool = false,

    pub fn publish(
        self: *@This(),
        channel: decorators.Channel,
        event: []const u8,
        payload: []const u8,
    ) !void {
        try std.testing.expectEqual(self.expected_channel, channel);
        try std.testing.expectEqualStrings(self.expected_event, event);
        try std.testing.expectEqualStrings(self.expected_payload, payload);
        self.called = true;
    }
};

test "success result returns through its originating channel" {
    const cases = [_]struct {
        channel: decorators.Channel,
        event: []const u8,
        success_event: []const u8,
    }{
        .{ .channel = .html, .event = "execute.prompt.html", .success_event = "execute.prompt.html.success" },
        .{ .channel = .ws, .event = "execute.prompt.ws", .success_event = "execute.prompt.ws.success" },
        .{ .channel = .grpc, .event = "execute.prompt.grpc", .success_event = "execute.prompt.grpc.success" },
    };

    for (cases) |case| {
        var sink = RecordingSink{
            .expected_channel = case.channel,
            .expected_event = case.success_event,
            .expected_payload = "processed-result",
        };
        var dispatcher = runtime.Dispatcher(RecordingSink){
            .allocator = std.testing.allocator,
            .sink = &sink,
        };

        try dispatcher.dispatch(
            .{ .event = case.event, .channel = case.channel },
            "processed-result",
        );
        try std.testing.expect(sink.called);
    }
}
