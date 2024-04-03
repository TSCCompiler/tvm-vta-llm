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

#if defined(_WIN32)
#include <windows.h>
#else
#include <dlfcn.h>
#endif

namespace vta {
namespace chisel{
    using namespace tvm::runtime;

/*! \brief The type of VTADPISim function pointer */
//    int VTADPIEval(int nstep)
typedef int (*VTADPIEvalFunc)(int);

using tvm::runtime::Module;

class DPIChiselNode : public tvm::runtime::ModuleNode {
public:
    const char * type_key() const override {
        return "DPIChiselNode";
    }



    static tvm::runtime::Module Load(std::string dll_name);
protected:
    void Init(const std::string & name) {
        LoadDSO(name);
        _feval = reinterpret_cast<VTADPIEvalFunc >(GetSymbol("VTADPIEval"));
        CHECK(_feval != nullptr);
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
        lib_handle_ = dlopen(name.c_str(), RTLD_LAZY | RTLD_LOCAL);
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

};



tvm::runtime::Module DPIChiselNode::Load(std::string dll_name) {
    auto n = tvm::runtime::make_object<DPIChiselNode>();
    n->Init(dll_name);
    return tvm::runtime::Module(n);
}

TVM_REGISTER_GLOBAL("runtime.module.loadfile_chisel-tsim")
.set_body([](tvm::runtime::TVMArgs args, tvm::runtime::TVMRetValue * rv){
   *rv = DPIChiselNode::Load(args[0]);
   //const auto* f = runtime::Registry::Get("relax.FuncWithAttrs")
});

} // namespace dpi
} //namespace vta