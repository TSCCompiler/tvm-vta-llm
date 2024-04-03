//
// Created by sunhh on 24-4-3.
//
#include <tvm/runtime/registry.h>
#include <tvm/runtime/packed_func.h>
#include <dlfcn.h>

int main(int argc, char** argv)
{
    void* lib_handle_ = dlopen("/mnt/workspace/project/nn_compiler/vta-hw/cmake-build-debug/libvta_chisel.so", RTLD_LAZY | RTLD_LOCAL);
    CHECK(lib_handle_ != nullptr)
        << "Failed to load dynamic shared library "
        << " " << dlerror();
    const auto* f = tvm::runtime::Registry::Get("runtime.module.loadfile_chisel-tsim");
    tvm::runtime::Module n = (*f)(argv[1]);
    auto f2 = n.GetFunction("Eval");
    int ret = f2(10);
    LOG(INFO) << "ret is " << ret;
    return 0;
}