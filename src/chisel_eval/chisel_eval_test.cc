//
// Created by sunhh on 24-4-3.
//
#include <tvm/runtime/registry.h>
#include <tvm/runtime/packed_func.h>
#include <tvm/runtime/ndarray.h>
#ifndef WIN32
#include <dlfcn.h>
#else
#include <windows.h>
#endif
#include <thread>

int main(int argc, char** argv)
{
#ifdef WIN32
    HMODULE lib_handle_{nullptr};
    std::string name = argv[1];
    std::wstring wname(name.begin(), name.end());
    lib_handle_ = LoadLibraryW(wname.c_str());
    CHECK(lib_handle_ != nullptr)
        << "Failed to load dynamic shared library " << name;
#else
    void* lib_handle_ = dlopen("/mnt/workspace/project/nn_compiler/vta-hw/cmake-build-debug/libvta_chisel.so", RTLD_LAZY | RTLD_LOCAL);
    CHECK(lib_handle_ != nullptr)
        << "Failed to load dynamic shared library "
        << " " << dlerror();
#endif
    const auto* f = tvm::runtime::Registry::Get("runtime.module.loadfile_vta-chisel-tsim");
    tvm::runtime::Module n = (*f)(argv[2]);
    auto f2 = n.GetFunction("Eval");
    auto f3 = n.GetFunction("GetArray");
    auto f_write = n.GetFunction("WriteReg");
    auto f_read = n.GetFunction("ReadReg");
    int ret = f2(10);
    std::this_thread::sleep_for(std::chrono::seconds (5));
    if (ret){
        printf("begin to cal it");
        f_write(16, 5);
        int val = f_read(16);
        LOG(INFO) << "val : " << val;
    }
//    tvm::runtime::NDArray ret_arr = f3(15);
//    LOG(INFO) << "ret is " << ret;
//    LOG(INFO) << "ret array is " << ret_arr.Shape();
    return 0;
}