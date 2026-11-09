import base64
import hashlib
import os
import socket
import subprocess
import sys
import time

import grpc

BINARY = "./zig-out/bin/decorators-server"
process = subprocess.Popen([BINARY], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def wait_port(port):
    deadline = time.time() + 15
    while time.time() < deadline:
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                return
        except OSError:
            time.sleep(0.1)
    raise RuntimeError(f"server did not open port {port}")

try:
    wait_port(8080)
    wait_port(50051)

    # HTTP request/response contract.
    with socket.create_connection(("127.0.0.1", 8080), timeout=3) as sock:
        body = b"http-smoke"
        sock.sendall(
            b"POST /echo HTTP/1.1\r\nHost: localhost\r\n"
            + f"Content-Length: {len(body)}\r\nConnection: close\r\n\r\n".encode()
            + body
        )
        response = b""
        while True:
            chunk = sock.recv(4096)
            if not chunk:
                break
            response += chunk
        assert response.endswith(body), response

    # WebSocket RFC 6455 upgrade + one masked text frame.
    with socket.create_connection(("127.0.0.1", 8080), timeout=3) as sock:
        key = base64.b64encode(os.urandom(16)).decode()
        request = (
            "GET /ws HTTP/1.1\r\nHost: localhost\r\n"
            "Upgrade: websocket\r\nConnection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n"
        )
        sock.sendall(request.encode())
        response = b""
        while b"\r\n\r\n" not in response:
            response += sock.recv(1024)
        assert b"101 Switching Protocols" in response, response
        payload = b"ws-smoke"
        mask = os.urandom(4)
        masked = bytes(value ^ mask[i % 4] for i, value in enumerate(payload))
        sock.sendall(bytes([0x81, 0x80 | len(payload)]) + mask + masked)
        frame = sock.recv(128)
        assert frame[0] == 0x81 and frame[2:] == payload, frame

    # Generic gRPC unary call: raw bytes in/out, no generated protobuf schema.
    channel = grpc.insecure_channel("127.0.0.1:50051")
    call = channel.unary_unary(
        "/smoke.Echo/Call",
        request_serializer=lambda value: value,
        response_deserializer=lambda value: value,
    )
    assert call(b"grpc-smoke", timeout=5) == b"grpc-smoke"
    channel.close()
    print("HTTP, WebSocket and generic gRPC smoke tests passed")
finally:
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
