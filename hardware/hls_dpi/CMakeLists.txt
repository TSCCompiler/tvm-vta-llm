include("${CMAKE_SOURCE_DIR}/cmake/vta_dpi.cmake")
# /mnt/workspace/project/nn_compiler/vta-hw/hardware/chisel/test_run_dir/TestTopVerilog
GenVerilatedDPI(hls_tsim_device HostSimAxiliteModule ${TestTopPath}
        hls_tsim_device.cc
)

add_executable(hls_dpi_test
    hls_dpi_test.cc
)
target_link_libraries(hls_dpi_test
    hls_tsim_device
)