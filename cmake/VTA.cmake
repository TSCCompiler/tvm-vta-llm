# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# CMake Build rules for VTA
find_program(PYTHON NAMES python python3 python3.6)

# Throw error if VTA_HW_PATH is not set
if (NOT VTA_HW_PATH)
  if(NOT DEFINED ENV{VTA_HW_PATH})
    message(STATUS "setting vta to local")
    set(VTA_HW_PATH ${CMAKE_CURRENT_SOURCE_DIR})
  else()
    set(VTA_HW_PATH $ENV{VTA_HW_PATH})
  endif()
endif ()
message(STATUS "VTA HW PATH ${VTA_HW_PATH}")


#add_definitions("-DTVM_EXPORTS=")


if(MSVC2)
  message(STATUS "VTA build is skipped in Windows..")
elseif(NOT EXISTS ${VTA_HW_PATH})
  if (USE_VTA_TSIM OR USE_VTA_FSIM OR USE_UFPGA)
    message(FATAL_ERROR "VTA path " ${VTA_HW_PATH} " does not exist")
  endif()
elseif(PYTHON)
  message(STATUS "VTA build with VTA_HW_PATH=" ${VTA_HW_PATH})
  set(VTA_CONFIG ${PYTHON} ${VTA_HW_PATH}/config/vta_config.py)

  if(EXISTS ${CMAKE_CURRENT_BINARY_DIR}/vta_config.json)
    message(STATUS "Use VTA config " ${CMAKE_CURRENT_BINARY_DIR}/vta_config.json)
    set(VTA_CONFIG ${PYTHON} ${VTA_HW_PATH}/config/vta_config.py
      --use-cfg=${CMAKE_CURRENT_BINARY_DIR}/vta_config.json)
  endif()

  execute_process(COMMAND ${VTA_CONFIG} --target OUTPUT_VARIABLE VTA_TARGET OUTPUT_STRIP_TRAILING_WHITESPACE)

  message(STATUS "Build VTA runtime with target: " ${VTA_TARGET})

  execute_process(COMMAND ${VTA_CONFIG} --defs OUTPUT_VARIABLE __vta_defs)
  message(STATUS "vta_defs ${__vta_defs}")


  string(REGEX MATCHALL "(^| )-D[A-Za-z0-9_=.]*" VTA_DEFINITIONS "${__vta_defs}")

  # Fast simulator driver build
  if(USE_VTA_FSIM)
    # Add fsim driver sources
    tvm_file_glob(GLOB FSIM_RUNTIME_SRCS ${VTA_HW_PATH}/src/*.cc)
    tvm_file_glob(GLOB FSIM_RUNTIME_SRCS vta/runtime/*.cc)
    list(APPEND FSIM_RUNTIME_SRCS ${VTA_HW_PATH}/src/sim/sim_driver.cc)
    list(APPEND FSIM_RUNTIME_SRCS ${VTA_HW_PATH}/src/sim/sim_tlpp.cc)
    list(APPEND FSIM_RUNTIME_SRCS ${VTA_HW_PATH}/src/vmem/virtual_memory.cc)
    # Target lib: vta_fsim
    message(STATUS "${FSIM_RUNTIME_SRCS}")
    add_library(vta_fsim SHARED
            ${FSIM_RUNTIME_SRCS}
#            ${VTA_HW_PATH}/src/tvm_runtime/tvm_runtime_pack.cc
            )
    target_include_directories(vta_fsim SYSTEM PUBLIC ${VTA_HW_PATH}/include)
    target_compile_definitions(vta_fsim PUBLIC DMLC_USE_LOGGING_LIBRARY=<tvm/runtime/logging.h>)
    message(STATUS "defines ${VTA_DEFINITIONS}")
    foreach(__def ${VTA_DEFINITIONS})
      message(STATUS "__strip_def:${__strip_def}")
      string(SUBSTRING ${__def} 3 -1 __strip_def)

      target_compile_definitions(vta_fsim PUBLIC ${__strip_def})
    endforeach()
    if(APPLE)
      set_property(TARGET vta_fsim APPEND PROPERTY LINK_FLAGS "-undefined dynamic_lookup")
    endif(APPLE)
    target_compile_definitions(vta_fsim PUBLIC USE_FSIM_TLPP)
    if (TVM_LIBRARY_PATH)
      target_link_libraries(vta_fsim
              #            D:/workspace/project/nn_compiler/tvm/cmake-build-debug-mingw_x86_64/libtvm.dll.a
              #            D:/workspace/project/nn_compiler/tvm/cmake-build-release_mingw/libtvm.dll.a
              ${TVM_LIBRARY_PATH}
      )
    endif ()

  endif()

  # Cycle accurate simulator driver build
  if(USE_VTA_TSIM)
    if (VERILATOR_INC_DIR)
      message(STATUS "set verilator inc dir : ${VERILATOR_INC_DIR}")
    elseif(DEFINED ENV{VERILATOR_INC_DIR})
      set(VERILATOR_INC_DIR $ENV{VERILATOR_INC_DIR})
    elseif (EXISTS /usr/local/share/verilator/include)
      set(VERILATOR_INC_DIR /usr/local/share/verilator/include)
    elseif (EXISTS /usr/share/verilator/include)
      set(VERILATOR_INC_DIR /usr/share/verilator/include)
    else()
      message(STATUS "Verilator not found in /usr/local/share/verilator/include")
      message(STATUS "Verilator not found in /usr/share/verilator/include")
      message(FATAL_ERROR "Cannot find Verilator, VERILATOR_INC_DIR is not defined")
    endif()
    # Add tsim driver sources
    tvm_file_glob(GLOB TSIM_RUNTIME_SRCS ${VTA_HW_PATH}/src/*.cc)
    tvm_file_glob(GLOB TSIM_RUNTIME_SRCS vta/runtime/*.cc)
    list(APPEND TSIM_RUNTIME_SRCS ${VTA_HW_PATH}/src/tsim/tsim_driver.cc)
    list(APPEND TSIM_RUNTIME_SRCS ${VTA_HW_PATH}/src/dpi/module.cc)
    list(APPEND TSIM_RUNTIME_SRCS ${VTA_HW_PATH}/src/vmem/virtual_memory.cc)
    message(STATUS "vta_tsim srcs : ${TSIM_RUNTIME_SRCS}")
    # Target lib: vta_tsim
    add_library(vta_tsim SHARED ${TSIM_RUNTIME_SRCS})
    target_include_directories(vta_tsim SYSTEM PUBLIC ${VTA_HW_PATH}/include ${VERILATOR_INC_DIR} ${VERILATOR_INC_DIR}/vltstd)
    target_compile_definitions(vta_tsim PUBLIC DMLC_USE_LOGGING_LIBRARY=<tvm/runtime/logging.h>)
    foreach(__def ${VTA_DEFINITIONS})
      string(SUBSTRING ${__def} 3 -1 __strip_def)
      target_compile_definitions(vta_tsim PUBLIC ${__strip_def})
    endforeach()
    if(APPLE)
      set_property(TARGET vta_tsim APPEND PROPERTY LINK_FLAGS "-undefined dynamic_lookup")
    endif(APPLE)

    if (IS_WINDOWS)
      if (TVM_LIBRARY_PATH)
        target_link_libraries(vta_tsim
                #            D:/workspace/project/nn_compiler/tvm/cmake-build-debug-mingw_x86_64/libtvm.dll.a
                #            D:/workspace/project/nn_compiler/tvm/cmake-build-release_mingw/libtvm.dll.a
                ${TVM_LIBRARY_PATH}
        )
      endif ()
#      target_link_libraries(vta_tsim
##              D:/workspace/project/nn_compiler/tvm/cmake-build-debug-mingw_x86_64/libtvm.dll.a
#              D:/workspace/project/nn_compiler/tvm/cmake-build-release_mingw/libtvm.dll.a
#              )
    endif ()

  endif()

  # VTA FPGA driver sources
  if(USE_VTA_FPGA)
    tvm_file_glob(GLOB FSIM_RUNTIME_SRCS ${VTA_HW_PATH}/src/*.cc)
    tvm_file_glob(GLOB FPGA_RUNTIME_SRCS vta/runtime/*.cc)
    # Rules for Zynq-class FPGAs with pynq OS support (see pynq.io)
    if(${VTA_TARGET} STREQUAL "pynq" OR
       ${VTA_TARGET} STREQUAL "ultra96")
      list(APPEND FPGA_RUNTIME_SRCS ${VTA_HW_PATH}/src/pynq/pynq_driver.cc)
      # Rules for Pynq v2.4
      find_library(__cma_lib NAMES cma PATH /usr/lib)
    elseif(${VTA_TARGET} STREQUAL "de10nano")  # DE10-Nano rules
      tvm_file_glob(GLOB DE10_FPGA_RUNTIME_SRCS ${VTA_HW_PATH}/src/de10nano/*.cc ${VTA_HW_PATH}/src/*.cc)
      list(APPEND FPGA_RUNTIME_SRCS ${DE10_FPGA_RUNTIME_SRCS})
    elseif(${VTA_TARGET} STREQUAL "intelfocl")  # Intel OpenCL for FPGA rules
      tvm_file_glob(GLOB FOCL_SRC ${VTA_HW_PATH}/src/oclfpga/*.cc)
      list(APPEND FPGA_RUNTIME_SRCS ${FOCL_SRC})
      list(APPEND FPGA_RUNTIME_SRCS ${VTA_HW_PATH}/src/vmem/virtual_memory.cc ${VTA_HW_PATH}/src/vmem/virtual_memory.h)
    endif()
    # Target lib: vta
    add_library(vta SHARED ${FPGA_RUNTIME_SRCS})
    target_include_directories(vta PUBLIC vta/runtime)
    target_include_directories(vta PUBLIC ${VTA_HW_PATH}/include)
    target_compile_definitions(vta PUBLIC DMLC_USE_LOGGING_LIBRARY=<tvm/runtime/logging.h>)
    foreach(__def ${VTA_DEFINITIONS})
      string(SUBSTRING ${__def} 3 -1 __strip_def)
      target_compile_definitions(vta PUBLIC ${__strip_def})
    endforeach()
    if(${VTA_TARGET} STREQUAL "pynq" OR
       ${VTA_TARGET} STREQUAL "ultra96")
      target_link_libraries(vta ${__cma_lib})
    elseif(${VTA_TARGET} STREQUAL "de10nano")  # DE10-Nano rules
     #target_compile_definitions(vta PUBLIC VTA_MAX_XFER=2097152) # (1<<21)
      target_include_directories(vta SYSTEM PUBLIC ${VTA_HW_PATH}/src/de10nano)
      target_include_directories(vta SYSTEM PUBLIC 3rdparty)
      target_include_directories(vta SYSTEM PUBLIC
        "/usr/local/intelFPGA_lite/18.1/embedded/ds-5/sw/gcc/arm-linux-gnueabihf/include")
    elseif(${VTA_TARGET} STREQUAL "intelfocl")  # Intel OpenCL for FPGA rules
      target_include_directories(vta PUBLIC 3rdparty)
      set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17")
      target_link_libraries(vta -lOpenCL)
    endif()
  endif()

  # VTA Chisel eval
  if (USE_CHISEL_EVAL)
    if (VERILATOR_INC_DIR)
      message(STATUS "set verilator inc dir : ${VERILATOR_INC_DIR}")
    elseif(DEFINED ENV{VERILATOR_INC_DIR})
      set(VERILATOR_INC_DIR $ENV{VERILATOR_INC_DIR})
    elseif (EXISTS /usr/local/share/verilator/include)
      set(VERILATOR_INC_DIR /usr/local/share/verilator/include)
    elseif (EXISTS /usr/share/verilator/include)
      set(VERILATOR_INC_DIR /usr/share/verilator/include)
    else()
      message(STATUS "Verilator not found in /usr/local/share/verilator/include")
      message(STATUS "Verilator not found in /usr/share/verilator/include")
      message(FATAL_ERROR "Cannot find Verilator, VERILATOR_INC_DIR is not defined")
    endif()
    # Add tsim driver sources
    tvm_file_glob(GLOB CHISEL_RUNTIME_SRCS ${VTA_HW_PATH}/src/*.cc)
    tvm_file_glob(GLOB CHISEL_RUNTIME_SRCS ${VTA_HW_PATH}/vta/runtime/*.cc)
    list(APPEND CHISEL_RUNTIME_SRCS ${VTA_HW_PATH}/src/vmem/virtual_memory.cc)
    list(APPEND CHISEL_RUNTIME_SRCS ${VTA_HW_PATH}/src/chisel_eval/chisel_eval.cc)
    list(APPEND CHISEL_RUNTIME_SRCS ${VTA_HW_PATH}/src/chisel_eval/chisel_driver.cc)

    # Target lib: vta_tsim
    add_library(vta_chisel SHARED ${CHISEL_RUNTIME_SRCS})
    target_include_directories(vta_chisel SYSTEM PUBLIC ${VTA_HW_PATH}/include ${VERILATOR_INC_DIR} ${VERILATOR_INC_DIR}/vltstd)
    target_compile_definitions(vta_chisel PUBLIC DMLC_USE_LOGGING_LIBRARY=<tvm/runtime/logging.h>)
    foreach(__def ${VTA_DEFINITIONS})
      string(SUBSTRING ${__def} 3 -1 __strip_def)
      target_compile_definitions(vta_chisel PUBLIC ${__strip_def})
    endforeach()
    if(APPLE)
      set_property(TARGET vta_chisel APPEND PROPERTY LINK_FLAGS "-undefined dynamic_lookup")
    endif(APPLE)

    if (IS_WINDOWS)
      if (TVM_LIBRARY_PATH)
        target_link_libraries(vta_chisel
                #            D:/workspace/project/nn_compiler/tvm/cmake-build-debug-mingw_x86_64/libtvm.dll.a
                #            D:/workspace/project/nn_compiler/tvm/cmake-build-release_mingw/libtvm.dll.a
                ${TVM_LIBRARY_PATH}
        )
      endif ()
      #      target_link_libraries(vta_tsim
      ##              D:/workspace/project/nn_compiler/tvm/cmake-build-debug-mingw_x86_64/libtvm.dll.a
      #              D:/workspace/project/nn_compiler/tvm/cmake-build-release_mingw/libtvm.dll.a
      #              )
    endif ()

    add_executable(vta_chisel_test
            ${VTA_HW_PATH}/src/chisel_eval/chisel_eval_test.cc
    )
    target_link_libraries(vta_chisel_test
            vta_chisel
            ${TVM_RUNTIME_LIBRARY_PATH}
            ${CMAKE_DL_LIBS}
    )
    add_dependencies(vta_chisel_test
            vta_chisel
            hls_tsim_device
    )

  endif ()


else()
  message(STATUS "Cannot found python in env, VTA build is skipped..")
endif()
