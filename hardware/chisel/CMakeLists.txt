tvm_option(HW_CONFIG "hardware configure pynq, de1no, etc" "DefaultPynqConfig")
tvm_option(TOP "top module name " "VTA")
tvm_option(USE_TRACE "trace to vcd file" ON)
tvm_option(USE_THREADS "use threads in verilator generator" OFF)

set(CONFIG_TEST "Test${HW_CONFIG}")
set(TOP_TEST "Test")


set(VERILATOR_BUILD_DIR ${CMAKE_BINARY_DIR}/verilator)
set(CHISEL_BUILD_DIR ${CMAKE_BINARY_DIR}/chisel)

set(CMAKE_CURRENT_SOURCE_DIR ${CMAKE_BINARY_DIR})


#verilator_opt = --cc
#verilator_opt += +define+RANDOMIZE_GARBAGE_ASSIGN
#verilator_opt += +define+RANDOMIZE_REG_INIT
#verilator_opt += +define+RANDOMIZE_MEM_INIT
#verilator_opt += --x-assign unique
#verilator_opt += --output-split 20000
#verilator_opt += --output-split-cfuncs 20000
#verilator_opt += --top-module ${TOP_TEST}
#verilator_opt += -Mdir ${verilator_build_dir}
#verilator_opt += -I$(chisel_build_dir)

set(VERILATOR_OPT "--cc")
set(VERILATOR_OPT "${VERILATOR_OPT} +define+RANDOMIZE_GARBAGE_ASSIGN")
#list(APPEND VERILATOR_OPT "+define+RANDOMIZE_GARBAGE_ASSIGN")
#list(APPEND VERILATOR_OPT "+define+RANDOMIZE_REG_INIT")
set(VERILATOR_OPT "${VERILATOR_OPT} +define+RANDOMIZE_REG_INIT")
#list(APPEND VERILATOR_OPT "+define+RANDOMIZE_MEM_INIT")
set(VERILATOR_OPT "${VERILATOR_OPT} +define+RANDOMIZE_MEM_INIT")
#list(APPEND VERILATOR_OPT "--x-assign unique")
set(VERILATOR_OPT "${VERILATOR_OPT} --x-assign unique")
#list(APPEND VERILATOR_OPT "--output-split 20000")
set(VERILATOR_OPT "${VERILATOR_OPT} --output-split 20000")
#list(APPEND VERILATOR_OPT "--output-split-cfuncs 20000")
set(VERILATOR_OPT "${VERILATOR_OPT} --output-split-cfuncs 20000")
#list(APPEND VERILATOR_OPT "--top-module ${TOP_TEST}")
set(VERILATOR_OPT "${VERILATOR_OPT} --top-module ${TOP_TEST}")
#list(APPEND VERILATOR_OPT "-Mdir ${VERILATOR_BUILD_DIR}")
set(VERILATOR_OPT "${VERILATOR_OPT} -Mdir ${VERILATOR_BUILD_DIR}")
#list(APPEND VERILATOR_OPT "-I${CHISEL_BUILD_DIR}")
set(VERILATOR_OPT "${VERILATOR_OPT} -I${CHISEL_BUILD_DIR}")

#string(REPLACE ";" "TEST" VERILATOR_OPT_STR ${VERILATOR_OPT})

message(STATUS "verilator compile flags ${VERILATOR_OPT}")

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-sign-compare -include V${TOP_TEST}.h")
add_definitions(
        "-DVL_TSIM_NAME=V${TOP_TEST}"
        -DVL_PRINTF=printf
        -DVL_USER_FINISH
        -DVM_COVERAGE=0
        -DVM_SC=0
)
include_directories(${VERILATOR_BUILD_DIR})
include_directories(${VERILATOR_INC_DIR})
include_directories(${VERILATOR_INC_DIR}/vltstd)
include_directories(${VTA_HW_PATH}/include)

if (USE_TRACE)
    add_definitions(-DVM_TRACE=1)
#    list(APPEND VERILATOR_OPT "--trace")
    set(VERILATOR_OPT "${VERILATOR_OPT} --trace")
    add_definitions("-DTSIM_TRACE_FILE=${verilator_build_dir}/${TOP_TEST}.vcd")
endif ()

set(VERILATOR_CMD "verilator ${VERILATOR_OPT} ${CHISEL_BUILD_DIR}/${TOP_TEST}.${HW_CONFIG}.v")
string(REPLACE "D:" "/mnt/d" MNT_VERI_CMD ${VERILATOR_CMD})
message(STATUS ${MNT_VERI_CMD})

if (IS_WINDOWS)
    tvm_file_glob(GLOB VERI_SRC ${VERILATOR_BUILD_DIR}/*.cpp)
    add_library(vta_hw SHARED
            ${VERI_SRC}
            ${VERILATOR_INC_DIR}/verilated_vcd_c.cpp
            ${VERILATOR_INC_DIR}/verilated.cpp
            ${VERILATOR_INC_DIR}/verilated_dpi.cpp
            ${VTA_HW_PATH}/hardware/dpi/tsim_device.cc
#            ${VTA_HW_PATH}/src/vmem/virtual_memory.cc
            )
#    target_link_libraries(vta_hw
#            D:/workspace/project/nn_compiler/tvm/cmake-build-debug-mingw_x86_64/libtvm.dll.a
#            )
endif ()