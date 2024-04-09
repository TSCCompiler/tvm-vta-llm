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

#if defined(_WIN32)
#include <windows.h>
#else
#include <dlfcn.h>
#include <cassert>

#endif

namespace vta {
namespace chisel{
    using namespace tvm::runtime;
    typedef struct _AxisElem
    {
        uint64_t val[2];
    }AxisElem;

/*! \brief The type of VTADPISim function pointer */
//    int VTADPIEval(int nstep)
typedef int (*VTADPIEvalFunc)(int);
typedef void (*VTAHLSDPIInitFunc)(VTAContextHandle ctx,
                           VTAAxisDPIFunc axisDpiFunc);

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
            const svOpenArrayHandle rd_bits,
            dpi8_t rd_valid,
            dpi8_t* rd_ready){
        CHECK(self!= nullptr) << "got empty vta context handle in axis host callback";
        reinterpret_cast<DPIChiselNode*>(self)->on_hls_stream_data(rd_bits,
                                                                   rd_valid,
                                                                   rd_ready);
    }
protected:
    void on_hls_stream_data(const svOpenArrayHandle rd_bits,
                            dpi8_t rd_valid,
                            dpi8_t* rd_ready){
        *rd_ready = 1;
        if (rd_valid){
            assert(rd_bits != NULL);
            assert(svSize(rd_bits, 1) == 2);
            assert(svDimensions(rd_bits) == 1);

            assert(svSize(rd_bits, 0) == 64);
            int rgtIdx = svRight(rd_bits, 1);
            AxisElem nelem;
            for (int i = 0; i < 2; ++i) {
                uint64_t * elemPtr = (uint64_t*) svGetArrElemPtr1(rd_bits, rgtIdx+i);
                assert(elemPtr != NULL);
                auto value = elemPtr[0];
                nelem.val[i] = value;
            }
            _recv_vals.push_back(nelem);

        }



    }
protected:
    void Init(const std::string & name) {
        LoadDSO(name);
        _feval = reinterpret_cast<VTADPIEvalFunc >(GetSymbol("VTADPIEval"));
        CHECK(_feval != nullptr);
        auto _init_func = reinterpret_cast<VTAHLSDPIInitFunc >(GetSymbol("VTAHLSDPIInit"));
        CHECK(_init_func != nullptr);
        _init_func(this, VTAAxisDPIFunc);
        _recv_vals.clear();

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
            return TypedPackedFunc<tvm::runtime::NDArray()>(
                    [this](){
                        auto arr = tvm::runtime::NDArray::Empty({static_cast<long>(_recv_vals.size()), 2},
                                                            DLDataType{kDLUInt, 64, 1},
                                                            DLDevice{kDLCPU, 0});
                        int axis_elem_sz = sizeof (AxisElem);
                        LOG(INFO) << "axis elem sz " << axis_elem_sz;
                        arr.CopyFromBytes(_recv_vals.data(), _recv_vals.size()*sizeof (AxisElem));
                        return arr;
                    }
            );
        }
    }
    int eval_step(int nstep){
        if (_feval){
            int ret = _feval(nstep);
            return ret;
        }
        return -1;
    }
protected:
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

protected:
    VTADPIEvalFunc _feval;
    std::vector<AxisElem> _recv_vals;

};



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