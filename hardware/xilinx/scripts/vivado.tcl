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

# Check if script is running in correct Vivado version.
set scripts_vivado_version 2018.3
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_msg_id "BD_TCL-109" "ERROR" "This script was generated using Vivado \
    <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado."}
   return 1
}

# Parse argument list, derive the clock to utilize
if { [llength $argv] eq 2 } {
  set ip_path     [lindex $argv 0]
  set vta_config  [lindex $argv 1]
} else {
  puts "Arg list incomplete: <path to ip dir> <path to vta_config.py>"
  return 1
}

# Source vta config variables
source $vta_config
source "/home/share/data/workspace/project/fpga/hls/vta-hw/hardware/xilinx/scripts/zc7020.tcl"

# Get the VTA configuration paramters
set target            $TARGET
set device            $FPGA_DEVICE
set device_family     $FPGA_FAMILY
set clock_freq        $FPGA_FREQ
set board             $FPGA_BOARD
set board_rev         $FPGA_BOARD_REV

# SRAM dimensions
set inp_part          $INP_MEM_BANKS
set inp_mem_width     $INP_MEM_WIDTH
set inp_mem_depth     $INP_MEM_DEPTH
set wgt_part          $WGT_MEM_BANKS
set wgt_mem_width     $WGT_MEM_WIDTH
set wgt_mem_depth     $WGT_MEM_DEPTH
set out_part          $OUT_MEM_BANKS
set out_mem_width     $OUT_MEM_WIDTH
set out_mem_depth     $OUT_MEM_DEPTH
set num_wgt_mem_uram  $NUM_WGT_MEM_URAM

# AXI bus signals
set axi_cache         $AXI_CACHE_BITS
set axi_prot          $AXI_PROT_BITS

# Address map
set ip_reg_map_range  $IP_REG_MAP_RANGE
set fetch_base_addr   $FETCH_BASE_ADDR
set load_base_addr    $LOAD_BASE_ADDR
set compute_base_addr $COMPUTE_BASE_ADDR
set store_base_addr   $STORE_BASE_ADDR

# Paths to IP library of VTA modules
set proj_name vta
set design_name $proj_name
set proj_path "."
set ip_lib "ip_lib"
set fetch_ip "${ip_path}/vta_fetch/soln/impl/ip/xilinx_com_hls_fetch_1_0.zip"
set load_ip "${ip_path}/vta_load/soln/impl/ip/xilinx_com_hls_load_1_0.zip"
set compute_ip "${ip_path}/vta_compute/soln/impl/ip/xilinx_com_hls_compute_1_0.zip"
set store_ip "${ip_path}/vta_store/soln/impl/ip/xilinx_com_hls_store_1_0.zip"

# Create custom project
create_project -force $proj_name $proj_path -part $device

# Apply board preset if exists
if {$board != "None" && $board_rev != "None"} {
  set_property board_part $board:$board_rev [current_project]
}

# Update IP repository with generated IP
file mkdir $ip_lib
set_property ip_repo_paths $ip_lib [current_project]
update_ip_catalog
update_ip_catalog -add_ip $fetch_ip -repo_path $ip_lib
update_ip_catalog -add_ip $load_ip -repo_path $ip_lib
update_ip_catalog -add_ip $compute_ip -repo_path $ip_lib
update_ip_catalog -add_ip $store_ip -repo_path $ip_lib


##################################################################
# CONFIGURE BLOCK DIAGRAM DESIGN
##################################################################

# Create bd design
create_bd_design $design_name
current_bd_design $design_name

# Procedure to initialize FIFO
proc init_fifo_property {fifo width_bytes depth} {
  set_property -dict [ list \
    CONFIG.FIFO_Implementation_rach {Common_Clock_Distributed_RAM} \
    CONFIG.FIFO_Implementation_wach {Common_Clock_Distributed_RAM} \
    CONFIG.FIFO_Implementation_wrch {Common_Clock_Distributed_RAM} \
    CONFIG.Full_Flags_Reset_Value {1} \
    CONFIG.INTERFACE_TYPE {AXI_STREAM} \
    CONFIG.Input_Depth_axis $depth \
    CONFIG.Reset_Type {Asynchronous_Reset} \
    CONFIG.TDATA_NUM_BYTES $width_bytes \
  ] $fifo
}

# Procedure to initialize BRAM
proc init_bram_property {bram width depth} {
  set_property -dict [ list \
    CONFIG.use_bram_block {Stand_Alone} \
    CONFIG.Assume_Synchronous_Clk {true} \
    CONFIG.Byte_Size {8} \
    CONFIG.Enable_32bit_Address {true} \
    CONFIG.Enable_B {Use_ENB_Pin} \
    CONFIG.Memory_Type {True_Dual_Port_RAM} \
    CONFIG.Read_Width_A $width \
    CONFIG.Read_Width_B $width \
    CONFIG.Register_PortA_Output_of_Memory_Primitives {false} \
    CONFIG.Register_PortB_Output_of_Memory_Primitives {false} \
    CONFIG.Use_Byte_Write_Enable {true} \
    CONFIG.Use_RSTA_Pin {true} \
    CONFIG.Use_RSTB_Pin {true} \
    CONFIG.Write_Depth_A $depth \
    CONFIG.Write_Width_A $width \
    CONFIG.Write_Width_B $width \
  ] $bram
}

# Create instance: proc_sys_reset, and set properties
set proc_sys_reset \
  [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset ]

# Create instance: pll_clk, and set properties
set pll_clk [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 pll_clk ]
set_property -dict [ list \
  CONFIG.CLKOUT1_REQUESTED_OUT_FREQ $clock_freq \
  CONFIG.RESET_PORT {resetn} \
  CONFIG.RESET_TYPE {ACTIVE_LOW} \
  CONFIG.USE_LOCKED {false} \
] $pll_clk

# Create instance: axi_smc0, and set properties
set axi_smc0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc0 ]
set_property -dict [ list \
  CONFIG.NUM_MI {1} \
  CONFIG.NUM_SI {5} \
] $axi_smc0

# Create instance: axi_xbar, and set properties
set axi_xbar \
  [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_xbar ]
set_property -dict [ list \
  CONFIG.NUM_MI {4} \
  CONFIG.NUM_SI {1} \
] $axi_xbar

# Create instance: fetch_0, and set properties
set fetch_0 [ create_bd_cell -type ip -vlnv xilinx.com:hls:fetch:1.0 fetch_0 ]
set_property -dict [ list \
  CONFIG.C_M_AXI_INS_PORT_CACHE_VALUE $axi_cache \
  CONFIG.C_M_AXI_INS_PORT_PROT_VALUE $axi_prot \
] $fetch_0

# Create instance: load_0, and set properties
set load_0 [ create_bd_cell -type ip -vlnv xilinx.com:hls:load:1.0 load_0 ]
set_property -dict [ list \
  CONFIG.C_M_AXI_DATA_PORT_CACHE_VALUE $axi_cache \
  CONFIG.C_M_AXI_DATA_PORT_PROT_VALUE $axi_prot \
] $load_0

# Create instance: compute_0, and set properties
set compute_0 [ create_bd_cell -type ip -vlnv xilinx.com:hls:compute:1.0 compute_0 ]
set_property -dict [ list \
  CONFIG.C_M_AXI_DATA_PORT_CACHE_VALUE $axi_cache \
  CONFIG.C_M_AXI_DATA_PORT_PROT_VALUE $axi_prot \
  CONFIG.C_M_AXI_UOP_PORT_CACHE_VALUE $axi_cache \
  CONFIG.C_M_AXI_UOP_PORT_PROT_VALUE $axi_prot \
] $compute_0

# Create instance: store_0, and set properties
set store_0 [ create_bd_cell -type ip -vlnv xilinx.com:hls:store:1.0 store_0 ]
set_property -dict [ list \
  CONFIG.C_M_AXI_DATA_PORT_CACHE_VALUE $axi_cache \
  CONFIG.C_M_AXI_DATA_PORT_PROT_VALUE $axi_prot \
] $store_0

# Create command queues and set properties
set cmd_queue_list {load_queue gemm_queue store_queue}
foreach cmd_queue $cmd_queue_list {
  set tmp_cmd_queue [ create_bd_cell -type ip -vlnv xilinx.com:ip:fifo_generator:13.2 $cmd_queue ]
  # Width is 16B (128b, as set in hw_spec.h), depth is 512 (depth of FIFO on Zynq 7000 and Zynq Ultrascale+)
  # TODO: derive it from vta_config.h
  [ init_fifo_property $tmp_cmd_queue 16 512 ]
}

# Create dependence queues and set properties
set dep_queue_list {l2g_queue g2l_queue g2s_queue s2g_queue}
foreach dep_queue $dep_queue_list {
  set tmp_dep_queue [ create_bd_cell -type ip -vlnv xilinx.com:ip:fifo_generator:13.2 $dep_queue ]
  # Width is 1B (min width), depth is 1024
  # TODO: derive it from vta_config.h
  [ init_fifo_property $tmp_dep_queue 1 1024 ]
}

# Create and connect inp_mem partitions
for {set i 0} {$i < $inp_part} {incr i} {
  # Create instance: inp_mem, and set properties
  set inp_mem [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 inp_mem_${i} ]
  [ init_bram_property $inp_mem $inp_mem_width $inp_mem_depth ]
  # If module has more than 1 mem port, the naming convention changes
  if {$inp_part > 1} {
    set porta [get_bd_intf_pins load_0/inp_mem_${i}_V_PORTA]
    set portb [get_bd_intf_pins compute_0/inp_mem_${i}_V_PORTA]
  } else {
    set porta [get_bd_intf_pins load_0/inp_mem_V_PORTA]
    set portb [get_bd_intf_pins compute_0/inp_mem_V_PORTA]
  }
  # Create interface connections
  connect_bd_intf_net -intf_net load_0_inp_mem_V_PORTA \
    [get_bd_intf_pins $inp_mem/BRAM_PORTA] \
    $porta
  connect_bd_intf_net -intf_net compute_0_inp_mem_V_PORTA \
    [get_bd_intf_pins $inp_mem/BRAM_PORTB] \
    $portb
}

# Create and connect wgt_mem partitions
for {set i 0} {$i < $wgt_part} {incr i} {
  # Create instance: wgt_mem, and set properties
  set wgt_mem [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 wgt_mem_${i} ]
  [ init_bram_property $wgt_mem $wgt_mem_width $wgt_mem_depth ]
  # If module has more than 1 mem port, the naming convention changes
  if {$wgt_part > 1} {
    set porta [get_bd_intf_pins load_0/wgt_mem_${i}_V_PORTA]
    set portb [get_bd_intf_pins compute_0/wgt_mem_${i}_V_PORTA]
  } else {
    set porta [get_bd_intf_pins load_0/wgt_mem_V_PORTA]
    set portb [get_bd_intf_pins compute_0/wgt_mem_V_PORTA]
  }
  # Create interface connections
  connect_bd_intf_net -intf_net load_0_wgt_mem_${i}_V_PORTA \
    [get_bd_intf_pins $wgt_mem/BRAM_PORTA] \
    $porta
  connect_bd_intf_net -intf_net compute_0_wgt_mem_${i}_V_PORTA \
    [get_bd_intf_pins $wgt_mem/BRAM_PORTB] \
    $portb
  if { $device_family eq "zynq-ultrascale+" && $i < $num_wgt_mem_uram } {
    set_property -dict [list CONFIG.PRIM_type_to_Implement {URAM}] $wgt_mem
  }
}

# Create and connect out_mem partitions
for {set i 0} {$i < $out_part} {incr i} {
  # Create instance: out_mem, and set properties
  set out_mem [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 out_mem_${i} ]
  [ init_bram_property $out_mem $out_mem_width $out_mem_depth ]
  # If module has more than 1 mem port, the naming convention changes
  if {$out_part > 1} {
    set porta [get_bd_intf_pins compute_0/out_mem_${i}_V_PORTA]
    set portb [get_bd_intf_pins store_0/out_mem_${i}_V_PORTA]
  } else {
    set porta [get_bd_intf_pins compute_0/out_mem_V_PORTA]
    set portb [get_bd_intf_pins store_0/out_mem_V_PORTA]
  }
  # Create interface connections
  connect_bd_intf_net -intf_net compute_0_out_mem_${i}_V_PORTA \
    [get_bd_intf_pins $out_mem/BRAM_PORTA] \
    $porta
  connect_bd_intf_net -intf_net store_0_out_mem_${i}_V_PORTA \
    [get_bd_intf_pins $out_mem/BRAM_PORTB] \
    $portb
}

