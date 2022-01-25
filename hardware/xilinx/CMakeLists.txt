set(ROOTDIR ${CMAKE_CURRENT_SOURCE_DIR})
set(VTA_HW_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../..)
set(SCRIPT_DIR ${CMAKE_CURRENT_SOURCE_DIR}/scripts)
set(SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)
set(BUILD_DIR ${CMAKE_CURRENT_BINARY_DIR})

set(VIVADO_HLS vivado_hls)
set(VIVADO vivado)

set(VTA_CONFIG "${VTA_HW_DIR}/config/vta_config.py")

# OUTPUT_VARIABLE
set(CONF "xc7z100ffg900-2_1x16_i8w8a32_15_15_18_17")
execute_process(COMMAND python ${VTA_CONFIG} --cfg-str
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        OUTPUT_VARIABLE CONF)
string(STRIP ${CONF} CONF)
message(STATUS "got conf ${CONF}")
SET(IP_BUILD_PATH "${BUILD_DIR}/hls/${CONF}")
SET(HW_BUILD_PATH "${BUILD_DIR}/vivado/${CONF}")

set(CONFIG_TCL "${BUILD_DIR}/include/vta_config.tcl")
message(STATUS "got config tcl ${CONFIG_TCL}")
set(IP_PATH ${BUILD_DIR}/hls/${CONF}/vta_compute/soln/impl/ip/xilinx_com_hls_compute_1_0.zip)

# Bitstream file path
set(BIT_PATH ${BUILD_DIR}/vivado/${CONF}/export/${CONF}.bit)
message(STATUS "python  ${VTA_CONFIG} --export-tcl ${CONFIG_TCL}")

add_custom_command(OUTPUT ${BUILD_DIR}/include
        COMMAND mkdir
        ARGS include
        WORKING_DIRECTORY ${BUILD_DIR}
        )
add_custom_target(inc_dir
        DEPENDS ${BUILD_DIR}/include
       )

add_custom_command(
        OUTPUT "${CONFIG_TCL}"
        COMMAND python
        ARGS "${VTA_CONFIG}" --export-tcl "${CONFIG_TCL}"
        WORKING_DIRECTORY ${BUILD_DIR}
        DEPENDS  ${inc_dir}
        )

add_custom_target(tcl
        DEPENDS ${CONFIG_TCL}
       )

add_custom_command(
        OUTPUT ${IP_PATH}
        COMMAND ${VIVADO_HLS}
        ARGS
#        -f "${SCRIPT_DIR}/hls.tcl"
#        -tclargs "${VTA_HW_DIR}" "${CONFIG_TCL}"
        WORKING_DIRECTORY ${IP_BUILD_PATH}
        DEPENDS ${tcl}
)
add_custom_target(ip
        DEPENDS ${IP_PATH})


