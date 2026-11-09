#ifndef DECORATORS_TRANSPORT_ABI_H
#define DECORATORS_TRANSPORT_ABI_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef size_t (*decorators_handler_fn)(const uint8_t *input, size_t input_len,
                                        uint8_t *output, size_t output_capacity);
int decorators_http_ws_serve(const char *address, decorators_handler_fn handler);
int decorators_grpc_serve(const char *address, decorators_handler_fn handler);
#ifdef __cplusplus
}
#endif
#endif
