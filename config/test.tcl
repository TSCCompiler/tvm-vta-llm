proc const {name value} {
    uplevel 1 [list set $name $value]
    uplevel 1 [list trace var $name w {error constant ;#} ]
}
const CFLAGS "-I/home/share/data/workspace/project/fpga/include -I/home/share/data/workspace/project/fpga/hls/vta-hw/include -I/home/share/data/workspace/project/fpga/3rdparty/dlpack/include -I/home/share/data/workspace/project/fpga/3rdparty/dmlc-core/include -DVTA_TARGET=pynq -DVTA_HW_VER=0.0.2 -DVTA_FPGA_DEVICE=xc7z020clg400-2 -DVTA_LOG_INP_WIDTH=3 -DVTA_LOG_WGT_WIDTH=3 -DVTA_LOG_ACC_WIDTH=5 -DVTA_LOG_BATCH=0 -DVTA_LOG_BLOCK=4 -DVTA_LOG_UOP_BUFF_SIZE=15 -DVTA_LOG_INP_BUFF_SIZE=15 -DVTA_LOG_WGT_BUFF_SIZE=18 -DVTA_LOG_ACC_BUFF_SIZE=17 -DVTA_LOG_BLOCK_IN=4 -DVTA_LOG_BLOCK_OUT=4 -DVTA_LOG_OUT_WIDTH=3 -DVTA_LOG_OUT_BUFF_SIZE=15 -DVTA_LOG_BUS_WIDTH=6 -DVTA_IP_REG_MAP_RANGE=0x1000 -DVTA_FETCH_ADDR=0x43C00000 -DVTA_LOAD_ADDR=0x43C01000 -DVTA_COMPUTE_ADDR=0x43C02000 -DVTA_STORE_ADDR=0x43C03000 -DVTA_FETCH_INSN_COUNT_OFFSET=16 -DVTA_FETCH_INSN_ADDR_OFFSET=24 -DVTA_LOAD_INP_ADDR_OFFSET=16 -DVTA_LOAD_WGT_ADDR_OFFSET=24 -DVTA_COMPUTE_DONE_WR_OFFSET=16 -DVTA_COMPUTE_DONE_RD_OFFSET=24 -DVTA_COMPUTE_UOP_ADDR_OFFSET=32 -DVTA_COMPUTE_BIAS_ADDR_OFFSET=40 -DVTA_STORE_OUT_ADDR_OFFSET=16 -DVTA_COHERENT_ACCESSES=true -DVTA_TARGET_PYNQ"
const TARGET pynq
const FPGA_DEVICE xc7z020clg400-2
const FPGA_FAMILY zynq-7000
const FPGA_BOARD None
const FPGA_BOARD_REV None
const FPGA_PERIOD 7
const FPGA_FREQ 100
const INP_MEM_AXI_RATIO 2
const WGT_MEM_AXI_RATIO 16
const OUT_MEM_AXI_RATIO 2
const INP_MEM_BANKS 1
const WGT_MEM_BANKS 2
const OUT_MEM_BANKS 1
const INP_MEM_WIDTH 128
const WGT_MEM_WIDTH 1024
const OUT_MEM_WIDTH 128
const INP_MEM_DEPTH 2048
const WGT_MEM_DEPTH 1024
const OUT_MEM_DEPTH 2048
const NUM_WGT_MEM_URAM 0
const AXI_CACHE_BITS 1111
const AXI_PROT_BITS 000
const IP_REG_MAP_RANGE 0x1000
const FETCH_BASE_ADDR 0x43C00000
const LOAD_BASE_ADDR 0x43C01000
const COMPUTE_BASE_ADDR 0x43C02000
const STORE_BASE_ADDR 0x43C03000