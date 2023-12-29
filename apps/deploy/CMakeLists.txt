# This file handles building each task as sub-project.
#
# Each task becomes an independent project in which you can experiment.
#
# Tasks are added as separate sub-projects so as compilation errors in
# one task don't affect another task.

if (USE_VTA_FSIM)
    add_executable(cpp_module_deploy_sim
            cpp_module_deploy.cpp
            )
    target_include_directories(cpp_module_deploy_sim SYSTEM PUBLIC ${VTA_HW_PATH}/include)
    target_compile_definitions(cpp_module_deploy_sim PUBLIC DMLC_USE_LOGGING_LIBRARY=<tvm/runtime/logging.h>)
    if (TVM_LIBRARY_PATH)
        target_link_libraries(cpp_module_deploy_sim
                #            D:/workspace/project/nn_compiler/tvm/cmake-build-debug-mingw_x86_64/libtvm.dll.a
                #            D:/workspace/project/nn_compiler/tvm/cmake-build-release_mingw/libtvm.dll.a
                ${TVM_LIBRARY_PATH}
                vta_fsim
                )
    endif ()
endif ()
