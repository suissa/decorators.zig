const std = @import("std");

extern fn decorators_handle_payload(
    input: [*]const u8,
    input_len: usize,
    output: [*]u8,
    output_capacity: usize,
) callconv(.c) usize;

test "shared transport handler returns the same payload" {
    const input = "transport-contract";
    var output: [128]u8 = undefined;
    const written = decorators_handle_payload(input.ptr, input.len, &output, output.len);
    try std.testing.expectEqual(input.len, written);
    try std.testing.expectEqualStrings(input, output[0..written]);
}

test "shared transport handler reports insufficient output capacity" {
    const input = "payload";
    var output: [2]u8 = undefined;
    const written = decorators_handle_payload(input.ptr, input.len, &output, output.len);
    try std.testing.expectEqual(output.len + 1, written);
}
