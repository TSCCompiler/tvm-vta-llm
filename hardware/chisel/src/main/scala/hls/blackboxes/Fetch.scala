/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package vta.hls.blackboxes

import chisel3._
import chisel3.util._
import vta.interface.axi._
class Fetch extends BlackBox with HasBlackBoxResource {
  val inst_v_param = AXIParams(idBits = 1, dataBits = 128)
  val control_bus_param = AXIParams(idBits = 0, dataBits = 32, addrBits = 5)
  val io = IO(new Bundle() {
    val ap_clk = Input(Clock())
    val ap_rst_n = Input(Bool())
    val m_axi_ins_port = new XilinxAXIMaster(inst_v_param)
    val load_queue_V_V = DecoupledIO(UInt(128.W))
    val gemm_queue_V_V = DecoupledIO(UInt(128.W))
    val store_queue_V_V = DecoupledIO(UInt(128.W))
    val s_axi_CONTROL_BUS = new XilinxAXILiteClient(control_bus_param)
    val interrupt = Output(Bool())
  })
  addResource("/hls/fetch/Fetch.v")
  addResource("/hls/fetch/fetch_CONTROL_BUS_s_axi.v")
  addResource("/hls/fetch/fetch_ins_port_m_axi.v")
}

class FetchHls extends Module{
  val inst_v_param = AXIParams(idBits = 1, dataBits = 128)
  val control_bus_param = AXIParams(idBits = 0, dataBits = 32, addrBits = 5)
  val io = IO(new Bundle() {
    val ap_clk = Input(Clock())
    val ap_rst_n = Input(Bool())
    val instr = new AXIMaster(inst_v_param)
    val load_queue = DecoupledIO(UInt(128.W))
    val gemm_queue = DecoupledIO(UInt(128.W))
    val store_queue = DecoupledIO(UInt(128.W))
    val control_bus = new AXILiteClient(control_bus_param)
    val interrupt = Output(Bool())
  })
  val u_fetch = Module(new Fetch())
  u_fetch.io.ap_clk := io.ap_clk
  u_fetch.io.ap_rst_n := io.ap_rst_n
  io.instr <> u_fetch.io.m_axi_ins_port
  io.load_queue <> u_fetch.io.load_queue_V_V
  io.gemm_queue <> u_fetch.io.gemm_queue_V_V
  io.store_queue <> u_fetch.io.store_queue_V_V
  u_fetch.io.s_axi_CONTROL_BUS <> io.control_bus
  io.interrupt := u_fetch.io.interrupt
}
