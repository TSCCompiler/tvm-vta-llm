//
// Created by sunhh on 2023/12/29.
//
#include <cstdio>
#include <dlpack/dlpack.h>
#include <tvm/runtime/module.h>
#include <tvm/runtime/registry.h>
#include <tvm/runtime/packed_func.h>
#include <fstream>
#include <iterator>
#include <algorithm>
#include <vta/runtime/runtime.h>

#if defined(_WIN32)
#include <windows.h>
#else
#include <dlfcn.h>
#endif


void matrix_multiply(std::string model_path){
    tvm::runtime::Module mod_dylib =
            tvm::runtime::Module::LoadFromFile(model_path.c_str());
    tvm::runtime::PackedFunc main_func = mod_dylib.GetFunction("__tvm_main__");
    int device_type = kDLExtDev;
    int device_id = 0;
    if (main_func== nullptr){
        LOG(FATAL) << "Failed to get main ";
    }else{
        LOG(INFO) << "got main func";
    }
    tvm::Device _device(DLDevice{kDLExtDev, 0});
    tvm::runtime::NDArray A_nd = tvm::runtime::NDArray::Empty({1,16,1,16}, tvm::DataType::Int(8),
                                                              _device);
    tvm::runtime::NDArray B_nd = tvm::runtime::NDArray::Empty({16,16,16,16}, tvm::DataType::Int(8),
                                                              _device);
    tvm::runtime::NDArray C_nd = tvm::runtime::NDArray::Empty({1,16,1,16}, tvm::DataType::Int(8),
                                                              _device);
    main_func(A_nd, B_nd, C_nd);


}
void* load_vta_driver(std::string vta_driver_dso){
#ifndef WIN32
    auto lib_handle_ = dlopen(vta_driver_dso.c_str(), RTLD_LAZY | RTLD_GLOBAL);
    ICHECK(lib_handle_ != nullptr) << "Failed to load dynamic shared library " << vta_driver_dso << " "
                                   << dlerror();
    return lib_handle_;
#else
    // use wstring version that is needed by LLVM.
    std::wstring wname(vta_driver_dso.begin(), vta_driver_dso.end());
    auto lib_handle_ = LoadLibraryW(wname.c_str());
    ICHECK(lib_handle_ != nullptr) << "Failed to load dynamic shared library " << vta_driver_dso;
    return lib_handle_;
#endif

}
int main(int argc, char** argv){
    auto driver_handle = load_vta_driver(argv[1]);
    matrix_multiply(argv[2]);
    return 0;
}