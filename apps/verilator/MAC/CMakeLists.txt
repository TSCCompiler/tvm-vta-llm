include(../../../cmake/tvm_verilator.cmake)
include_directories(build)
include_directories(include)

tvm_file_glob(GLOB VERILATOR_SRC build/*.cpp)

if (IS_WINDOWS)
    add_executable(MAC_TB
            mac_tb.cpp
            ${VERILATOR_SRC}
            include/verilated.cpp
            include/verilated_vcd_c.cpp
            )
endif ()

# tvm_file_glob(GLOB_RECURSE TEST_SRCS tests/cpp/*.cc)

