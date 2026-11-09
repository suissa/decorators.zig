#include "transport_abi.h"
#include <openssl/evp.h>
#include <openssl/sha.h>
#include <algorithm>
#include <array>
#include <cerrno>
#include <cstring>
#include <string>
#include <vector>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#include <arpa/inet.h>

namespace {
bool send_all(int fd, const uint8_t* data, size_t size) {
  while (size) {
    const ssize_t n = ::send(fd, data, size, MSG_NOSIGNAL);
    if (n <= 0) return false;
    data += n; size -= static_cast<size_t>(n);
  }
  return true;
}
bool read_exact(int fd, uint8_t* data, size_t size) {
  while (size) {
    const ssize_t n = ::recv(fd, data, size, 0);
    if (n <= 0) return false;
    data += n; size -= static_cast<size_t>(n);
  }
  return true;
}
std::string header_value(const std::string& headers, const std::string& key) {
  std::string lower = headers, needle = key;
  std::transform(lower.begin(), lower.end(), lower.begin(), ::tolower);
  std::transform(needle.begin(), needle.end(), needle.begin(), ::tolower);
  const auto p = lower.find(needle + ":");
  if (p == std::string::npos) return {};
  auto start = headers.find(':', p) + 1;
  while (start < headers.size() && headers[start] == ' ') ++start;
  auto end = headers.find("\r\n", start);
  return headers.substr(start, end - start);
}
bool websocket_upgrade(int fd, const std::string& headers) {
  const auto key = header_value(headers, "Sec-WebSocket-Key");
  if (key.empty()) return false;
  const std::string source = key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
  unsigned char digest[SHA_DIGEST_LENGTH];
  SHA1(reinterpret_cast<const unsigned char*>(source.data()), source.size(), digest);
  unsigned char encoded[EVP_ENCODE_LENGTH(SHA_DIGEST_LENGTH)];
  const int length = EVP_EncodeBlock(encoded, digest, SHA_DIGEST_LENGTH);
  const std::string response =
      "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n"
      "Connection: Upgrade\r\nSec-WebSocket-Accept: " +
      std::string(reinterpret_cast<char*>(encoded), length) + "\r\n\r\n";
  return send_all(fd, reinterpret_cast<const uint8_t*>(response.data()), response.size());
}
bool websocket_loop(int fd, decorators_handler_fn handler) {
  for (;;) {
    uint8_t h[2];
    if (!read_exact(fd, h, 2)) return true;
    const uint8_t opcode = h[0] & 0x0f;
    const bool masked = (h[1] & 0x80) != 0;
    uint64_t length = h[1] & 0x7f;
    if (length == 126) { uint8_t ext[2]; if (!read_exact(fd, ext, 2)) return false; length = (ext[0] << 8) | ext[1]; }
    else if (length == 127) return false;
    if (!masked || length > 1024 * 1024) return false;
    uint8_t mask[4]; if (!read_exact(fd, mask, 4)) return false;
    std::vector<uint8_t> payload(static_cast<size_t>(length));
    if (!read_exact(fd, payload.data(), payload.size())) return false;
    for (size_t i = 0; i < payload.size(); ++i) payload[i] ^= mask[i % 4];
    if (opcode == 8) return true;
    if (opcode != 1 && opcode != 2) continue;
    std::vector<uint8_t> output(payload.size() + 65536);
    const size_t n = handler(payload.data(), payload.size(), output.data(), output.size());
    if (n > output.size()) return false;
    std::vector<uint8_t> frame;
    frame.push_back(static_cast<uint8_t>(0x80 | opcode));
    if (n < 126) frame.push_back(static_cast<uint8_t>(n));
    else if (n <= 65535) { frame.push_back(126); frame.push_back(n >> 8); frame.push_back(n & 0xff); }
    else return false;
    frame.insert(frame.end(), output.begin(), output.begin() + n);
    if (!send_all(fd, frame.data(), frame.size())) return false;
  }
}
void serve_client(int fd, decorators_handler_fn handler) {
  std::string headers;
  std::array<char, 4096> chunk{};
  while (headers.find("\r\n\r\n") == std::string::npos && headers.size() < 32768) {
    const auto n = ::recv(fd, chunk.data(), chunk.size(), 0);
    if (n <= 0) return;
    headers.append(chunk.data(), static_cast<size_t>(n));
  }
  if (headers.find("Upgrade: websocket") != std::string::npos ||
      headers.find("upgrade: websocket") != std::string::npos) {
    if (websocket_upgrade(fd, headers)) websocket_loop(fd, handler);
    return;
  }
  const auto split = headers.find("\r\n\r\n");
  if (split == std::string::npos) return;
  const auto cl = header_value(headers, "Content-Length");
  size_t length = cl.empty() ? 0 : static_cast<size_t>(std::stoul(cl));
  if (length > 1024 * 1024) return;
  std::string body = headers.substr(split + 4);
  if (body.size() < length) {
    const size_t old = body.size(); body.resize(length);
    if (!read_exact(fd, reinterpret_cast<uint8_t*>(&body[old]), length - old)) return;
  } else body.resize(length);
  std::vector<uint8_t> output(body.size() + 65536);
  const size_t written = handler(reinterpret_cast<const uint8_t*>(body.data()),
                                 body.size(), output.data(), output.size());
  if (written > output.size()) return;
  const std::string prefix = "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: " +
      std::to_string(written) + "\r\nConnection: close\r\n\r\n";
  send_all(fd, reinterpret_cast<const uint8_t*>(prefix.data()), prefix.size());
  send_all(fd, output.data(), written);
}
}  // namespace

extern "C" int decorators_http_ws_serve(const char* address,
                                         decorators_handler_fn handler) {
  if (!address || !handler) return 1;
  std::string endpoint(address);
  const auto colon = endpoint.rfind(':');
  if (colon == std::string::npos) return 1;
  const int port = std::stoi(endpoint.substr(colon + 1));
  const int fd = ::socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) return 2;
  int reuse = 1;
  ::setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
  sockaddr_in addr{}; addr.sin_family = AF_INET;
  addr.sin_port = htons(static_cast<uint16_t>(port));
  const auto host = endpoint.substr(0, colon);
  addr.sin_addr.s_addr = (host == "0.0.0.0" || host == "*") ? INADDR_ANY : inet_addr(host.c_str());
  if (::bind(fd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0 || ::listen(fd, 128) < 0) {
    ::close(fd); return 3;
  }
  for (;;) {
    const int client = ::accept(fd, nullptr, nullptr);
    if (client < 0) { if (errno == EINTR) continue; ::close(fd); return 4; }
    serve_client(client, handler);
    ::close(client);
  }
}
