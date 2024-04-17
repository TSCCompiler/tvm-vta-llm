//
// Created by sunhh on 24-4-3.
//
#include <tvm/runtime/registry.h>
#include <tvm/runtime/packed_func.h>
#include <tvm/runtime/ndarray.h>
#include <dlfcn.h>
#include <thread>

int main(int argc, char** argv)
{
    void* lib_handle_ = dlopen("/mnt/workspace/project/nn_compiler/vta-hw/cmake-build-debug/libvta_chisel.so", RTLD_LAZY | RTLD_LOCAL);
    CHECK(lib_handle_ != nullptr)
        << "Failed to load dynamic shared library "
        << " " << dlerror();
    const auto* f = tvm::runtime::Registry::Get("runtime.module.loadfile_vta-chisel-tsim");
    tvm::runtime::Module n = (*f)(argv[1]);
    auto f2 = n.GetFunction("Eval");
    auto f3 = n.GetFunction("GetArray");
    auto f_write = n.GetFunction("WriteReg");
    auto f_read = n.GetFunction("ReadReg");
    int ret = f2(10);
    std::this_thread::sleep_for(std::chrono::seconds (5));
    if (ret){
        printf("begin to cal it");
        f_write(0x18, 5);
        int val = f_read(0x18);
        LOG(INFO) << "val : " << val;
    }
//    tvm::runtime::NDArray ret_arr = f3(15);
//    LOG(INFO) << "ret is " << ret;
//    LOG(INFO) << "ret array is " << ret_arr.Shape();
    return 0;
}