const decorators = @import("decorators.zig");

fn process(payload: []const u8) []const u8 {
    return payload;
}

const EchoBehavior = struct {
    pub fn before(args: anytype) void {
        _ = args;
    }

    pub fn after(args: anytype, result: []const u8) void {
        _ = args;
        _ = result;
    }
};

const Echo = decorators.Decorator(process, EchoBehavior);

pub fn handlePayload(
    input: [*]const u8,
    input_len: usize,
    output: [*]u8,
    output_capacity: usize,
) usize {
    const result = Echo.call(.{input[0..input_len]});
    if (result.len > output_capacity) return output_capacity + 1;
    @memcpy(output[0..result.len], result);
    return result.len;
}

export fn decorators_handle_payload(
    input: [*]const u8,
    input_len: usize,
    output: [*]u8,
    output_capacity: usize,
) callconv(.c) usize {
    return handlePayload(input, input_len, output, output_capacity);
}
