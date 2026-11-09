const decorators = @import("decorators.zig");

extern "c" fn decorators_start_all(
    http_address: [*:0]const u8,
    grpc_address: [*:0]const u8,
    handler: *const fn ([*]const u8, usize, [*]u8, usize) callconv(.c) usize,
) callconv(.c) c_int;

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

export fn decorators_handle_payload(
    input: [*]const u8,
    input_len: usize,
    output: [*]u8,
    output_capacity: usize,
) callconv(.c) usize {
    const result = Echo.call(.{input[0..input_len]});
    if (result.len > output_capacity) return output_capacity + 1;
    @memcpy(output[0..result.len], result);
    return result.len;
}

pub fn main() !void {
    const result = decorators_start_all(
        "0.0.0.0:8080",
        "0.0.0.0:50051",
        decorators_handle_payload,
    );
    if (result != 0) return error.TransportServerFailed;
}
