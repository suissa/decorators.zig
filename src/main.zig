const handler = @import("transport_handler");

extern "c" fn decorators_start_all(
    http_address: [*:0]const u8,
    grpc_address: [*:0]const u8,
    callback: *const fn ([*]const u8, usize, [*]u8, usize) callconv(.c) usize,
) callconv(.c) c_int;

pub fn main() !void {
    const result = decorators_start_all(
        "0.0.0.0:8080",
        "0.0.0.0:50051",
        handler.decorators_handle_payload,
    );
    if (result != 0) return error.TransportServerFailed;
}
