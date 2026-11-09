#include "transport_abi.h"
#include <grpcpp/grpcpp.h>
#include <grpcpp/generic/async_generic_service.h>
#include <memory>
#include <string>
#include <thread>
#include <vector>

namespace {
class GenericCall {
 public:
  GenericCall(grpc::AsyncGenericService* service, grpc::ServerCompletionQueue* cq,
              decorators_handler_fn handler)
      : service_(service), cq_(cq), handler_(handler), stream_(&context_) {
    Proceed(true);
  }

  void Proceed(bool ok) {
    if (state_ == State::kCreate) {
      new GenericCall(service_, cq_, handler_);
      state_ = State::kRead;
      service_->RequestCall(&context_, &stream_, cq_, cq_, this);
      return;
    }
    if (state_ == State::kRead) {
      if (!ok) { delete this; return; }
      state_ = State::kFinish;
      stream_.Read(&request_, this);
      return;
    }
    if (state_ == State::kFinish) {
      if (!ok) { delete this; return; }
      std::vector<grpc::Slice> slices;
      if (!request_.Dump(&slices).ok()) {
        stream_.Finish(grpc::Status(grpc::StatusCode::INVALID_ARGUMENT,
                                    "Unable to decode request"), this);
        state_ = State::kDone;
        return;
      }
      std::string input;
      for (const auto& slice : slices)
        input.append(reinterpret_cast<const char*>(slice.begin()), slice.size());
      std::vector<uint8_t> output(input.size() + 65536);
      const size_t written = handler_(
          reinterpret_cast<const uint8_t*>(input.data()), input.size(),
          output.data(), output.size());
      if (written > output.size()) {
        stream_.Finish(grpc::Status(grpc::StatusCode::RESOURCE_EXHAUSTED,
                                    "Handler response exceeds capacity"), this);
      } else {
        grpc::Slice response_slice(output.data(), written);
        grpc::ByteBuffer response(&response_slice, 1);
        stream_.WriteAndFinish(response, grpc::WriteOptions(),
                               grpc::Status::OK, this);
      }
      state_ = State::kDone;
      return;
    }
    delete this;
  }

 private:
  enum class State { kCreate, kRead, kFinish, kDone };
  grpc::AsyncGenericService* service_;
  grpc::ServerCompletionQueue* cq_;
  decorators_handler_fn handler_;
  grpc::GenericServerContext context_;
  grpc::GenericServerAsyncReaderWriter stream_;
  grpc::ByteBuffer request_;
  State state_ = State::kCreate;
};
}  // namespace

extern "C" int decorators_grpc_serve(const char* address,
                                      decorators_handler_fn handler) {
  if (!address || !handler) return 1;
  grpc::AsyncGenericService service;
  grpc::ServerBuilder builder;
  builder.AddListeningPort(address, grpc::InsecureServerCredentials());
  builder.RegisterAsyncGenericService(&service);
  auto cq = builder.AddCompletionQueue();
  auto server = builder.BuildAndStart();
  if (!server || !cq) return 2;
  new GenericCall(&service, cq.get(), handler);
  void* tag = nullptr;
  bool ok = false;
  while (cq->Next(&tag, &ok))
    static_cast<GenericCall*>(tag)->Proceed(ok);
  return 0;
}
