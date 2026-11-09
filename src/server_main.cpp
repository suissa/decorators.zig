#include "transport_abi.h"
#include <thread>

extern "C" int decorators_start_all(const char* http_address,
                                     const char* grpc_address,
                                     decorators_handler_fn handler) {
  if (!http_address || !grpc_address || !handler) return 1;
  int http_result = 0;
  int grpc_result = 0;
  std::thread http_thread([&] {
    http_result = decorators_http_ws_serve(http_address, handler);
  });
  std::thread grpc_thread([&] {
    grpc_result = decorators_grpc_serve(grpc_address, handler);
  });
  http_thread.join();
  grpc_thread.join();
  return http_result ? http_result : grpc_result;
}
