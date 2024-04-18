//
// Created by sunhh on 24-4-3.
//
#include <tvm/runtime/registry.h>
#include <tvm/runtime/packed_func.h>
#include <tvm/runtime/ndarray.h>
#include <dlfcn.h>
#include <thread>

bool get_bit_mask(int val, int bit_id){
    int mask = int(1) << bit_id;
    int mask_and = val & mask;
    bool masked = (mask_and) >> bit_id;
    return masked;
}
int set_bit_mask(int val, int bit_id, bool flag){
    int ret = val;
    int mask = int(1) << bit_id;
    if (flag) {
        ret = val | mask;
    } else {
        mask = ~mask;
        ret = val & mask;
    }
    return ret;
}

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
        int control_signals = f_read(0x0);
        bool ap_start = get_bit_mask(control_signals, 0);
        bool ap_done = get_bit_mask(control_signals, 1);
        bool ap_idle = get_bit_mask(control_signals, 2);
        bool ap_ready = get_bit_mask(control_signals, 3);
        bool ap_auto_restart = get_bit_mask(control_signals, 7);
        LOG(INFO) << "ap start " << ap_start
        <<"ap_ready " << ap_ready;
        f_write(0x10, 5);
        f_write(0x18, 10);
        control_signals = set_bit_mask(control_signals, 0, true);
        f_write(0x0, control_signals);
        do {
            control_signals = f_read(0x0);
            bool ap_done = get_bit_mask(control_signals, 1);
            if(ap_done){
                break;
            }
        } while (true);

//        printf("control signals %x\n", control_signals);
        int c_val = f_read(0x28);
        int c_valid = f_read(0x2c);
        if (c_valid){
            LOG(INFO) << "c val " << c_val;
        }

//        control_signals = f_read(0x0);
//        printf("control signals %x\n", control_signals);
//
//        int val = f_read(0x18);
//        LOG(INFO) << "val : " << val;


    }
//    tvm::runtime::NDArray ret_arr = f3(15);
//    LOG(INFO) << "ret is " << ret;
//    LOG(INFO) << "ret array is " << ret_arr.Shape();
    return 0;
}