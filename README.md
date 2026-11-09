# decorators.zig

Zig 0.16 compile-time behavior decorators with native HTTP, WebSocket and gRPC
transport adapters.

## Architecture

- **Zig behavior layer**: one handler contract is shared by all transports.
- **HTTP/1.1 + WebSocket**: native TCP adapter; WebSocket upgrade and masked
  text/binary frame handling use RFC 6455 framing.
- **gRPC**: gRPC C++ Core generic asynchronous service, using HTTP/2 and opaque
  protobuf message bytes. It accepts generic RPC methods; generated protobuf
  service bindings and typed request validation are application-level work.
- **C ABI**: the transport adapters call the Zig handler through
  `decorators_handle_payload`.

The C++ code is a narrow protocol adapter. Business behavior remains in Zig.

## Run

Requires Zig 0.16.0, a C++17 compiler, gRPC C++ development libraries,
protobuf development libraries and OpenSSL development headers.

```sh
zig build
./zig-out/bin/decorators-server
```

Defaults:
- HTTP + WebSocket: `0.0.0.0:8080`
- gRPC: `0.0.0.0:50051`

HTTP accepts request bodies and returns the handler bytes as an
`application/octet-stream` response. WebSocket accepts text/binary frames and
returns one frame per input. The generic gRPC endpoint forwards raw protobuf
message bytes to the same handler; it does not define a protobuf schema.

## Tests

```sh
zig fmt --check build.zig src tests
zig build
zig build test
```

The current tests validate the shared Zig handler contract and output-capacity
behavior. They are not yet full network end-to-end tests for HTTP, WebSocket,
or gRPC interoperability. The HTTP/WebSocket adapter currently handles one
connection at a time and is intended as a functional baseline, not a
production-hardened server.
