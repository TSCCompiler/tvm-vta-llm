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

void matrix_multiply(std::string model_path){
    tvm::runtime::Module mod_dylib =
            tvm::runtime::Module::LoadFromFile(model_path.c_str());
    tvm::runtime::PackedFunc main_func = mod_dylib.GetFunction("__tvm_main__");
    int device_type = kDLExtDev;
    int device_id = 0;
    if (main_func== nullptr){
        LOG(ERROR) << "Failed to get main ";
    }else{
        LOG(INFO) << "got main func";
    }

}
int main(int argc, char** argv){
    matrix_multiply(argv[1]);
    return 0;
}