# Create instance: processing_system, and set properties
if { $device_family eq "zynq-7000" } {
  set processing_system [ create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system ]
  set_property -dict [ list \
    CONFIG.PCW_DDR_RAM_BASEADDR {0x00100000}  \
        CONFIG.PCW_DDR_RAM_HIGHADDR {0x3FFFFFFF}  \
        CONFIG.PCW_UART0_BASEADDR {0xE0000000}  \
        CONFIG.PCW_UART0_HIGHADDR {0xE0000FFF}  \
        CONFIG.PCW_UART1_BASEADDR {0xE0001000}  \
        CONFIG.PCW_UART1_HIGHADDR {0xE0001FFF}  \
        CONFIG.PCW_I2C0_BASEADDR {0xE0004000}  \
        CONFIG.PCW_I2C0_HIGHADDR {0xE0004FFF}  \
        CONFIG.PCW_I2C1_BASEADDR {0xE0005000}  \
        CONFIG.PCW_I2C1_HIGHADDR {0xE0005FFF}  \
        CONFIG.PCW_SPI0_BASEADDR {0xE0006000}  \
        CONFIG.PCW_SPI0_HIGHADDR {0xE0006FFF}  \
        CONFIG.PCW_SPI1_BASEADDR {0xE0007000}  \
        CONFIG.PCW_SPI1_HIGHADDR {0xE0007FFF}  \
        CONFIG.PCW_CAN0_BASEADDR {0xE0008000}  \
        CONFIG.PCW_CAN0_HIGHADDR {0xE0008FFF}  \
        CONFIG.PCW_CAN1_BASEADDR {0xE0009000}  \
        CONFIG.PCW_CAN1_HIGHADDR {0xE0009FFF}  \
        CONFIG.PCW_GPIO_BASEADDR {0xE000A000}  \
        CONFIG.PCW_GPIO_HIGHADDR {0xE000AFFF}  \
        CONFIG.PCW_ENET0_BASEADDR {0xE000B000}  \
        CONFIG.PCW_ENET0_HIGHADDR {0xE000BFFF}  \
        CONFIG.PCW_ENET1_BASEADDR {0xE000C000}  \
        CONFIG.PCW_ENET1_HIGHADDR {0xE000CFFF}  \
        CONFIG.PCW_SDIO0_BASEADDR {0xE0100000}  \
        CONFIG.PCW_SDIO0_HIGHADDR {0xE0100FFF}  \
        CONFIG.PCW_SDIO1_BASEADDR {0xE0101000}  \
        CONFIG.PCW_SDIO1_HIGHADDR {0xE0101FFF}  \
        CONFIG.PCW_USB0_BASEADDR {0xE0102000}  \
        CONFIG.PCW_USB0_HIGHADDR {0xE0102fff}  \
        CONFIG.PCW_USB1_BASEADDR {0xE0103000}  \
        CONFIG.PCW_USB1_HIGHADDR {0xE0103fff}  \
        CONFIG.PCW_TTC0_BASEADDR {0xE0104000}  \
        CONFIG.PCW_TTC0_HIGHADDR {0xE0104fff}  \
        CONFIG.PCW_TTC1_BASEADDR {0xE0105000}  \
        CONFIG.PCW_TTC1_HIGHADDR {0xE0105fff}  \
        CONFIG.PCW_FCLK_CLK0_BUF {TRUE}  \
        CONFIG.PCW_FCLK_CLK1_BUF {TRUE}  \
        CONFIG.PCW_FCLK_CLK2_BUF {FALSE}  \
        CONFIG.PCW_FCLK_CLK3_BUF {FALSE}  \
        CONFIG.PCW_UIPARAM_DDR_FREQ_MHZ {533.333333}  \
        CONFIG.PCW_UIPARAM_DDR_BANK_ADDR_COUNT {3}  \
        CONFIG.PCW_UIPARAM_DDR_ROW_ADDR_COUNT {15}  \
        CONFIG.PCW_UIPARAM_DDR_COL_ADDR_COUNT {10}  \
        CONFIG.PCW_UIPARAM_DDR_CL {7}  \
        CONFIG.PCW_UIPARAM_DDR_CWL {6}  \
        CONFIG.PCW_UIPARAM_DDR_T_RCD {7}  \
        CONFIG.PCW_UIPARAM_DDR_T_RP {7}  \
        CONFIG.PCW_UIPARAM_DDR_T_RC {48.91}  \
        CONFIG.PCW_UIPARAM_DDR_T_RAS_MIN {35.0}  \
        CONFIG.PCW_UIPARAM_DDR_T_FAW {40.0}  \
        CONFIG.PCW_UIPARAM_DDR_AL {0}  \
        CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_0 {0.0}  \
        CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_1 {0.0}  \
        CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_2 {0.0}  \
        CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_3 {0.0}  \
        CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY0 {0.25}  \
        CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY1 {0.25}  \
        CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY2 {0.25}  \
        CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY3 {0.25}  \
        CONFIG.PCW_UIPARAM_DDR_DQS_0_LENGTH_MM {0}  \
        CONFIG.PCW_UIPARAM_DDR_DQS_1_LENGTH_MM {0}  \
        CONFIG.PCW_UIPARAM_DDR_DQS_2_LENGTH_MM {0}  \
        CONFIG.PCW_UIPARAM_DDR_DQS_3_LENGTH_MM {0}  \
        CONFIG.PCW_UIPARAM_DDR_DQ_0_LENGTH_MM {0}  \
        CONFIG.PCW_UIPARAM_DDR_DQ_1_LENGTH_MM {0}  \
        CONFIG.PCW_UIPARAM_DDR_DQ_2_LENGTH_MM {0}  \
        CONFIG.PCW_UIPARAM_DDR_DQ_3_LENGTH_MM {0}  \
        CONFIG.PCW_UIPARAM_DDR_CLOCK_0_LENGTH_MM {0}  \
        CONFIG.PCW_UIPARAM_DDR_CLOCK_1_LENGTH_MM {0}  \
        CONFIG.PCW_UIPARAM_DDR_CLOCK_2_LENGTH_MM {0}  \
        CONFIG.PCW_UIPARAM_DDR_CLOCK_3_LENGTH_MM {0}  \
        CONFIG.PCW_UIPARAM_DDR_DQS_0_PACKAGE_LENGTH {105.056}  \
        CONFIG.PCW_UIPARAM_DDR_DQS_1_PACKAGE_LENGTH {66.904}  \
        CONFIG.PCW_UIPARAM_DDR_DQS_2_PACKAGE_LENGTH {89.1715}  \
        CONFIG.PCW_UIPARAM_DDR_DQS_3_PACKAGE_LENGTH {113.63}  \
        CONFIG.PCW_UIPARAM_DDR_DQ_0_PACKAGE_LENGTH {98.503}  \
        CONFIG.PCW_UIPARAM_DDR_DQ_1_PACKAGE_LENGTH {68.5855}  \
        CONFIG.PCW_UIPARAM_DDR_DQ_2_PACKAGE_LENGTH {90.295}  \
        CONFIG.PCW_UIPARAM_DDR_DQ_3_PACKAGE_LENGTH {103.977}  \
        CONFIG.PCW_UIPARAM_DDR_CLOCK_0_PACKAGE_LENGTH {80.4535}  \
        CONFIG.PCW_UIPARAM_DDR_CLOCK_1_PACKAGE_LENGTH {80.4535}  \
        CONFIG.PCW_UIPARAM_DDR_CLOCK_2_PACKAGE_LENGTH {80.4535}  \
        CONFIG.PCW_UIPARAM_DDR_CLOCK_3_PACKAGE_LENGTH {80.4535}  \
        CONFIG.PCW_UIPARAM_DDR_DQS_0_PROPOGATION_DELAY {160}  \
        CONFIG.PCW_UIPARAM_DDR_DQS_1_PROPOGATION_DELAY {160}  \
        CONFIG.PCW_UIPARAM_DDR_DQS_2_PROPOGATION_DELAY {160}  \
        CONFIG.PCW_UIPARAM_DDR_DQS_3_PROPOGATION_DELAY {160}  \
        CONFIG.PCW_UIPARAM_DDR_DQ_0_PROPOGATION_DELAY {160}  \
        CONFIG.PCW_UIPARAM_DDR_DQ_1_PROPOGATION_DELAY {160}  \
        CONFIG.PCW_UIPARAM_DDR_DQ_2_PROPOGATION_DELAY {160}  \
        CONFIG.PCW_UIPARAM_DDR_DQ_3_PROPOGATION_DELAY {160}  \
        CONFIG.PCW_UIPARAM_DDR_CLOCK_0_PROPOGATION_DELAY {160}  \
        CONFIG.PCW_UIPARAM_DDR_CLOCK_1_PROPOGATION_DELAY {160}  \
        CONFIG.PCW_UIPARAM_DDR_CLOCK_2_PROPOGATION_DELAY {160}  \
        CONFIG.PCW_UIPARAM_DDR_CLOCK_3_PROPOGATION_DELAY {160}  \
        CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_0 {-0.025}  \
        CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_1 {0.014}  \
        CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_2 {-0.009}  \
        CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_3 {-0.033}  \
        CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY0 {0.089}  \
        CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY1 {0.075}  \
        CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY2 {0.085}  \
        CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY3 {0.092}  \
        CONFIG.PCW_CPU_CPU_6X4X_MAX_RANGE {767}  \
        CONFIG.PCW_CRYSTAL_PERIPHERAL_FREQMHZ {33.333333}  \
        CONFIG.PCW_APU_PERIPHERAL_FREQMHZ {767}  \
        CONFIG.PCW_DCI_PERIPHERAL_FREQMHZ {10.159}  \
        CONFIG.PCW_QSPI_PERIPHERAL_FREQMHZ {200}  \
        CONFIG.PCW_SMC_PERIPHERAL_FREQMHZ {100}  \
        CONFIG.PCW_USB0_PERIPHERAL_FREQMHZ {60}  \
        CONFIG.PCW_USB1_PERIPHERAL_FREQMHZ {60}  \
        CONFIG.PCW_SDIO_PERIPHERAL_FREQMHZ {100}  \
        CONFIG.PCW_UART_PERIPHERAL_FREQMHZ {100}  \
        CONFIG.PCW_SPI_PERIPHERAL_FREQMHZ {166.666666}  \
        CONFIG.PCW_CAN_PERIPHERAL_FREQMHZ {100}  \
        CONFIG.PCW_CAN0_PERIPHERAL_FREQMHZ {-1}  \
        CONFIG.PCW_CAN1_PERIPHERAL_FREQMHZ {-1}  \
        CONFIG.PCW_I2C_PERIPHERAL_FREQMHZ {127.777779}  \
        CONFIG.PCW_WDT_PERIPHERAL_FREQMHZ {133.333333}  \
        CONFIG.PCW_TTC_PERIPHERAL_FREQMHZ {50}  \
        CONFIG.PCW_TTC0_CLK0_PERIPHERAL_FREQMHZ {133.333333}  \
        CONFIG.PCW_TTC0_CLK1_PERIPHERAL_FREQMHZ {133.333333}  \
        CONFIG.PCW_TTC0_CLK2_PERIPHERAL_FREQMHZ {133.333333}  \
        CONFIG.PCW_TTC1_CLK0_PERIPHERAL_FREQMHZ {133.333333}  \
        CONFIG.PCW_TTC1_CLK1_PERIPHERAL_FREQMHZ {133.333333}  \
        CONFIG.PCW_TTC1_CLK2_PERIPHERAL_FREQMHZ {133.333333}  \
        CONFIG.PCW_PCAP_PERIPHERAL_FREQMHZ {200}  \
        CONFIG.PCW_TPIU_PERIPHERAL_FREQMHZ {200}  \
        CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100}  \
        CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {150}  \
        CONFIG.PCW_FPGA2_PERIPHERAL_FREQMHZ {12}  \
        CONFIG.PCW_FPGA3_PERIPHERAL_FREQMHZ {200}  \
        CONFIG.PCW_ACT_APU_PERIPHERAL_FREQMHZ {766.666687}  \
        CONFIG.PCW_UIPARAM_ACT_DDR_FREQ_MHZ {533.333374}  \
        CONFIG.PCW_ACT_DCI_PERIPHERAL_FREQMHZ {10.158730}  \
        CONFIG.PCW_ACT_QSPI_PERIPHERAL_FREQMHZ {200.000000}  \
        CONFIG.PCW_ACT_SMC_PERIPHERAL_FREQMHZ {10.000000}  \
        CONFIG.PCW_ACT_ENET0_PERIPHERAL_FREQMHZ {125.000000}  \
        CONFIG.PCW_ACT_ENET1_PERIPHERAL_FREQMHZ {125.000000}  \
        CONFIG.PCW_ACT_USB0_PERIPHERAL_FREQMHZ {60}  \
        CONFIG.PCW_ACT_USB1_PERIPHERAL_FREQMHZ {60}  \
        CONFIG.PCW_ACT_SDIO_PERIPHERAL_FREQMHZ {100.000000}  \
        CONFIG.PCW_ACT_UART_PERIPHERAL_FREQMHZ {100.000000}  \
        CONFIG.PCW_ACT_SPI_PERIPHERAL_FREQMHZ {10.000000}  \
        CONFIG.PCW_ACT_CAN_PERIPHERAL_FREQMHZ {10.000000}  \
        CONFIG.PCW_ACT_CAN0_PERIPHERAL_FREQMHZ {23.8095}  \
        CONFIG.PCW_ACT_CAN1_PERIPHERAL_FREQMHZ {23.8095}  \
        CONFIG.PCW_ACT_I2C_PERIPHERAL_FREQMHZ {50}  \
        CONFIG.PCW_ACT_WDT_PERIPHERAL_FREQMHZ {127.777786}  \
        CONFIG.PCW_ACT_TTC_PERIPHERAL_FREQMHZ {50}  \
        CONFIG.PCW_ACT_PCAP_PERIPHERAL_FREQMHZ {200.000000}  \
        CONFIG.PCW_ACT_TPIU_PERIPHERAL_FREQMHZ {200.000000}  \
        CONFIG.PCW_ACT_FPGA0_PERIPHERAL_FREQMHZ {100.000000}  \
        CONFIG.PCW_ACT_FPGA1_PERIPHERAL_FREQMHZ {142.857132}  \
        CONFIG.PCW_ACT_FPGA2_PERIPHERAL_FREQMHZ {10.000000}  \
        CONFIG.PCW_ACT_FPGA3_PERIPHERAL_FREQMHZ {10.000000}  \
        CONFIG.PCW_ACT_TTC0_CLK0_PERIPHERAL_FREQMHZ {127.777786}  \
        CONFIG.PCW_ACT_TTC0_CLK1_PERIPHERAL_FREQMHZ {127.777786}  \
        CONFIG.PCW_ACT_TTC0_CLK2_PERIPHERAL_FREQMHZ {127.777786}  \
        CONFIG.PCW_ACT_TTC1_CLK0_PERIPHERAL_FREQMHZ {127.777786}  \
        CONFIG.PCW_ACT_TTC1_CLK1_PERIPHERAL_FREQMHZ {127.777786}  \
        CONFIG.PCW_ACT_TTC1_CLK2_PERIPHERAL_FREQMHZ {127.777786}  \
        CONFIG.PCW_CLK0_FREQ {100000000}  \
        CONFIG.PCW_CLK1_FREQ {142857132}  \
        CONFIG.PCW_CLK2_FREQ {10000000}  \
        CONFIG.PCW_CLK3_FREQ {10000000}  \
        CONFIG.PCW_OVERRIDE_BASIC_CLOCK {0}  \
        CONFIG.PCW_CPU_PERIPHERAL_DIVISOR0 {2}  \
        CONFIG.PCW_DDR_PERIPHERAL_DIVISOR0 {2}  \
        CONFIG.PCW_SMC_PERIPHERAL_DIVISOR0 {1}  \
        CONFIG.PCW_QSPI_PERIPHERAL_DIVISOR0 {5}  \
        CONFIG.PCW_SDIO_PERIPHERAL_DIVISOR0 {10}  \
        CONFIG.PCW_UART_PERIPHERAL_DIVISOR0 {10}  \
        CONFIG.PCW_SPI_PERIPHERAL_DIVISOR0 {1}  \
        CONFIG.PCW_CAN_PERIPHERAL_DIVISOR0 {1}  \
        CONFIG.PCW_CAN_PERIPHERAL_DIVISOR1 {1}  \
        CONFIG.PCW_FCLK0_PERIPHERAL_DIVISOR0 {5}  \
        CONFIG.PCW_FCLK1_PERIPHERAL_DIVISOR0 {7}  \
        CONFIG.PCW_FCLK2_PERIPHERAL_DIVISOR0 {1}  \
        CONFIG.PCW_FCLK3_PERIPHERAL_DIVISOR0 {1}  \
        CONFIG.PCW_FCLK0_PERIPHERAL_DIVISOR1 {2}  \
        CONFIG.PCW_FCLK1_PERIPHERAL_DIVISOR1 {1}  \
        CONFIG.PCW_FCLK2_PERIPHERAL_DIVISOR1 {1}  \
        CONFIG.PCW_FCLK3_PERIPHERAL_DIVISOR1 {1}  \
        CONFIG.PCW_ENET0_PERIPHERAL_DIVISOR0 {8}  \
        CONFIG.PCW_ENET1_PERIPHERAL_DIVISOR0 {1}  \
        CONFIG.PCW_ENET0_PERIPHERAL_DIVISOR1 {1}  \
        CONFIG.PCW_ENET1_PERIPHERAL_DIVISOR1 {1}  \
        CONFIG.PCW_TPIU_PERIPHERAL_DIVISOR0 {1}  \
        CONFIG.PCW_DCI_PERIPHERAL_DIVISOR0 {15}  \
        CONFIG.PCW_DCI_PERIPHERAL_DIVISOR1 {7}  \
        CONFIG.PCW_PCAP_PERIPHERAL_DIVISOR0 {5}  \
        CONFIG.PCW_TTC0_CLK0_PERIPHERAL_DIVISOR0 {1}  \
        CONFIG.PCW_TTC0_CLK1_PERIPHERAL_DIVISOR0 {1}  \
        CONFIG.PCW_TTC0_CLK2_PERIPHERAL_DIVISOR0 {1}  \
        CONFIG.PCW_TTC1_CLK0_PERIPHERAL_DIVISOR0 {1}  \
        CONFIG.PCW_TTC1_CLK1_PERIPHERAL_DIVISOR0 {1}  \
        CONFIG.PCW_TTC1_CLK2_PERIPHERAL_DIVISOR0 {1}  \
        CONFIG.PCW_WDT_PERIPHERAL_DIVISOR0 {1}  \
        CONFIG.PCW_ARMPLL_CTRL_FBDIV {46}  \
        CONFIG.PCW_IOPLL_CTRL_FBDIV {30}  \
        CONFIG.PCW_DDRPLL_CTRL_FBDIV {32}  \
        CONFIG.PCW_CPU_CPU_PLL_FREQMHZ {1533.333}  \
        CONFIG.PCW_IO_IO_PLL_FREQMHZ {1000.000}  \
        CONFIG.PCW_DDR_DDR_PLL_FREQMHZ {1066.667}  \
        CONFIG.PCW_SMC_PERIPHERAL_VALID {0}  \
        CONFIG.PCW_SDIO_PERIPHERAL_VALID {1}  \
        CONFIG.PCW_SPI_PERIPHERAL_VALID {0}  \
        CONFIG.PCW_CAN_PERIPHERAL_VALID {0}  \
        CONFIG.PCW_UART_PERIPHERAL_VALID {1}  \
        CONFIG.PCW_EN_EMIO_CAN0 {0}  \
        CONFIG.PCW_EN_EMIO_CAN1 {0}  \
        CONFIG.PCW_EN_EMIO_ENET0 {0}  \
        CONFIG.PCW_EN_EMIO_ENET1 {0}  \
        CONFIG.PCW_EN_PTP_ENET0 {0}  \
        CONFIG.PCW_EN_PTP_ENET1 {0}  \
        CONFIG.PCW_EN_EMIO_GPIO {0}  \
        CONFIG.PCW_EN_EMIO_I2C0 {1}  \
        CONFIG.PCW_EN_EMIO_I2C1 {1}  \
        CONFIG.PCW_EN_EMIO_PJTAG {0}  \
        CONFIG.PCW_EN_EMIO_SDIO0 {0}  \
        CONFIG.PCW_EN_EMIO_CD_SDIO0 {0}  \
        CONFIG.PCW_EN_EMIO_WP_SDIO0 {0}  \
        CONFIG.PCW_EN_EMIO_SDIO1 {0}  \
        CONFIG.PCW_EN_EMIO_CD_SDIO1 {0}  \
        CONFIG.PCW_EN_EMIO_WP_SDIO1 {0}  \
        CONFIG.PCW_EN_EMIO_SPI0 {0}  \
        CONFIG.PCW_EN_EMIO_SPI1 {0}  \
        CONFIG.PCW_EN_EMIO_UART0 {0}  \
        CONFIG.PCW_EN_EMIO_UART1 {0}  \
        CONFIG.PCW_EN_EMIO_MODEM_UART0 {0}  \
        CONFIG.PCW_EN_EMIO_MODEM_UART1 {0}  \
        CONFIG.PCW_EN_EMIO_TTC0 {0}  \
        CONFIG.PCW_EN_EMIO_TTC1 {0}  \
        CONFIG.PCW_EN_EMIO_WDT {0}  \
        CONFIG.PCW_EN_EMIO_TRACE {0}  \
        CONFIG.PCW_USE_AXI_NONSECURE {0}  \
        CONFIG.PCW_USE_M_AXI_GP0 {1}  \
        CONFIG.PCW_USE_M_AXI_GP1 {0}  \
        CONFIG.PCW_USE_S_AXI_GP0 {0}  \
        CONFIG.PCW_USE_S_AXI_GP1 {0}  \
        CONFIG.PCW_USE_S_AXI_ACP {0}  \
        CONFIG.PCW_USE_S_AXI_HP0 {0}  \
        CONFIG.PCW_USE_S_AXI_HP1 {0}  \
        CONFIG.PCW_USE_S_AXI_HP2 {0}  \
        CONFIG.PCW_USE_S_AXI_HP3 {0}  \
        CONFIG.PCW_USE_DMA0 {0}  \
        CONFIG.PCW_USE_DMA1 {0}  \
        CONFIG.PCW_USE_DMA2 {0}  \
        CONFIG.PCW_USE_DMA3 {0}  \
        CONFIG.PCW_USE_TRACE {0}  \
        CONFIG.PCW_TRACE_PIPELINE_WIDTH {8}  \
        CONFIG.PCW_INCLUDE_TRACE_BUFFER {0}  \
        CONFIG.PCW_TRACE_BUFFER_FIFO_SIZE {128}  \
        CONFIG.PCW_USE_TRACE_DATA_EDGE_DETECTOR {0}  \
        CONFIG.PCW_TRACE_BUFFER_CLOCK_DELAY {12}  \
        CONFIG.PCW_USE_CROSS_TRIGGER {0}  \
        CONFIG.PCW_FTM_CTI_IN0 {<Select>}  \
        CONFIG.PCW_FTM_CTI_IN1 {<Select>}  \
        CONFIG.PCW_FTM_CTI_IN2 {<Select>}  \
        CONFIG.PCW_FTM_CTI_IN3 {<Select>}  \
        CONFIG.PCW_FTM_CTI_OUT0 {<Select>}  \
        CONFIG.PCW_FTM_CTI_OUT1 {<Select>}  \
        CONFIG.PCW_FTM_CTI_OUT2 {<Select>}  \
        CONFIG.PCW_FTM_CTI_OUT3 {<Select>}  \
        CONFIG.PCW_USE_DEBUG {0}  \
        CONFIG.PCW_USE_CR_FABRIC {1}  \
        CONFIG.PCW_USE_AXI_FABRIC_IDLE {0}  \
        CONFIG.PCW_USE_DDR_BYPASS {0}  \
        CONFIG.PCW_USE_FABRIC_INTERRUPT {1}  \
        CONFIG.PCW_USE_PROC_EVENT_BUS {0}  \
        CONFIG.PCW_USE_EXPANDED_IOP {0}  \
        CONFIG.PCW_USE_HIGH_OCM {0}  \
        CONFIG.PCW_USE_PS_SLCR_REGISTERS {0}  \
        CONFIG.PCW_USE_EXPANDED_PS_SLCR_REGISTERS {0}  \
        CONFIG.PCW_USE_CORESIGHT {0}  \
        CONFIG.PCW_EN_EMIO_SRAM_INT {0}  \
        CONFIG.PCW_GPIO_EMIO_GPIO_WIDTH {64}  \
        CONFIG.PCW_GP0_NUM_WRITE_THREADS {4}  \
        CONFIG.PCW_GP0_NUM_READ_THREADS {4}  \
        CONFIG.PCW_GP1_NUM_WRITE_THREADS {4}  \
        CONFIG.PCW_GP1_NUM_READ_THREADS {4}  \
        CONFIG.PCW_UART0_BAUD_RATE {115200}  \
        CONFIG.PCW_UART1_BAUD_RATE {115200}  \
        CONFIG.PCW_EN_4K_TIMER {0}  \
        CONFIG.PCW_M_AXI_GP0_ID_WIDTH {12}  \
        CONFIG.PCW_M_AXI_GP0_ENABLE_STATIC_REMAP {0}  \
        CONFIG.PCW_M_AXI_GP0_SUPPORT_NARROW_BURST {0}  \
        CONFIG.PCW_M_AXI_GP0_THREAD_ID_WIDTH {12}  \
        CONFIG.PCW_M_AXI_GP1_ID_WIDTH {12}  \
        CONFIG.PCW_M_AXI_GP1_ENABLE_STATIC_REMAP {0}  \
        CONFIG.PCW_M_AXI_GP1_SUPPORT_NARROW_BURST {0}  \
        CONFIG.PCW_M_AXI_GP1_THREAD_ID_WIDTH {12}  \
        CONFIG.PCW_S_AXI_GP0_ID_WIDTH {6}  \
        CONFIG.PCW_S_AXI_GP1_ID_WIDTH {6}  \
        CONFIG.PCW_S_AXI_ACP_ID_WIDTH {3}  \
        CONFIG.PCW_INCLUDE_ACP_TRANS_CHECK {0}  \
        CONFIG.PCW_USE_DEFAULT_ACP_USER_VAL {0}  \
        CONFIG.PCW_S_AXI_ACP_ARUSER_VAL {31}  \
        CONFIG.PCW_S_AXI_ACP_AWUSER_VAL {31}  \
        CONFIG.PCW_S_AXI_HP0_ID_WIDTH {6}  \
        CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {64}  \
        CONFIG.PCW_S_AXI_HP1_ID_WIDTH {6}  \
        CONFIG.PCW_S_AXI_HP1_DATA_WIDTH {64}  \
        CONFIG.PCW_S_AXI_HP2_ID_WIDTH {6}  \
        CONFIG.PCW_S_AXI_HP2_DATA_WIDTH {64}  \
        CONFIG.PCW_S_AXI_HP3_ID_WIDTH {6}  \
        CONFIG.PCW_S_AXI_HP3_DATA_WIDTH {64}  \
        CONFIG.PCW_EN_DDR {1}  \
        CONFIG.PCW_EN_SMC {0}  \
        CONFIG.PCW_EN_QSPI {1}  \
        CONFIG.PCW_EN_CAN0 {0}  \
        CONFIG.PCW_EN_CAN1 {0}  \
        CONFIG.PCW_EN_ENET0 {1}  \
        CONFIG.PCW_EN_ENET1 {0}  \
        CONFIG.PCW_EN_GPIO {1}  \
        CONFIG.PCW_EN_I2C0 {1}  \
        CONFIG.PCW_EN_I2C1 {1}  \
        CONFIG.PCW_EN_PJTAG {0}  \
        CONFIG.PCW_EN_SDIO0 {1}  \
        CONFIG.PCW_EN_SDIO1 {1}  \
        CONFIG.PCW_EN_SPI0 {0}  \
        CONFIG.PCW_EN_SPI1 {0}  \
        CONFIG.PCW_EN_UART0 {1}  \
        CONFIG.PCW_EN_UART1 {0}  \
        CONFIG.PCW_EN_MODEM_UART0 {0}  \
        CONFIG.PCW_EN_MODEM_UART1 {0}  \
        CONFIG.PCW_EN_TTC0 {0}  \
        CONFIG.PCW_EN_TTC1 {0}  \
        CONFIG.PCW_EN_WDT {0}  \
        CONFIG.PCW_EN_TRACE {0}  \
        CONFIG.PCW_EN_USB0 {1}  \
        CONFIG.PCW_EN_USB1 {0}  \
        CONFIG.PCW_DQ_WIDTH {32}  \
        CONFIG.PCW_DQS_WIDTH {4}  \
        CONFIG.PCW_DM_WIDTH {4}  \
        CONFIG.PCW_MIO_PRIMITIVE {54}  \
        CONFIG.PCW_EN_CLK0_PORT {1}  \
        CONFIG.PCW_EN_CLK1_PORT {1}  \
        CONFIG.PCW_EN_CLK2_PORT {0}  \
        CONFIG.PCW_EN_CLK3_PORT {0}  \
        CONFIG.PCW_EN_RST0_PORT {1}  \
        CONFIG.PCW_EN_RST1_PORT {0}  \
        CONFIG.PCW_EN_RST2_PORT {0}  \
        CONFIG.PCW_EN_RST3_PORT {0}  \
        CONFIG.PCW_EN_CLKTRIG0_PORT {0}  \
        CONFIG.PCW_EN_CLKTRIG1_PORT {0}  \
        CONFIG.PCW_EN_CLKTRIG2_PORT {0}  \
        CONFIG.PCW_EN_CLKTRIG3_PORT {0}  \
        CONFIG.PCW_P2F_DMAC_ABORT_INTR {0}  \
        CONFIG.PCW_P2F_DMAC0_INTR {0}  \
        CONFIG.PCW_P2F_DMAC1_INTR {0}  \
        CONFIG.PCW_P2F_DMAC2_INTR {0}  \
        CONFIG.PCW_P2F_DMAC3_INTR {0}  \
        CONFIG.PCW_P2F_DMAC4_INTR {0}  \
        CONFIG.PCW_P2F_DMAC5_INTR {0}  \
        CONFIG.PCW_P2F_DMAC6_INTR {0}  \
        CONFIG.PCW_P2F_DMAC7_INTR {0}  \
        CONFIG.PCW_P2F_SMC_INTR {0}  \
        CONFIG.PCW_P2F_QSPI_INTR {0}  \
        CONFIG.PCW_P2F_CTI_INTR {0}  \
        CONFIG.PCW_P2F_GPIO_INTR {0}  \
        CONFIG.PCW_P2F_USB0_INTR {0}  \
        CONFIG.PCW_P2F_ENET0_INTR {0}  \
        CONFIG.PCW_P2F_SDIO0_INTR {0}  \
        CONFIG.PCW_P2F_I2C0_INTR {0}  \
        CONFIG.PCW_P2F_SPI0_INTR {0}  \
        CONFIG.PCW_P2F_UART0_INTR {0}  \
        CONFIG.PCW_P2F_CAN0_INTR {0}  \
        CONFIG.PCW_P2F_USB1_INTR {0}  \
        CONFIG.PCW_P2F_ENET1_INTR {0}  \
        CONFIG.PCW_P2F_SDIO1_INTR {0}  \
        CONFIG.PCW_P2F_I2C1_INTR {0}  \
        CONFIG.PCW_P2F_SPI1_INTR {0}  \
        CONFIG.PCW_P2F_UART1_INTR {0}  \
        CONFIG.PCW_P2F_CAN1_INTR {0}  \
        CONFIG.PCW_IRQ_F2P_INTR {1}  \
        CONFIG.PCW_IRQ_F2P_MODE {DIRECT}  \
        CONFIG.PCW_CORE0_FIQ_INTR {0}  \
        CONFIG.PCW_CORE0_IRQ_INTR {0}  \
        CONFIG.PCW_CORE1_FIQ_INTR {0}  \
        CONFIG.PCW_CORE1_IRQ_INTR {0}  \
        CONFIG.PCW_VALUE_SILVERSION {3}  \
        CONFIG.PCW_GP0_EN_MODIFIABLE_TXN {1}  \
        CONFIG.PCW_GP1_EN_MODIFIABLE_TXN {1}  \
        CONFIG.PCW_IMPORT_BOARD_PRESET {None}  \
        CONFIG.PCW_PERIPHERAL_BOARD_PRESET {part0}  \
        CONFIG.PCW_PRESET_BANK0_VOLTAGE {LVCMOS 3.3V}  \
        CONFIG.PCW_PRESET_BANK1_VOLTAGE {LVCMOS 1.8V}  \
        CONFIG.PCW_UIPARAM_DDR_ENABLE {1}  \
        CONFIG.PCW_UIPARAM_DDR_ADV_ENABLE {0}  \
        CONFIG.PCW_UIPARAM_DDR_MEMORY_TYPE {DDR 3}  \
        CONFIG.PCW_UIPARAM_DDR_ECC {Disabled}  \
        CONFIG.PCW_UIPARAM_DDR_BUS_WIDTH {32 Bit}  \
        CONFIG.PCW_UIPARAM_DDR_BL {8}  \
        CONFIG.PCW_UIPARAM_DDR_HIGH_TEMP {Normal (0-85)}  \
        CONFIG.PCW_UIPARAM_DDR_PARTNO {MT41J256M16 RE-125}  \
        CONFIG.PCW_UIPARAM_DDR_DRAM_WIDTH {16 Bits}  \
        CONFIG.PCW_UIPARAM_DDR_DEVICE_CAPACITY {4096 MBits}  \
        CONFIG.PCW_UIPARAM_DDR_SPEED_BIN {DDR3_1066F}  \
        CONFIG.PCW_UIPARAM_DDR_TRAIN_WRITE_LEVEL {1}  \
        CONFIG.PCW_UIPARAM_DDR_TRAIN_READ_GATE {1}  \
        CONFIG.PCW_UIPARAM_DDR_TRAIN_DATA_EYE {1}  \
        CONFIG.PCW_UIPARAM_DDR_CLOCK_STOP_EN {0}  \
        CONFIG.PCW_UIPARAM_DDR_USE_INTERNAL_VREF {0}  \
        CONFIG.PCW_DDR_PRIORITY_WRITEPORT_0 {<Select>}  \
        CONFIG.PCW_DDR_PRIORITY_WRITEPORT_1 {<Select>}  \
        CONFIG.PCW_DDR_PRIORITY_WRITEPORT_2 {<Select>}  \
        CONFIG.PCW_DDR_PRIORITY_WRITEPORT_3 {<Select>}  \
        CONFIG.PCW_DDR_PRIORITY_READPORT_0 {<Select>}  \
        CONFIG.PCW_DDR_PRIORITY_READPORT_1 {<Select>}  \
        CONFIG.PCW_DDR_PRIORITY_READPORT_2 {<Select>}  \
        CONFIG.PCW_DDR_PRIORITY_READPORT_3 {<Select>}  \
        CONFIG.PCW_DDR_PORT0_HPR_ENABLE {0}  \
        CONFIG.PCW_DDR_PORT1_HPR_ENABLE {0}  \
        CONFIG.PCW_DDR_PORT2_HPR_ENABLE {0}  \
        CONFIG.PCW_DDR_PORT3_HPR_ENABLE {0}  \
        CONFIG.PCW_DDR_HPRLPR_QUEUE_PARTITION {HPR(0)/LPR(32)}  \
        CONFIG.PCW_DDR_LPR_TO_CRITICAL_PRIORITY_LEVEL {2}  \
        CONFIG.PCW_DDR_HPR_TO_CRITICAL_PRIORITY_LEVEL {15}  \
        CONFIG.PCW_DDR_WRITE_TO_CRITICAL_PRIORITY_LEVEL {2}  \
        CONFIG.PCW_NAND_PERIPHERAL_ENABLE {0}  \
        CONFIG.PCW_NAND_NAND_IO {<Select>}  \
        CONFIG.PCW_NAND_GRP_D8_ENABLE {0}  \
        CONFIG.PCW_NAND_GRP_D8_IO {<Select>}  \
        CONFIG.PCW_NOR_PERIPHERAL_ENABLE {0}  \
        CONFIG.PCW_NOR_NOR_IO {<Select>}  \
        CONFIG.PCW_NOR_GRP_A25_ENABLE {0}  \
        CONFIG.PCW_NOR_GRP_A25_IO {<Select>}  \
        CONFIG.PCW_NOR_GRP_CS0_ENABLE {0}  \
        CONFIG.PCW_NOR_GRP_CS0_IO {<Select>}  \
        CONFIG.PCW_NOR_GRP_SRAM_CS0_ENABLE {0}  \
        CONFIG.PCW_NOR_GRP_SRAM_CS0_IO {<Select>}  \
        CONFIG.PCW_NOR_GRP_CS1_ENABLE {0}  \
        CONFIG.PCW_NOR_GRP_CS1_IO {<Select>}  \
        CONFIG.PCW_NOR_GRP_SRAM_CS1_ENABLE {0}  \
        CONFIG.PCW_NOR_GRP_SRAM_CS1_IO {<Select>}  \
        CONFIG.PCW_NOR_GRP_SRAM_INT_ENABLE {0}  \
        CONFIG.PCW_NOR_GRP_SRAM_INT_IO {<Select>}  \
        CONFIG.PCW_QSPI_PERIPHERAL_ENABLE {1}  \
        CONFIG.PCW_QSPI_QSPI_IO {MIO 1 .. 6}  \
        CONFIG.PCW_QSPI_GRP_SINGLE_SS_ENABLE {1}  \
        CONFIG.PCW_QSPI_GRP_SINGLE_SS_IO {MIO 1 .. 6}  \
        CONFIG.PCW_QSPI_GRP_SS1_ENABLE {0}  \
        CONFIG.PCW_QSPI_GRP_SS1_IO {<Select>}  \
        CONFIG.PCW_SINGLE_QSPI_DATA_MODE {x4}  \
        CONFIG.PCW_QSPI_GRP_IO1_ENABLE {0}  \
        CONFIG.PCW_QSPI_GRP_IO1_IO {<Select>}  \
        CONFIG.PCW_QSPI_GRP_FBCLK_ENABLE {0}  \
        CONFIG.PCW_QSPI_GRP_FBCLK_IO {<Select>}  \
        CONFIG.PCW_QSPI_INTERNAL_HIGHADDRESS {0xFCFFFFFF}  \
        CONFIG.PCW_ENET0_PERIPHERAL_ENABLE {1}  \
        CONFIG.PCW_ENET0_ENET0_IO {MIO 16 .. 27}  \
        CONFIG.PCW_ENET0_GRP_MDIO_ENABLE {1}  \
        CONFIG.PCW_ENET0_GRP_MDIO_IO {MIO 52 .. 53}  \
        CONFIG.PCW_ENET_RESET_ENABLE {0}  \
        CONFIG.PCW_ENET_RESET_SELECT {<Select>}  \
        CONFIG.PCW_ENET0_RESET_ENABLE {0}  \
        CONFIG.PCW_ENET0_RESET_IO {<Select>}  \
        CONFIG.PCW_ENET1_PERIPHERAL_ENABLE {0}  \
        CONFIG.PCW_ENET1_ENET1_IO {<Select>}  \
        CONFIG.PCW_ENET1_GRP_MDIO_ENABLE {0}  \
        CONFIG.PCW_ENET1_GRP_MDIO_IO {<Select>}  \
        CONFIG.PCW_ENET1_RESET_ENABLE {0}  \
        CONFIG.PCW_ENET1_RESET_IO {<Select>}  \
        CONFIG.PCW_SD0_PERIPHERAL_ENABLE {1}  \
        CONFIG.PCW_SD0_SD0_IO {MIO 40 .. 45}  \
        CONFIG.PCW_SD0_GRP_CD_ENABLE {1}  \
        CONFIG.PCW_SD0_GRP_CD_IO {MIO 10}  \
        CONFIG.PCW_SD0_GRP_WP_ENABLE {0}  \
        CONFIG.PCW_SD0_GRP_WP_IO {<Select>}  \
        CONFIG.PCW_SD0_GRP_POW_ENABLE {0}  \
        CONFIG.PCW_SD0_GRP_POW_IO {<Select>}  \
        CONFIG.PCW_SD1_PERIPHERAL_ENABLE {1}  \
        CONFIG.PCW_SD1_SD1_IO {MIO 46 .. 51}  \
        CONFIG.PCW_SD1_GRP_CD_ENABLE {0}  \
        CONFIG.PCW_SD1_GRP_CD_IO {<Select>}  \
        CONFIG.PCW_SD1_GRP_WP_ENABLE {0}  \
        CONFIG.PCW_SD1_GRP_WP_IO {<Select>}  \
        CONFIG.PCW_SD1_GRP_POW_ENABLE {0}  \
        CONFIG.PCW_SD1_GRP_POW_IO {<Select>}  \
        CONFIG.PCW_UART0_PERIPHERAL_ENABLE {1}  \
        CONFIG.PCW_UART0_UART0_IO {MIO 14 .. 15}  \
        CONFIG.PCW_UART0_GRP_FULL_ENABLE {0}  \
        CONFIG.PCW_UART0_GRP_FULL_IO {<Select>}  \
        CONFIG.PCW_UART1_PERIPHERAL_ENABLE {0}  \
        CONFIG.PCW_UART1_UART1_IO {<Select>}  \
        CONFIG.PCW_UART1_GRP_FULL_ENABLE {0}  \
        CONFIG.PCW_UART1_GRP_FULL_IO {<Select>}  \
        CONFIG.PCW_SPI0_PERIPHERAL_ENABLE {0}  \
        CONFIG.PCW_SPI0_SPI0_IO {<Select>}  \
        CONFIG.PCW_SPI0_GRP_SS0_ENABLE {0}  \
        CONFIG.PCW_SPI0_GRP_SS0_IO {<Select>}  \
        CONFIG.PCW_SPI0_GRP_SS1_ENABLE {0}  \
        CONFIG.PCW_SPI0_GRP_SS1_IO {<Select>}  \
        CONFIG.PCW_SPI0_GRP_SS2_ENABLE {0}  \
        CONFIG.PCW_SPI0_GRP_SS2_IO {<Select>}  \
        CONFIG.PCW_SPI1_PERIPHERAL_ENABLE {0}  \
        CONFIG.PCW_SPI1_SPI1_IO {<Select>}  \
        CONFIG.PCW_SPI1_GRP_SS0_ENABLE {0}  \
        CONFIG.PCW_SPI1_GRP_SS0_IO {<Select>}  \
        CONFIG.PCW_SPI1_GRP_SS1_ENABLE {0}  \
        CONFIG.PCW_SPI1_GRP_SS1_IO {<Select>}  \
        CONFIG.PCW_SPI1_GRP_SS2_ENABLE {0}  \
        CONFIG.PCW_SPI1_GRP_SS2_IO {<Select>}  \
        CONFIG.PCW_CAN0_PERIPHERAL_ENABLE {0}  \
        CONFIG.PCW_CAN0_CAN0_IO {<Select>}  \
        CONFIG.PCW_CAN0_GRP_CLK_ENABLE {0}  \
        CONFIG.PCW_CAN0_GRP_CLK_IO {<Select>}  \
        CONFIG.PCW_CAN1_PERIPHERAL_ENABLE {0}  \
        CONFIG.PCW_CAN1_CAN1_IO {<Select>}  \
        CONFIG.PCW_CAN1_GRP_CLK_ENABLE {0}  \
        CONFIG.PCW_CAN1_GRP_CLK_IO {<Select>}  \
        CONFIG.PCW_TRACE_PERIPHERAL_ENABLE {0}  \
        CONFIG.PCW_TRACE_TRACE_IO {<Select>}  \
        CONFIG.PCW_TRACE_GRP_2BIT_ENABLE {0}  \
        CONFIG.PCW_TRACE_GRP_2BIT_IO {<Select>}  \
        CONFIG.PCW_TRACE_GRP_4BIT_ENABLE {0}  \
        CONFIG.PCW_TRACE_GRP_4BIT_IO {<Select>}  \
        CONFIG.PCW_TRACE_GRP_8BIT_ENABLE {0}  \
        CONFIG.PCW_TRACE_GRP_8BIT_IO {<Select>}  \
        CONFIG.PCW_TRACE_GRP_16BIT_ENABLE {0}  \
        CONFIG.PCW_TRACE_GRP_16BIT_IO {<Select>}  \
        CONFIG.PCW_TRACE_GRP_32BIT_ENABLE {0}  \
        CONFIG.PCW_TRACE_GRP_32BIT_IO {<Select>}  \
        CONFIG.PCW_TRACE_INTERNAL_WIDTH {2}  \
        CONFIG.PCW_WDT_PERIPHERAL_ENABLE {0}  \
        CONFIG.PCW_WDT_WDT_IO {<Select>}  \
        CONFIG.PCW_TTC0_PERIPHERAL_ENABLE {0}  \
        CONFIG.PCW_TTC0_TTC0_IO {<Select>}  \
        CONFIG.PCW_TTC1_PERIPHERAL_ENABLE {0}  \
        CONFIG.PCW_TTC1_TTC1_IO {<Select>}  \
        CONFIG.PCW_PJTAG_PERIPHERAL_ENABLE {0}  \
        CONFIG.PCW_PJTAG_PJTAG_IO {<Select>}  \
        CONFIG.PCW_USB0_PERIPHERAL_ENABLE {1}  \
        CONFIG.PCW_USB0_USB0_IO {MIO 28 .. 39}  \
        CONFIG.PCW_USB_RESET_ENABLE {1}  \
        CONFIG.PCW_USB_RESET_SELECT {Share reset pin}  \
        CONFIG.PCW_USB0_RESET_ENABLE {1}  \
        CONFIG.PCW_USB0_RESET_IO {MIO 9}  \
        CONFIG.PCW_USB1_PERIPHERAL_ENABLE {0}  \
        CONFIG.PCW_USB1_USB1_IO {<Select>}  \
        CONFIG.PCW_USB1_RESET_ENABLE {0}  \
        CONFIG.PCW_USB1_RESET_IO {<Select>}  \
        CONFIG.PCW_I2C0_PERIPHERAL_ENABLE {1}  \
        CONFIG.PCW_I2C0_I2C0_IO {EMIO}  \
        CONFIG.PCW_I2C0_GRP_INT_ENABLE {1}  \
        CONFIG.PCW_I2C0_GRP_INT_IO {EMIO}  \
        CONFIG.PCW_I2C0_RESET_ENABLE {0}  \
        CONFIG.PCW_I2C0_RESET_IO {<Select>}  \
        CONFIG.PCW_I2C1_PERIPHERAL_ENABLE {1}  \
        CONFIG.PCW_I2C1_I2C1_IO {EMIO}  \
        CONFIG.PCW_I2C1_GRP_INT_ENABLE {1}  \
        CONFIG.PCW_I2C1_GRP_INT_IO {EMIO}  \
        CONFIG.PCW_I2C_RESET_ENABLE {0}  \
        CONFIG.PCW_I2C_RESET_SELECT {<Select>}  \
        CONFIG.PCW_I2C1_RESET_ENABLE {0}  \
        CONFIG.PCW_I2C1_RESET_IO {<Select>}  \
        CONFIG.PCW_GPIO_PERIPHERAL_ENABLE {0}  \
        CONFIG.PCW_GPIO_MIO_GPIO_ENABLE {1}  \
        CONFIG.PCW_GPIO_MIO_GPIO_IO {MIO}  \
        CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE {0}  \
        CONFIG.PCW_GPIO_EMIO_GPIO_IO {<Select>}  \
        CONFIG.PCW_APU_CLK_RATIO_ENABLE {6:2:1}  \
        CONFIG.PCW_ENET0_PERIPHERAL_FREQMHZ {1000 Mbps}  \
        CONFIG.PCW_ENET1_PERIPHERAL_FREQMHZ {1000 Mbps}  \
        CONFIG.PCW_CPU_PERIPHERAL_CLKSRC {ARM PLL}  \
        CONFIG.PCW_DDR_PERIPHERAL_CLKSRC {DDR PLL}  \
        CONFIG.PCW_SMC_PERIPHERAL_CLKSRC {IO PLL}  \
        CONFIG.PCW_QSPI_PERIPHERAL_CLKSRC {IO PLL}  \
        CONFIG.PCW_SDIO_PERIPHERAL_CLKSRC {IO PLL}  \
        CONFIG.PCW_UART_PERIPHERAL_CLKSRC {IO PLL}  \
        CONFIG.PCW_SPI_PERIPHERAL_CLKSRC {IO PLL}  \
        CONFIG.PCW_CAN_PERIPHERAL_CLKSRC {IO PLL}  \
        CONFIG.PCW_FCLK0_PERIPHERAL_CLKSRC {IO PLL}  \
        CONFIG.PCW_FCLK1_PERIPHERAL_CLKSRC {IO PLL}  \
        CONFIG.PCW_FCLK2_PERIPHERAL_CLKSRC {IO PLL}  \
        CONFIG.PCW_FCLK3_PERIPHERAL_CLKSRC {IO PLL}  \
        CONFIG.PCW_ENET0_PERIPHERAL_CLKSRC {IO PLL}  \
        CONFIG.PCW_ENET1_PERIPHERAL_CLKSRC {External}  \
        CONFIG.PCW_CAN0_PERIPHERAL_CLKSRC {External}  \
        CONFIG.PCW_CAN1_PERIPHERAL_CLKSRC {External}  \
        CONFIG.PCW_TPIU_PERIPHERAL_CLKSRC {External}  \
        CONFIG.PCW_TTC0_CLK0_PERIPHERAL_CLKSRC {CPU_1X}  \
        CONFIG.PCW_TTC0_CLK1_PERIPHERAL_CLKSRC {CPU_1X}  \
        CONFIG.PCW_TTC0_CLK2_PERIPHERAL_CLKSRC {CPU_1X}  \
        CONFIG.PCW_TTC1_CLK0_PERIPHERAL_CLKSRC {CPU_1X}  \
        CONFIG.PCW_TTC1_CLK1_PERIPHERAL_CLKSRC {CPU_1X}  \
        CONFIG.PCW_TTC1_CLK2_PERIPHERAL_CLKSRC {CPU_1X}  \
        CONFIG.PCW_WDT_PERIPHERAL_CLKSRC {CPU_1X}  \
        CONFIG.PCW_DCI_PERIPHERAL_CLKSRC {DDR PLL}  \
        CONFIG.PCW_PCAP_PERIPHERAL_CLKSRC {IO PLL}  \
        CONFIG.PCW_USB_RESET_POLARITY {Active Low}  \
        CONFIG.PCW_ENET_RESET_POLARITY {Active Low}  \
        CONFIG.PCW_I2C_RESET_POLARITY {Active Low}  \
        CONFIG.PCW_MIO_0_PULLUP {enabled}  \
        CONFIG.PCW_MIO_0_IOTYPE {LVCMOS 3.3V}  \
        CONFIG.PCW_MIO_0_DIRECTION {inout}  \
        CONFIG.PCW_MIO_0_SLEW {slow}  \
        CONFIG.PCW_MIO_1_PULLUP {enabled}  \
        CONFIG.PCW_MIO_1_IOTYPE {LVCMOS 3.3V}  \
        CONFIG.PCW_MIO_1_DIRECTION {out}  \
        CONFIG.PCW_MIO_1_SLEW {fast}  \
        CONFIG.PCW_MIO_2_PULLUP {disabled}  \
        CONFIG.PCW_MIO_2_IOTYPE {LVCMOS 3.3V}  \
        CONFIG.PCW_MIO_2_DIRECTION {inout}  \
        CONFIG.PCW_MIO_2_SLEW {fast}  \
        CONFIG.PCW_MIO_3_PULLUP {disabled}  \
        CONFIG.PCW_MIO_3_IOTYPE {LVCMOS 3.3V}  \
        CONFIG.PCW_MIO_3_DIRECTION {inout}  \
        CONFIG.PCW_MIO_3_SLEW {fast}  \
        CONFIG.PCW_MIO_4_PULLUP {disabled}  \
        CONFIG.PCW_MIO_4_IOTYPE {LVCMOS 3.3V}  \
        CONFIG.PCW_MIO_4_DIRECTION {inout}  \
        CONFIG.PCW_MIO_4_SLEW {fast}  \
        CONFIG.PCW_MIO_5_PULLUP {disabled}  \
        CONFIG.PCW_MIO_5_IOTYPE {LVCMOS 3.3V}  \
        CONFIG.PCW_MIO_5_DIRECTION {inout}  \
        CONFIG.PCW_MIO_5_SLEW {fast}  \
        CONFIG.PCW_MIO_6_PULLUP {disabled}  \
        CONFIG.PCW_MIO_6_IOTYPE {LVCMOS 3.3V}  \
        CONFIG.PCW_MIO_6_DIRECTION {out}  \
        CONFIG.PCW_MIO_6_SLEW {fast}  \
        CONFIG.PCW_MIO_7_PULLUP {disabled}  \
        CONFIG.PCW_MIO_7_IOTYPE {LVCMOS 3.3V}  \
        CONFIG.PCW_MIO_7_DIRECTION {out}  \
        CONFIG.PCW_MIO_7_SLEW {slow}  \
        CONFIG.PCW_MIO_8_PULLUP {disabled}  \
        CONFIG.PCW_MIO_8_IOTYPE {LVCMOS 3.3V}  \
        CONFIG.PCW_MIO_8_DIRECTION {out}  \
        CONFIG.PCW_MIO_8_SLEW {slow}  \
        CONFIG.PCW_MIO_9_PULLUP {enabled}  \
        CONFIG.PCW_MIO_9_IOTYPE {LVCMOS 3.3V}  \
        CONFIG.PCW_MIO_9_DIRECTION {out}  \
        CONFIG.PCW_MIO_9_SLEW {slow}  \
        CONFIG.PCW_MIO_10_PULLUP {enabled}  \
        CONFIG.PCW_MIO_10_IOTYPE {LVCMOS 3.3V}  \
        CONFIG.PCW_MIO_10_DIRECTION {in}  \
        CONFIG.PCW_MIO_10_SLEW {fast}  \
        CONFIG.PCW_MIO_11_PULLUP {enabled}  \
        CONFIG.PCW_MIO_11_IOTYPE {LVCMOS 3.3V}  \
        CONFIG.PCW_MIO_11_DIRECTION {inout}  \
        CONFIG.PCW_MIO_11_SLEW {slow}  \
        CONFIG.PCW_MIO_12_PULLUP {enabled}  \
        CONFIG.PCW_MIO_12_IOTYPE {LVCMOS 3.3V}  \
        CONFIG.PCW_MIO_12_DIRECTION {inout}  \
        CONFIG.PCW_MIO_12_SLEW {slow}  \
        CONFIG.PCW_MIO_13_PULLUP {enabled}  \
        CONFIG.PCW_MIO_13_IOTYPE {LVCMOS 3.3V}  \
        CONFIG.PCW_MIO_13_DIRECTION {inout}  \
        CONFIG.PCW_MIO_13_SLEW {slow}  \
        CONFIG.PCW_MIO_14_PULLUP {enabled}  \
        CONFIG.PCW_MIO_14_IOTYPE {LVCMOS 3.3V}  \
        CONFIG.PCW_MIO_14_DIRECTION {in}  \
        CONFIG.PCW_MIO_14_SLEW {slow}  \
        CONFIG.PCW_MIO_15_PULLUP {enabled}  \
        CONFIG.PCW_MIO_15_IOTYPE {LVCMOS 3.3V}  \
        CONFIG.PCW_MIO_15_DIRECTION {out}  \
        CONFIG.PCW_MIO_15_SLEW {slow}  \
        CONFIG.PCW_MIO_16_PULLUP {enabled}  \
        CONFIG.PCW_MIO_16_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_16_DIRECTION {out}  \
        CONFIG.PCW_MIO_16_SLEW {fast}  \
        CONFIG.PCW_MIO_17_PULLUP {enabled}  \
        CONFIG.PCW_MIO_17_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_17_DIRECTION {out}  \
        CONFIG.PCW_MIO_17_SLEW {fast}  \
        CONFIG.PCW_MIO_18_PULLUP {enabled}  \
        CONFIG.PCW_MIO_18_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_18_DIRECTION {out}  \
        CONFIG.PCW_MIO_18_SLEW {fast}  \
        CONFIG.PCW_MIO_19_PULLUP {enabled}  \
        CONFIG.PCW_MIO_19_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_19_DIRECTION {out}  \
        CONFIG.PCW_MIO_19_SLEW {fast}  \
        CONFIG.PCW_MIO_20_PULLUP {enabled}  \
        CONFIG.PCW_MIO_20_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_20_DIRECTION {out}  \
        CONFIG.PCW_MIO_20_SLEW {fast}  \
        CONFIG.PCW_MIO_21_PULLUP {enabled}  \
        CONFIG.PCW_MIO_21_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_21_DIRECTION {out}  \
        CONFIG.PCW_MIO_21_SLEW {fast}  \
        CONFIG.PCW_MIO_22_PULLUP {enabled}  \
        CONFIG.PCW_MIO_22_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_22_DIRECTION {in}  \
        CONFIG.PCW_MIO_22_SLEW {fast}  \
        CONFIG.PCW_MIO_23_PULLUP {enabled}  \
        CONFIG.PCW_MIO_23_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_23_DIRECTION {in}  \
        CONFIG.PCW_MIO_23_SLEW {fast}  \
        CONFIG.PCW_MIO_24_PULLUP {enabled}  \
        CONFIG.PCW_MIO_24_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_24_DIRECTION {in}  \
        CONFIG.PCW_MIO_24_SLEW {fast}  \
        CONFIG.PCW_MIO_25_PULLUP {enabled}  \
        CONFIG.PCW_MIO_25_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_25_DIRECTION {in}  \
        CONFIG.PCW_MIO_25_SLEW {fast}  \
        CONFIG.PCW_MIO_26_PULLUP {enabled}  \
        CONFIG.PCW_MIO_26_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_26_DIRECTION {in}  \
        CONFIG.PCW_MIO_26_SLEW {fast}  \
        CONFIG.PCW_MIO_27_PULLUP {enabled}  \
        CONFIG.PCW_MIO_27_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_27_DIRECTION {in}  \
        CONFIG.PCW_MIO_27_SLEW {fast}  \
        CONFIG.PCW_MIO_28_PULLUP {enabled}  \
        CONFIG.PCW_MIO_28_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_28_DIRECTION {inout}  \
        CONFIG.PCW_MIO_28_SLEW {fast}  \
        CONFIG.PCW_MIO_29_PULLUP {enabled}  \
        CONFIG.PCW_MIO_29_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_29_DIRECTION {in}  \
        CONFIG.PCW_MIO_29_SLEW {fast}  \
        CONFIG.PCW_MIO_30_PULLUP {enabled}  \
        CONFIG.PCW_MIO_30_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_30_DIRECTION {out}  \
        CONFIG.PCW_MIO_30_SLEW {fast}  \
        CONFIG.PCW_MIO_31_PULLUP {enabled}  \
        CONFIG.PCW_MIO_31_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_31_DIRECTION {in}  \
        CONFIG.PCW_MIO_31_SLEW {fast}  \
        CONFIG.PCW_MIO_32_PULLUP {enabled}  \
        CONFIG.PCW_MIO_32_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_32_DIRECTION {inout}  \
        CONFIG.PCW_MIO_32_SLEW {fast}  \
        CONFIG.PCW_MIO_33_PULLUP {enabled}  \
        CONFIG.PCW_MIO_33_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_33_DIRECTION {inout}  \
        CONFIG.PCW_MIO_33_SLEW {fast}  \
        CONFIG.PCW_MIO_34_PULLUP {enabled}  \
        CONFIG.PCW_MIO_34_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_34_DIRECTION {inout}  \
        CONFIG.PCW_MIO_34_SLEW {fast}  \
        CONFIG.PCW_MIO_35_PULLUP {enabled}  \
        CONFIG.PCW_MIO_35_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_35_DIRECTION {inout}  \
        CONFIG.PCW_MIO_35_SLEW {fast}  \
        CONFIG.PCW_MIO_36_PULLUP {enabled}  \
        CONFIG.PCW_MIO_36_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_36_DIRECTION {in}  \
        CONFIG.PCW_MIO_36_SLEW {fast}  \
        CONFIG.PCW_MIO_37_PULLUP {enabled}  \
        CONFIG.PCW_MIO_37_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_37_DIRECTION {inout}  \
        CONFIG.PCW_MIO_37_SLEW {fast}  \
        CONFIG.PCW_MIO_38_PULLUP {enabled}  \
        CONFIG.PCW_MIO_38_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_38_DIRECTION {inout}  \
        CONFIG.PCW_MIO_38_SLEW {fast}  \
        CONFIG.PCW_MIO_39_PULLUP {enabled}  \
        CONFIG.PCW_MIO_39_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_39_DIRECTION {inout}  \
        CONFIG.PCW_MIO_39_SLEW {fast}  \
        CONFIG.PCW_MIO_40_PULLUP {enabled}  \
        CONFIG.PCW_MIO_40_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_40_DIRECTION {inout}  \
        CONFIG.PCW_MIO_40_SLEW {fast}  \
        CONFIG.PCW_MIO_41_PULLUP {enabled}  \
        CONFIG.PCW_MIO_41_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_41_DIRECTION {inout}  \
        CONFIG.PCW_MIO_41_SLEW {fast}  \
        CONFIG.PCW_MIO_42_PULLUP {enabled}  \
        CONFIG.PCW_MIO_42_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_42_DIRECTION {inout}  \
        CONFIG.PCW_MIO_42_SLEW {fast}  \
        CONFIG.PCW_MIO_43_PULLUP {enabled}  \
        CONFIG.PCW_MIO_43_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_43_DIRECTION {inout}  \
        CONFIG.PCW_MIO_43_SLEW {fast}  \
        CONFIG.PCW_MIO_44_PULLUP {enabled}  \
        CONFIG.PCW_MIO_44_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_44_DIRECTION {inout}  \
        CONFIG.PCW_MIO_44_SLEW {fast}  \
        CONFIG.PCW_MIO_45_PULLUP {enabled}  \
        CONFIG.PCW_MIO_45_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_45_DIRECTION {inout}  \
        CONFIG.PCW_MIO_45_SLEW {fast}  \
        CONFIG.PCW_MIO_46_PULLUP {enabled}  \
        CONFIG.PCW_MIO_46_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_46_DIRECTION {inout}  \
        CONFIG.PCW_MIO_46_SLEW {fast}  \
        CONFIG.PCW_MIO_47_PULLUP {enabled}  \
        CONFIG.PCW_MIO_47_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_47_DIRECTION {inout}  \
        CONFIG.PCW_MIO_47_SLEW {fast}  \
        CONFIG.PCW_MIO_48_PULLUP {enabled}  \
        CONFIG.PCW_MIO_48_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_48_DIRECTION {inout}  \
        CONFIG.PCW_MIO_48_SLEW {fast}  \
        CONFIG.PCW_MIO_49_PULLUP {enabled}  \
        CONFIG.PCW_MIO_49_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_49_DIRECTION {inout}  \
        CONFIG.PCW_MIO_49_SLEW {fast}  \
        CONFIG.PCW_MIO_50_PULLUP {enabled}  \
        CONFIG.PCW_MIO_50_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_50_DIRECTION {inout}  \
        CONFIG.PCW_MIO_50_SLEW {fast}  \
        CONFIG.PCW_MIO_51_PULLUP {enabled}  \
        CONFIG.PCW_MIO_51_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_51_DIRECTION {inout}  \
        CONFIG.PCW_MIO_51_SLEW {fast}  \
        CONFIG.PCW_MIO_52_PULLUP {enabled}  \
        CONFIG.PCW_MIO_52_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_52_DIRECTION {out}  \
        CONFIG.PCW_MIO_52_SLEW {fast}  \
        CONFIG.PCW_MIO_53_PULLUP {enabled}  \
        CONFIG.PCW_MIO_53_IOTYPE {LVCMOS 1.8V}  \
        CONFIG.PCW_MIO_53_DIRECTION {inout}  \
        CONFIG.PCW_MIO_53_SLEW {fast}  \
        CONFIG.PCW_UIPARAM_GENERATE_SUMMARY {NA}  \
        CONFIG.PCW_MIO_TREE_PERIPHERALS {GPIO#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#Quad SPI Flash#GPIO#GPIO#USB Reset#SD 0#GPIO#GPIO#GPIO#UART 0#UART 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#Enet 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#USB 0#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0#SD 1#SD 1#SD 1#SD 1#SD 1#SD 1#Enet 0#Enet 0}  \
        CONFIG.PCW_MIO_TREE_SIGNALS {gpio[0]#qspi0_ss_b#qspi0_io[0]#qspi0_io[1]#qspi0_io[2]#qspi0_io[3]/HOLD_B#qspi0_sclk#gpio[7]#gpio[8]#reset#cd#gpio[11]#gpio[12]#gpio[13]#rx#tx#tx_clk#txd[0]#txd[1]#txd[2]#txd[3]#tx_ctl#rx_clk#rxd[0]#rxd[1]#rxd[2]#rxd[3]#rx_ctl#data[4]#dir#stp#nxt#data[0]#data[1]#data[2]#data[3]#clk#data[5]#data[6]#data[7]#clk#cmd#data[0]#data[1]#data[2]#data[3]#data[0]#cmd#clk#data[1]#data[2]#data[3]#mdc#mdio}  \
        CONFIG.PCW_PS7_SI_REV {PRODUCTION}  \
        CONFIG.PCW_FPGA_FCLK0_ENABLE {1}  \
        CONFIG.PCW_FPGA_FCLK1_ENABLE {1}  \
        CONFIG.PCW_FPGA_FCLK2_ENABLE {0}  \
        CONFIG.PCW_FPGA_FCLK3_ENABLE {0}  \
        CONFIG.PCW_NOR_SRAM_CS0_T_TR {1}  \
        CONFIG.PCW_NOR_SRAM_CS0_T_PC {1}  \
        CONFIG.PCW_NOR_SRAM_CS0_T_WP {1}  \
        CONFIG.PCW_NOR_SRAM_CS0_T_CEOE {1}  \
        CONFIG.PCW_NOR_SRAM_CS0_T_WC {11}  \
        CONFIG.PCW_NOR_SRAM_CS0_T_RC {11}  \
        CONFIG.PCW_NOR_SRAM_CS0_WE_TIME {0}  \
        CONFIG.PCW_NOR_SRAM_CS1_T_TR {1}  \
        CONFIG.PCW_NOR_SRAM_CS1_T_PC {1}  \
        CONFIG.PCW_NOR_SRAM_CS1_T_WP {1}  \
        CONFIG.PCW_NOR_SRAM_CS1_T_CEOE {1}  \
        CONFIG.PCW_NOR_SRAM_CS1_T_WC {11}  \
        CONFIG.PCW_NOR_SRAM_CS1_T_RC {11}  \
        CONFIG.PCW_NOR_SRAM_CS1_WE_TIME {0}  \
        CONFIG.PCW_NOR_CS0_T_TR {1}  \
        CONFIG.PCW_NOR_CS0_T_PC {1}  \
        CONFIG.PCW_NOR_CS0_T_WP {1}  \
        CONFIG.PCW_NOR_CS0_T_CEOE {1}  \
        CONFIG.PCW_NOR_CS0_T_WC {11}  \
        CONFIG.PCW_NOR_CS0_T_RC {11}  \
        CONFIG.PCW_NOR_CS0_WE_TIME {0}  \
        CONFIG.PCW_NOR_CS1_T_TR {1}  \
        CONFIG.PCW_NOR_CS1_T_PC {1}  \
        CONFIG.PCW_NOR_CS1_T_WP {1}  \
        CONFIG.PCW_NOR_CS1_T_CEOE {1}  \
        CONFIG.PCW_NOR_CS1_T_WC {11}  \
        CONFIG.PCW_NOR_CS1_T_RC {11}  \
        CONFIG.PCW_NOR_CS1_WE_TIME {0}  \
        CONFIG.PCW_NAND_CYCLES_T_RR {1}  \
        CONFIG.PCW_NAND_CYCLES_T_AR {1}  \
        CONFIG.PCW_NAND_CYCLES_T_CLR {1}  \
        CONFIG.PCW_NAND_CYCLES_T_WP {1}  \
        CONFIG.PCW_NAND_CYCLES_T_REA {1}  \
        CONFIG.PCW_NAND_CYCLES_T_WC {11}  \
        CONFIG.PCW_NAND_CYCLES_T_RC {11}  \
        CONFIG.PCW_SMC_CYCLE_T0 {NA}  \
        CONFIG.PCW_SMC_CYCLE_T1 {NA}  \
        CONFIG.PCW_SMC_CYCLE_T2 {NA}  \
        CONFIG.PCW_SMC_CYCLE_T3 {NA}  \
        CONFIG.PCW_SMC_CYCLE_T4 {NA}  \
        CONFIG.PCW_SMC_CYCLE_T5 {NA}  \
        CONFIG.PCW_SMC_CYCLE_T6 {NA}  \
        CONFIG.PCW_PACKAGE_NAME {clg400}  \
        CONFIG.PCW_PLL_BYPASSMODE_ENABLE {0}  \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_USE_DEFAULT_ACP_USER_VAL {1} \
    CONFIG.PCW_USE_S_AXI_ACP {1} \
  ] $processing_system
  # Get ports that are specific to the Zynq 7000 processing system
  set ps_clk    [get_bd_pins processing_system/FCLK_CLK0]
  set ps_rstn   [get_bd_pins processing_system/FCLK_RESET0_N]
  set maxi_clk  [get_bd_pins processing_system/M_AXI_GP0_ACLK]
  set saxi_clk  [get_bd_pins processing_system/S_AXI_ACP_ACLK]
  set maxi      [get_bd_intf_pins processing_system/M_AXI_GP0]
  set saxi      [get_bd_intf_pins processing_system/S_AXI_ACP]
} elseif { $device_family eq "zynq-ultrascale+" } {
  set processing_system [ create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.3 processing_system ]
  apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" }  [get_bd_cells processing_system]
  set_property -dict [ list \
    CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {100} \
    CONFIG.PSU__USE__M_AXI_GP0 {1} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__M_AXI_GP2 {0} \
    CONFIG.PSU__USE__S_AXI_GP0 {1}
  ] $processing_system
  # Get ports that are specific to the Zynq Ultrascale MPSoC processing system
  set ps_clk    [get_bd_pins processing_system/pl_clk0]
  set ps_rstn   [get_bd_pins processing_system/pl_resetn0]
  set maxi_clk  [get_bd_pins processing_system/maxihpm0_fpd_aclk]
  set saxi_clk  [get_bd_pins processing_system/saxihpc0_fpd_aclk]
  set maxi      [get_bd_intf_pins processing_system/M_AXI_HPM0_FPD]
  set saxi      [get_bd_intf_pins processing_system/S_AXI_HPC0_FPD]
}

# Create interface connections
connect_bd_intf_net -intf_net axi_xbar_M00_AXI [get_bd_intf_pins axi_xbar/M00_AXI] [get_bd_intf_pins fetch_0/s_axi_CONTROL_BUS]
connect_bd_intf_net -intf_net axi_xbar_M01_AXI [get_bd_intf_pins axi_xbar/M01_AXI] [get_bd_intf_pins load_0/s_axi_CONTROL_BUS]
connect_bd_intf_net -intf_net axi_xbar_M02_AXI [get_bd_intf_pins axi_xbar/M02_AXI] [get_bd_intf_pins compute_0/s_axi_CONTROL_BUS]
connect_bd_intf_net -intf_net axi_xbar_M03_AXI [get_bd_intf_pins axi_xbar/M03_AXI] [get_bd_intf_pins store_0/s_axi_CONTROL_BUS]
connect_bd_intf_net -intf_net fetch_0_l2g_dep_queue_V [get_bd_intf_pins l2g_queue/S_AXIS] [get_bd_intf_pins load_0/l2g_dep_queue_V]
connect_bd_intf_net -intf_net fetch_0_load_queue_V_V [get_bd_intf_pins fetch_0/load_queue_V_V] [get_bd_intf_pins load_queue/S_AXIS]
connect_bd_intf_net -intf_net fetch_0_gemm_queue_V_V [get_bd_intf_pins fetch_0/gemm_queue_V_V] [get_bd_intf_pins gemm_queue/S_AXIS]
connect_bd_intf_net -intf_net fetch_0_store_queue_V_V [get_bd_intf_pins fetch_0/store_queue_V_V] [get_bd_intf_pins store_queue/S_AXIS]
connect_bd_intf_net -intf_net compute_0_g2l_dep_queue_V [get_bd_intf_pins compute_0/g2l_dep_queue_V] [get_bd_intf_pins g2l_queue/S_AXIS]
connect_bd_intf_net -intf_net compute_0_g2s_dep_queue_V [get_bd_intf_pins compute_0/g2s_dep_queue_V] [get_bd_intf_pins g2s_queue/S_AXIS]
connect_bd_intf_net -intf_net store_0_s2g_dep_queue_V [get_bd_intf_pins s2g_queue/S_AXIS] [get_bd_intf_pins store_0/s2g_dep_queue_V]
connect_bd_intf_net -intf_net load_queue_M_AXIS [get_bd_intf_pins load_0/load_queue_V_V] [get_bd_intf_pins load_queue/M_AXIS]
connect_bd_intf_net -intf_net gemm_queue_M_AXIS [get_bd_intf_pins compute_0/gemm_queue_V_V] [get_bd_intf_pins gemm_queue/M_AXIS]
connect_bd_intf_net -intf_net store_queue_M_AXIS [get_bd_intf_pins store_0/store_queue_V_V] [get_bd_intf_pins store_queue/M_AXIS]
connect_bd_intf_net -intf_net l2g_queue_M_AXIS [get_bd_intf_pins compute_0/l2g_dep_queue_V] [get_bd_intf_pins l2g_queue/M_AXIS]
connect_bd_intf_net -intf_net g2l_queue_M_AXIS [get_bd_intf_pins g2l_queue/M_AXIS] [get_bd_intf_pins load_0/g2l_dep_queue_V]
connect_bd_intf_net -intf_net g2s_queue_M_AXIS [get_bd_intf_pins g2s_queue/M_AXIS] [get_bd_intf_pins store_0/g2s_dep_queue_V]
connect_bd_intf_net -intf_net s2g_queue_M_AXIS [get_bd_intf_pins compute_0/s2g_dep_queue_V] [get_bd_intf_pins s2g_queue/M_AXIS]
connect_bd_intf_net -intf_net fetch_0_m_axi_ins_port [get_bd_intf_pins axi_smc0/S00_AXI] [get_bd_intf_pins fetch_0/m_axi_ins_port]
connect_bd_intf_net -intf_net load_0_m_axi_data_port [get_bd_intf_pins axi_smc0/S01_AXI] [get_bd_intf_pins load_0/m_axi_data_port]
connect_bd_intf_net -intf_net compute_0_m_axi_uop_port [get_bd_intf_pins axi_smc0/S02_AXI] [get_bd_intf_pins compute_0/m_axi_uop_port]
connect_bd_intf_net -intf_net compute_0_m_axi_data_port [get_bd_intf_pins axi_smc0/S03_AXI] [get_bd_intf_pins compute_0/m_axi_data_port]
connect_bd_intf_net -intf_net store_0_m_axi_data_port [get_bd_intf_pins axi_smc0/S04_AXI] [get_bd_intf_pins store_0/m_axi_data_port]
connect_bd_intf_net -intf_net axi_smc0_M00_AXI [get_bd_intf_pins axi_smc0/M00_AXI] $saxi
connect_bd_intf_net -intf_net processing_system_m_axi [get_bd_intf_pins axi_xbar/S00_AXI] $maxi

# Create port connections
connect_bd_net -net processing_system_reset \
  [get_bd_pins pll_clk/resetn] \
  [get_bd_pins proc_sys_reset/ext_reset_in] \
  $ps_rstn
connect_bd_net -net ps_clk_net \
  [get_bd_pins pll_clk/clk_in1] \
  $ps_clk
connect_bd_net -net proc_sys_reset_interconnect_aresetn \
  [get_bd_pins axi_xbar/ARESETN] \
  [get_bd_pins proc_sys_reset/interconnect_aresetn]
connect_bd_net -net proc_sys_reset_peripheral_aresetn \
  [get_bd_pins proc_sys_reset/peripheral_aresetn] \
  [get_bd_pins axi_smc0/aresetn] \
  [get_bd_pins axi_xbar/M00_ARESETN] \
  [get_bd_pins axi_xbar/M01_ARESETN] \
  [get_bd_pins axi_xbar/M02_ARESETN] \
  [get_bd_pins axi_xbar/M03_ARESETN] \
  [get_bd_pins axi_xbar/S00_ARESETN] \
  [get_bd_pins fetch_0/ap_rst_n] \
  [get_bd_pins load_0/ap_rst_n] \
  [get_bd_pins store_0/ap_rst_n] \
  [get_bd_pins compute_0/ap_rst_n] \
  [get_bd_pins load_queue/s_aresetn] \
  [get_bd_pins gemm_queue/s_aresetn] \
  [get_bd_pins store_queue/s_aresetn] \
  [get_bd_pins l2g_queue/s_aresetn] \
  [get_bd_pins g2l_queue/s_aresetn] \
  [get_bd_pins g2s_queue/s_aresetn] \
  [get_bd_pins s2g_queue/s_aresetn]
connect_bd_net -net processing_system_clk \
  [get_bd_pins pll_clk/clk_out1] \
  [get_bd_pins proc_sys_reset/slowest_sync_clk] \
  [get_bd_pins axi_smc0/aclk] \
  [get_bd_pins axi_xbar/ACLK] \
  [get_bd_pins axi_xbar/M00_ACLK] \
  [get_bd_pins axi_xbar/M01_ACLK] \
  [get_bd_pins axi_xbar/M02_ACLK] \
  [get_bd_pins axi_xbar/M03_ACLK] \
  [get_bd_pins axi_xbar/S00_ACLK] \
  [get_bd_pins fetch_0/ap_clk] \
  [get_bd_pins load_0/ap_clk] \
  [get_bd_pins compute_0/ap_clk] \
  [get_bd_pins store_0/ap_clk] \
  [get_bd_pins load_queue/s_aclk] \
  [get_bd_pins gemm_queue/s_aclk] \
  [get_bd_pins store_queue/s_aclk] \
  [get_bd_pins l2g_queue/s_aclk] \
  [get_bd_pins g2l_queue/s_aclk] \
  [get_bd_pins g2s_queue/s_aclk] \
  [get_bd_pins s2g_queue/s_aclk] \
  $maxi_clk \
  $saxi_clk

# Create address segments
create_bd_addr_seg -range $ip_reg_map_range -offset $fetch_base_addr [get_bd_addr_spaces processing_system/Data] [get_bd_addr_segs fetch_0/s_axi_CONTROL_BUS/Reg] SEG_fetch_0_Reg
create_bd_addr_seg -range $ip_reg_map_range -offset $load_base_addr [get_bd_addr_spaces processing_system/Data] [get_bd_addr_segs load_0/s_axi_CONTROL_BUS/Reg] SEG_load_0_Reg
create_bd_addr_seg -range $ip_reg_map_range -offset $compute_base_addr [get_bd_addr_spaces processing_system/Data] [get_bd_addr_segs compute_0/s_axi_CONTROL_BUS/Reg] SEG_compute_0_Reg
create_bd_addr_seg -range $ip_reg_map_range -offset $store_base_addr [get_bd_addr_spaces processing_system/Data] [get_bd_addr_segs store_0/s_axi_CONTROL_BUS/Reg] SEG_store_0_Reg
if { $device_family eq "zynq-7000" } {
  create_bd_addr_seg -range 0x40000000 -offset 0x00000000 [get_bd_addr_spaces compute_0/Data_m_axi_uop_port] [get_bd_addr_segs processing_system/S_AXI_ACP/ACP_DDR_LOWOCM] SEG_processing_system_ACP_DDR_LOWOCM
  create_bd_addr_seg -range 0x40000000 -offset 0x00000000 [get_bd_addr_spaces compute_0/Data_m_axi_data_port] [get_bd_addr_segs processing_system/S_AXI_ACP/ACP_DDR_LOWOCM] SEG_processing_system_ACP_DDR_LOWOCM
  create_bd_addr_seg -range 0x40000000 -offset 0x00000000 [get_bd_addr_spaces fetch_0/Data_m_axi_ins_port] [get_bd_addr_segs processing_system/S_AXI_ACP/ACP_DDR_LOWOCM] SEG_processing_system_ACP_DDR_LOWOCM
  create_bd_addr_seg -range 0x40000000 -offset 0x00000000 [get_bd_addr_spaces load_0/Data_m_axi_data_port] [get_bd_addr_segs processing_system/S_AXI_ACP/ACP_DDR_LOWOCM] SEG_processing_system_ACP_DDR_LOWOCM
  create_bd_addr_seg -range 0x40000000 -offset 0x00000000 [get_bd_addr_spaces store_0/Data_m_axi_data_port] [get_bd_addr_segs processing_system/S_AXI_ACP/ACP_DDR_LOWOCM] SEG_processing_system_ACP_DDR_LOWOCM
} elseif { $device_family eq "zynq-ultrascale+"} {
  create_bd_addr_seg -range 0x80000000 -offset 0x00000000 [get_bd_addr_spaces fetch_0/Data_m_axi_ins_port] [get_bd_addr_segs processing_system/SAXIGP0/HPC0_DDR_LOW] SEG_processing_system_HPC0_DDR_LOW
  create_bd_addr_seg -range 0x80000000 -offset 0x00000000 [get_bd_addr_spaces load_0/Data_m_axi_data_port] [get_bd_addr_segs processing_system/SAXIGP0/HPC0_DDR_LOW] SEG_processing_system_HPC0_DDR_LOW
  create_bd_addr_seg -range 0x80000000 -offset 0x00000000 [get_bd_addr_spaces compute_0/Data_m_axi_uop_port] [get_bd_addr_segs processing_system/SAXIGP0/HPC0_DDR_LOW] SEG_processing_system_HPC0_DDR_LOW
  create_bd_addr_seg -range 0x80000000 -offset 0x00000000 [get_bd_addr_spaces compute_0/Data_m_axi_data_port] [get_bd_addr_segs processing_system/SAXIGP0/HPC0_DDR_LOW] SEG_processing_system_HPC0_DDR_LOW
  create_bd_addr_seg -range 0x80000000 -offset 0x00000000 [get_bd_addr_spaces store_0/Data_m_axi_data_port] [get_bd_addr_segs processing_system/SAXIGP0/HPC0_DDR_LOW] SEG_processing_system_HPC0_DDR_LOW
}

save_bd_design


##################################################################
# COMPILATION FLOW
##################################################################

# Create top-level wrapper file
make_wrapper -files \
  [get_files $proj_path/$proj_name.srcs/sources_1/bd/$proj_name/$proj_name.bd] -top
add_files -norecurse $proj_path/$proj_name.srcs/sources_1/bd/$proj_name/hdl/${proj_name}_wrapper.v
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

save_bd_design
exit

# Run bistream generation on 8 threads with performance oriented P&R strategy
set num_threads 8
launch_runs impl_1 -to_step write_bitstream -jobs $num_threads
wait_on_run impl_1

# Export hardware description file and bitstream files to export/ dir
if {[file exist $proj_path/$proj_name.runs/impl_1/${proj_name}_wrapper.bit]} {
  file mkdir $proj_path/export
  file copy -force $proj_path/$proj_name.runs/impl_1/${proj_name}_wrapper.bit \
    $proj_path/export/vta.bit
}

exit
