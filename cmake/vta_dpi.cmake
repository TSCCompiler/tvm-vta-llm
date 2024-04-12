macro(GenVerilatedDPI TARGET_NAME TOP_NAME V_DIR)
    message(STATUS "TOP_NAME is ${TOP_NAME}")
    set(VERILATOR_OPT "--cc")
    set(VERILATOR_OPT "${VERILATOR_OPT} +define+RANDOMIZE_GARBAGE_ASSIGN")
    set(VERILATOR_OPT "${VERILATOR_OPT} +define+RANDOMIZE_REG_INIT")
    set(VERILATOR_OPT "${VERILATOR_OPT} +define+RANDOMIZE_MEM_INIT")
    set(VERILATOR_OPT "${VERILATOR_OPT} -Wno-Warning-STMTDLY")
    set(VERILATOR_OPT "${VERILATOR_OPT} --x-assign unique")
    set(VERILATOR_OPT "${VERILATOR_OPT} --output-split 20000")
    set(VERILATOR_OPT "${VERILATOR_OPT} --output-split-cfuncs 20000")
    set(VERILATOR_OPT "${VERILATOR_OPT} --top-module ${TOP_NAME}")
    set(VERILATOR_OPT "${VERILATOR_OPT} -Mdir ${CMAKE_CURRENT_BINARY_DIR}")
    set(VERILATOR_OPT "${VERILATOR_OPT} -I${V_DIR}")

    if (MSVC)
        #    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -include V${TOP_TEST}.h")
    else (MSVC)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-sign-compare -include V${TOP_NAME}.h")
    endif (MSVC)

    include_directories(${VERILATOR_INC_DIR})
    include_directories(${VERILATOR_INC_DIR}/vltstd)
    include_directories(${VTA_HW_PATH}/include)
    include_directories(${CMAKE_CURRENT_BINARY_DIR})
    add_definitions(
            "-DVL_TSIM_NAME=V${TOP_NAME}"
            -DVL_PRINTF=printf
            -DVL_USER_FINISH
            -DVM_COVERAGE=0
            -DVM_SC=0
    )
    add_definitions(-DVM_TRACE=1)
    set(VERILATOR_OPT "${VERILATOR_OPT} --trace")
    add_definitions("-DTSIM_TRACE_FILE=${CMAKE_CURRENT_BINARY_DIR}/${TOP_NAME}.vcd")

    set(VERILATOR_CMD "verilator ${VERILATOR_OPT} ${V_DIR}/${TOP_NAME}.v")
    set(VERILATOR_OPT "${VERILATOR_OPT} ${V_DIR}/${TOP_NAME}.v")
    string(REPLACE "D:" "/mnt/d" MNT_VERI_CMD ${VERILATOR_CMD})
    message(STATUS ${MNT_VERI_CMD})
    if (IS_WINDOWS)
        tvm_file_glob(GLOB VERI_SRC ${CMAKE_CURRENT_BINARY_DIR}/*.cpp)
        add_library(${TARGET_NAME} SHARED
                ${VERI_SRC}
                ${VERILATOR_INC_DIR}/verilated_vcd_c.cpp
                ${VERILATOR_INC_DIR}/verilated.cpp
                ${VERILATOR_INC_DIR}/verilated_dpi.cpp
                ${ARGN}
#                ${VTA_HW_PATH}/hardware/dpi/tsim_device.cc
                #            ${VTA_HW_PATH}/src/vmem/virtual_memory.cc
        )
    else (IS_WINDOWS)
        add_custom_command(OUTPUT
                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}.cpp
                #                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}__1.cpp
                #                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}__1__Slow.cpp
                #                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}__Dpi.cpp
                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}__Slow.cpp
                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}__Syms.cpp
                #                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}_DotProduct.cpp
                #                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}_DotProduct__Slow.cpp
                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}__Trace.cpp
                #                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}__Trace__1.cpp
                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}__Trace__Slow.cpp
                COMMAND "${VERILATOR_BIN}"
                ARGS "--cc"
                +define+RANDOMIZE_GARBAGE_ASSIGN
                +define+RANDOMIZE_REG_INIT
                +define+RANDOMIZE_MEM_INIT
                --x-assign unique
                --output-split 20000
                --output-split-cfuncs 20000
                "--top-module"
                "${TOP_NAME}"
                "-Mdir"
                "${CMAKE_CURRENT_BINARY_DIR}"
                "-I${V_DIR}"
                ${V_DIR}/${TOP_NAME}.v
                "--trace"
                DEPENDS
                ${ARGN}

        )
        add_library(${TARGET_NAME} SHARED
                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}.cpp
#                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}__1.cpp
#                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}__1__Slow.cpp
#                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}__Dpi.cpp
                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}__Slow.cpp
                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}__Syms.cpp
#                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}_DotProduct.cpp
#                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}_DotProduct__Slow.cpp
                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}__Trace.cpp
#                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}__Trace__1.cpp
                ${CMAKE_CURRENT_BINARY_DIR}/V${TOP_NAME}__Trace__Slow.cpp
                ${VERILATOR_INC_DIR}/verilated_vcd_c.cpp
                ${VERILATOR_INC_DIR}/verilated.cpp
                ${VERILATOR_INC_DIR}/verilated_dpi.cpp
                ${ARGN}
        )

    endif (IS_WINDOWS)



endmacro()