const std = @import("std");

const handler = @import("transport_handler");


test "shared transport handler returns the same payload" {
    const input = "transport-contract";
    var output: [128]u8 = undefined;
    const written = handler.handlePayload(input.ptr, input.len, &output, output.len);
    try std.testing.expectEqual(input.len, written);
    try std.testing.expectEqualStrings(input, output[0..written]);
}

test "shared transport handler reports insufficient output capacity" {
    const input = "payload";
    var output: [2]u8 = undefined;
    const written = handler.handlePayload(input.ptr, input.len, &output, output.len);
    try std.testing.expectEqual(output.len + 1, written);
}
