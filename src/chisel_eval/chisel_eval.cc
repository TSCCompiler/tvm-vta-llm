/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
#include <tvm/runtime/module.h>
#include <tvm/runtime/packed_func.h>
#include <tvm/runtime/registry.h>

#include "vta/dpi/tsim.h"

// Include verilator array access functions code
#include "verilated.cpp"
#include "verilated_dpi.cpp"

#if defined(_WIN32)
#include <windows.h>


#else
#include <dlfcn.h>
#endif

#include <cassert>
#include <queue>
#include <condition_variable>
#include <thread>

namespace vta {
namespace chisel{
    using namespace tvm::runtime;
    typedef struct _AxisElem
    {
        uint64_t val[2];
    }AxisElem;
    struct HostRequest {
        uint8_t opcode;
        uint8_t addr;
        uint32_t value;
    };

    struct HostResponse {
        uint32_t value;
    };
    struct MemResponse {
        uint8_t valid;
        uint8_t id;
        uint64_t* value;
    };
    template <typename T>
    class ThreadSafeQueue {
    public:
        void Push(const T item) {
            std::lock_guard<std::mutex> lock(mutex_);
            queue_.push(std::move(item));
            cond_.notify_one();
        }

        void WaitPop(T* item) {
            std::unique_lock<std::mutex> lock(mutex_);
            cond_.wait(lock, [this]{return !queue_.empty();});
            *item = std::move(queue_.front());
            queue_.pop();
        }

        bool TryPop(T* item, bool pop) {
            std::lock_guard<std::mutex> lock(mutex_);
            if (queue_.empty()) return false;
            *item = std::move(queue_.front());
            if (pop) queue_.pop();
            return true;
        }

    private:
        mutable std::mutex mutex_;
        std::queue<T> queue_;
        std::condition_variable cond_;
    };
    class HostDevice {
    public:
        void PushRequest(uint8_t opcode, uint8_t addr, uint32_t value);
        bool TryPopRequest(HostRequest* r, bool pop);
        void PushResponse(uint32_t value);
        void WaitPopResponse(HostResponse* r);

    private:
        mutable std::mutex mutex_;
        ThreadSafeQueue<HostRequest> req_;
        ThreadSafeQueue<HostResponse> resp_;
    };
    class MemDevice {
    public:
        void  SetRequest(
                uint8_t  rd_req_valid,
                uint64_t rd_req_addr,
                uint32_t rd_req_len,
                uint32_t rd_req_id,
                uint64_t wr_req_addr,
                uint32_t wr_req_len,
                uint8_t  wr_req_valid);
        MemResponse ReadData(uint8_t ready, int blkNb);
        void WriteData(svOpenArrayHandle value, uint64_t wr_strb);

    private:
        uint64_t* raddr_{0};
        uint64_t* waddr_{0};
        uint32_t rlen_{0};
        uint32_t rid_{0};
        uint32_t wlen_{0};
        std::mutex mutex_;
        uint64_t dead_beef_ [8] = {0xdeadbeefdeadbeef,0xdeadbeefdeadbeef,
                                   0xdeadbeefdeadbeef,0xdeadbeefdeadbeef,
                                   0xdeadbeefdeadbeef,0xdeadbeefdeadbeef,
                                   0xdeadbeefdeadbeef,0xdeadbeefdeadbeef };

    };


/*! \brief The type of VTADPISim function pointer */
//    int VTADPIEval(int nstep)
typedef int (*VTADPIEvalFunc)(int);
typedef void (*VTAHLSDPIInitFunc)(VTAContextHandle ctx,
                                  VTAAxisDPIFunc axisDpiFunc,
                                  VTAHostDPIFunc host_dpi,
                                  VTAMemDPIFunc mem_dpi);

using tvm::runtime::Module;

class DPIChiselNode : public tvm::runtime::ModuleNode {
public:
    const char * type_key() const override {
        return "DPIChiselNode";
    }

