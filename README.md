# decorators.zig

A small Zig 0.16 experiment for composing compile-time function wrappers and
declaring event/channel metadata.

## Decorator factory

Zig does not support user-defined syntax such as `@channels(...)` or
`@channel.ws(...)`. The equivalent is a compile-time factory that returns a
type with a wrapped `call` function:

```zig
const Prompt = decorators.Decorator(prompt, PromptBehavior);
const result = Prompt.call(.{text});
```

The behavior type supplies two functions:

- `before(args)`: called before the handler.
- `after(args, result)`: called after the handler; receives the handler's
  return value without changing it.

The result is returned to the caller. A behavior can use its own configured
transport publisher to emit `<event>.success`. Use `ContextDecorator` when
the publisher needs a request or connection context.

## Channel metadata

```zig
const user_prompt = decorators.Binding{
    .event = "execute.prompt.user",
    .channel = .html,
};
```

The supported channel tags are `html`, `ws`, and `grpc`. These are metadata,
not network servers: HTTP routing, WebSocket framing, HTTP/2, protobuf encoding,
and gRPC status/trailer handling belong in transport adapters.

## Build and test

Requires Zig 0.16.0:

```sh
zig build
zig build test
```

This repository currently demonstrates the decorator factory and event metadata;
it is not yet a complete HTTP/WebSocket/gRPC server.