    static tvm::runtime::Module Load(std::string dll_name);
protected:
    static void VTAAxisDPIFunc(
            VTAContextHandle self,
            dpi32_t user_id,
            const svOpenArrayHandle rd_bits,
            dpi8_t rd_valid,
            dpi8_t* rd_ready){
        CHECK(self!= nullptr) << "got empty vta context handle in axis host callback";
        reinterpret_cast<DPIChiselNode*>(self)->on_hls_stream_data(user_id,rd_bits,
                                                                   rd_valid,
                                                                   rd_ready);
    }
    static void VTAHostDPI(
            VTAContextHandle self,
            dpi8_t* req_valid,
            dpi8_t* req_opcode,
            dpi8_t* req_addr,
            dpi32_t* req_value,
            dpi8_t req_deq,
            dpi8_t resp_valid,
            dpi32_t resp_value) {
        static_cast<DPIChiselNode*>(self)->HostDPI(
                req_valid, req_opcode, req_addr,
                req_value, req_deq, resp_valid, resp_value);
    }
    static void VTAMemDPI(
            VTAContextHandle self,
            dpi8_t rd_req_valid,
            dpi8_t rd_req_len,
            dpi8_t rd_req_id,
            dpi64_t rd_req_addr,
            dpi8_t wr_req_valid,
            dpi8_t wr_req_len,
            dpi64_t wr_req_addr,
            dpi8_t wr_valid,
            const svOpenArrayHandle wr_value,
            dpi64_t wr_strb,
            dpi8_t* rd_valid,
            dpi8_t*   rd_id,
            const svOpenArrayHandle rd_value,
            dpi8_t rd_ready) {
        static_cast<DPIChiselNode*>(self)->MemDPI(
                rd_req_valid, rd_req_len, rd_req_id,
                rd_req_addr, wr_req_valid, wr_req_len, wr_req_addr,
                wr_valid, wr_value, wr_strb,
                rd_valid, rd_id, rd_value, rd_ready);
    }
protected:
    void on_hls_stream_data(
            dpi32_t user_id,
            const svOpenArrayHandle rd_bits,
                            dpi8_t rd_valid,
                            dpi8_t* rd_ready){
        LOG(INFO) << "recv user id " << user_id;
        *rd_ready = 1;
        if (rd_valid){
            assert(rd_bits != NULL);
            assert(svSize(rd_bits, 1) <= 8);
            assert(svDimensions(rd_bits) == 1);

            assert(svSize(rd_bits, 0) == 64);
            int rgtIdx = svRight(rd_bits, 1);
            int blkNd = svSize(rd_bits, 1);
            if (_userid_2_blkNd.find(user_id)==_userid_2_blkNd.end()){
                _userid_2_blkNd[user_id]=blkNd;
                // create and clear array
                _userid_2_array[user_id] = std::vector<uint64_t >();
            }else {
                CHECK(_userid_2_blkNd[user_id]==blkNd) << "blknd changed for user " << user_id;
            }
            auto& varray = _userid_2_array[user_id];
            for (int i = 0; i < blkNd; ++i) {
                uint64_t * elemPtr = (uint64_t*) svGetArrElemPtr1(rd_bits, rgtIdx+i);
                assert(elemPtr != NULL);
                auto value = elemPtr[0];
                varray.push_back(value);
//                nelem.val[i] = value;
            }
//            _recv_vals.push_back(nelem);
        }
    }
    void HostDPI(dpi8_t* req_valid,
                 dpi8_t* req_opcode,
                 dpi8_t* req_addr,
                 dpi32_t* req_value,
                 dpi8_t req_deq,
                 dpi8_t resp_valid,
                 dpi32_t resp_value) {
        HostRequest* r = new HostRequest;
        *req_valid = host_device_.TryPopRequest(r, req_deq);
        *req_opcode = r->opcode;
        *req_addr = r->addr;
        *req_value = r->value;
        if (resp_valid) {
            host_device_.PushResponse(resp_value);
        }
        delete r;
    }
    void MemDPI(
            dpi8_t rd_req_valid,
            dpi8_t rd_req_len,
            dpi8_t rd_req_id,
            dpi64_t rd_req_addr,
            dpi8_t wr_req_valid,
            dpi8_t wr_req_len,
            dpi64_t wr_req_addr,
            dpi8_t wr_valid,
            const svOpenArrayHandle wr_value,
            dpi64_t wr_strb,
            dpi8_t* rd_valid,
            dpi8_t*  rd_id,
            const svOpenArrayHandle rd_value,
            dpi8_t rd_ready) {

        // check data pointers
        // data is expected to come in 64bit chunks
        // up to 512 bits total
        // more bits require wider strb data
        assert(wr_value != NULL);
        assert(svDimensions(wr_value) == 1);
        assert(svSize(wr_value, 1) <= 8);
        assert(svSize(wr_value, 0) == 64);
        assert(rd_value != NULL);
        assert(svDimensions(rd_value) == 1);
        assert(svSize(rd_value, 1) <= 8);
        assert(svSize(rd_value, 0) == 64);

        int lftIdx = svLeft(rd_value, 1);
        int rgtIdx = svRight(rd_value, 1);
        int blkNb  = lftIdx - rgtIdx + 1;
        assert(lftIdx >= 0);
        assert(rgtIdx >= 0);
        assert(lftIdx >= rgtIdx);
        assert(blkNb > 0);

        if (wr_valid) {
            mem_device_.WriteData(wr_value, wr_strb);
        }
        if (rd_req_valid || wr_req_valid) {
            LOG(INFO) << "rd req addr : " << rd_req_addr;
            mem_device_.SetRequest(
                    rd_req_valid,
                    rd_req_addr,
                    rd_req_len,
                    rd_req_id,
                    wr_req_addr,
                    wr_req_len,
                    wr_req_valid);
        }


        MemResponse r = mem_device_.ReadData(rd_ready, blkNb);
        *rd_valid = r.valid;
        for (int idx = 0; idx < blkNb; idx ++) {
            uint64_t* dataPtr = (uint64_t*)svGetArrElemPtr1(rd_value, rgtIdx + idx);
            assert(dataPtr != NULL);
            uint32_t val = 0;//r.value[idx];
            (*dataPtr) = val;
        }
        *rd_id     = r.id;
    }
protected:
    void Init(const std::string & name) {
        LoadDSO(name);
        _feval = reinterpret_cast<VTADPIEvalFunc >(GetSymbol("VTADPIEval"));
        CHECK(_feval != nullptr);
        auto _init_func = reinterpret_cast<VTAHLSDPIInitFunc >(GetSymbol("VTAHLSDPIInit"));
        CHECK(_init_func != nullptr);
        _init_func(this, VTAAxisDPIFunc, VTAHostDPI, VTAMemDPI);
        _userid_2_array.clear();
        _userid_2_blkNd.clear();

    }
    void WriteReg(int addr, uint32_t value) {
        host_device_.PushRequest(1, addr, value);
    }

    uint32_t ReadReg(int addr) {
        uint32_t value;
        HostResponse* r = new HostResponse;
        host_device_.PushRequest(0, addr, 0);
        host_device_.WaitPopResponse(r);
        value = r->value;
        delete r;
        return value;
    }
    PackedFunc GetFunction(const tvm::runtime::String &name,
                           const ObjectPtr<tvm::runtime::Object> &sptr_to_self) override
    {
        if (name == "Eval"){
            return TypedPackedFunc<int(int)>(
                [this](int nstep){
                    int ret = this->eval_step(nstep);
                    return ret;
                }
            );
        }else if(name=="GetArray"){
            return TypedPackedFunc<tvm::runtime::NDArray(int )>(
                    [this](int user_id){
                        auto arr = tvm::runtime::NDArray();
                        if (_userid_2_blkNd.find(user_id)!=_userid_2_blkNd.end()){
                            if (_userid_2_array.find(user_id)!=_userid_2_array.end()){
                                auto blknd = _userid_2_blkNd[user_id];
                                const auto& vector_array = _userid_2_array[user_id];
                                arr = tvm::runtime::NDArray::Empty({static_cast<long>((vector_array.size()/blknd)), blknd},
                                                                   DLDataType{kDLUInt, 64, 1},
                                                                   DLDevice{kDLCPU, 0});
                                arr.CopyFromBytes(vector_array.data(), vector_array.size()*sizeof (uint64_t));
                                return arr;
                            }
                        }
                        return arr;
                    }
            );
        }else if(name=="WriteReg"){
            return TypedPackedFunc<void(int, int)>(
                    [this](int addr, int value){
                        this->WriteReg(addr, value);
                    }
            );
        }else if(name=="ReadReg"){
            return TypedPackedFunc<int(int)>(
                    [this](int addr) -> int {
                        return this->ReadReg(addr);
                    }
                    );
        }
    }
    int eval_step(int nstep){
        // start it in thread only once
        if (_feval){
            auto frun = [this](){
                (*_feval)(10);
            };
            tsim_thread_ = std::thread(frun);
            return 1;
        }
        return 0;
    }
protected:

#if defined(_WIN32)
    // library handle
    HMODULE lib_handle_{nullptr};
    // Load the library
    void LoadDSO(const std::string& name) {
        // use wstring version that is needed by LLVM.
        std::wstring wname(name.begin(), name.end());
        lib_handle_ = LoadLibraryW(wname.c_str());
        CHECK(lib_handle_ != nullptr)
            << "Failed to load dynamic shared library " << name;
    }
    void* GetSymbol(const char* name) {
        return reinterpret_cast<void*>(
                GetProcAddress(lib_handle_, (LPCSTR)name)); // NOLINT(*)
    }
    void Unload() {
        FreeLibrary(lib_handle_);
    }
#else
    // Library handle
    void* lib_handle_{nullptr};
    void LoadDSO(const std::string & name) {
        lib_handle_ = dlopen(name.c_str(), RTLD_LAZY | RTLD_GLOBAL);
        CHECK(lib_handle_ != nullptr)
            << "Failed to load dynamic shared library " << name
            << " " << dlerror();
    }
    void* GetSymbol(const char* name) {
        return dlsym(lib_handle_, name);
    }
    void Unload() {
        dlclose(lib_handle_);
    }
#endif

protected:
    VTADPIEvalFunc _feval;
    std::map<int, std::vector<uint64_t > >  _userid_2_array;
    std::map<int, int>                      _userid_2_blkNd;
    HostDevice host_device_;
    MemDevice   mem_device_;
    std::thread tsim_thread_;
//    std::vector<uint64_t> _recv_vals;

};

void HostDevice::PushRequest(uint8_t opcode, uint8_t addr, uint32_t value) {
    HostRequest r;
    r.opcode = opcode;
    r.addr = addr;
    r.value = value;
    req_.Push(r);
}

bool HostDevice::TryPopRequest(HostRequest* r, bool pop) {
    r->opcode = 0xad;
    r->addr = 0xad;
    r->value = 0xbad;
    return req_.TryPop(r, pop);
}

void HostDevice::PushResponse(uint32_t value) {
    HostResponse r;
    r.value = value;
    resp_.Push(r);
}

void HostDevice::WaitPopResponse(HostResponse* r) {
    resp_.WaitPop(r);
}

void MemDevice::SetRequest(
        uint8_t  rd_req_valid,
        uint64_t rd_req_addr,
        uint32_t rd_req_len,
        uint32_t rd_req_id,
        uint64_t wr_req_addr,
        uint32_t wr_req_len,
        uint8_t  wr_req_valid) {

    std::lock_guard<std::mutex> lock(mutex_);
    if(rd_req_addr !=0 ){
        // todo change to my own memory
//        void * rd_vaddr = vta::vmem::VirtualMemoryManager::Global()->GetAddr(rd_req_addr);
        void * rd_vaddr = nullptr;
        if(rd_req_valid == 1) {
            rlen_ = rd_req_len + 1;
            rid_  = rd_req_id;
            raddr_ = reinterpret_cast<uint64_t*>(rd_vaddr);
        }
    }

    if(wr_req_addr != 0){
        //todo change to my own memory
//        void * wr_vaddr = vta::vmem::VirtualMemoryManager::Global()->GetAddr(wr_req_addr);
        void* wr_vaddr = nullptr;
        if (wr_req_valid == 1) {
            wlen_ = wr_req_len + 1;
            waddr_ = reinterpret_cast<uint64_t*>(wr_vaddr);
        }
    }
}

MemResponse MemDevice::ReadData(uint8_t ready, int blkNb) {
    std::lock_guard<std::mutex> lock(mutex_);
    MemResponse r;
    r.valid = rlen_ > 0;
    r.value = rlen_ > 0 ? raddr_ : dead_beef_;
    r.id    = rid_;
    if (ready == 1 && rlen_ > 0) {
        raddr_ += blkNb;
        rlen_ -= 1;
    }
    return r;
}

void MemDevice::WriteData(svOpenArrayHandle value, uint64_t wr_strb) {

    int lftIdx = svLeft(value, 1);
    int rgtIdx = svRight(value, 1);
    int blkNb  = lftIdx - rgtIdx + 1;
    assert(lftIdx >= 0);
    assert(rgtIdx >= 0);
    assert(lftIdx >= rgtIdx);
    assert(blkNb > 0);
    // supported up to 64bit strb
    assert(blkNb <= 8);

    std::lock_guard<std::mutex> lock(mutex_);
    int strbMask = 0xff;
    if (wlen_ > 0) {
        for (int idx = 0 ; idx < blkNb; ++idx) {
            int strbFlags = (wr_strb >> (idx * 8)) & strbMask;
            if (!(strbFlags == 0 || strbFlags == strbMask)) {
                LOG(FATAL) << "Unexpected strb data " << (void*)wr_strb;
            }
            if (strbFlags != 0) {
                uint64_t* elemPtr = (uint64_t*)svGetArrElemPtr1(value, rgtIdx + idx);
                assert(elemPtr != NULL);
                LOG(INFO) << "setting data as " << (*elemPtr);
                //todo set waddr to real addr
                //waddr_[idx] = (*elemPtr);
            }
        }
        waddr_ += blkNb;
        wlen_ -= 1;
    }
}

tvm::runtime::Module DPIChiselNode::Load(std::string dll_name) {
    auto n = tvm::runtime::make_object<DPIChiselNode>();
    n->Init(dll_name);
    return tvm::runtime::Module(n);
}

TVM_REGISTER_GLOBAL("runtime.module.loadfile_vta-chisel-tsim")
.set_body([](tvm::runtime::TVMArgs args, tvm::runtime::TVMRetValue * rv){
   *rv = DPIChiselNode::Load(args[0]);
   //const auto* f = runtime::Registry::Get("relax.FuncWithAttrs")
});

} // namespace dpi
} //namespace vta