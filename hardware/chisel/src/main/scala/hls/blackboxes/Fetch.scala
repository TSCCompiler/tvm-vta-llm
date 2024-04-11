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
import chisel3.stage.ChiselStage
import chisel3.util._
import vta.interface.axi._
class Fetch extends BlackBox with HasBlackBoxResource {
  val inst_v_param = AXIParams(idBits = 1, dataBits = 128)
  val control_bus_param = AXIParams(idBits = 0, dataBits = 32, addrBits = 5)
  val io = IO(new Bundle() {
    val ap_clk = Input(Clock())
    val ap_rst_n = Input(Bool())
    val m_axi_ins_port = new XilinxAXIMaster(inst_v_param)
//    val load_queue_V_V = DecoupledIO(UInt(128.W))
    val load_queue_V_V_TDATA = Output(UInt(128.W))
    val load_queue_V_V_TVALID = Output(Bool())
    val load_queue_V_V_TREADY = Input(Bool())
//    val gemm_queue_V_V = DecoupledIO(UInt(128.W))
    val gemm_queue_V_V_TDATA = Output(UInt(128.W))
    val gemm_queue_V_V_TVALID = Output(Bool())
    val gemm_queue_V_V_TREADY = Input(Bool())
//    val store_queue_V_V = DecoupledIO(UInt(128.W))
    val store_queue_V_V_TDATA = Output(UInt(128.W))
    val store_queue_V_V_TVALID = Output(Bool())
    val store_queue_V_V_TREADY = Input(Bool())
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
//  connectAxiMasterXilinx(io.instr, u_fetch.io.m_axi_ins_port)
  exportAxiMasterXilinx(io.instr, u_fetch.io.m_axi_ins_port)
  exportAxiLite(u_fetch.io.s_axi_CONTROL_BUS, io.control_bus)

////  u_fetch.io.m_axi_ins_port.AWVALID := io.instr.aw.valid
//  io.instr.aw.valid := u_fetch.io.m_axi_ins_port.AWVALID
  io.load_queue.bits := u_fetch.io.load_queue_V_V_TDATA
  io.load_queue.valid := u_fetch.io.load_queue_V_V_TVALID
  u_fetch.io.load_queue_V_V_TREADY := io.load_queue.ready

  io.gemm_queue.bits := u_fetch.io.gemm_queue_V_V_TDATA
  io.gemm_queue.valid := u_fetch.io.gemm_queue_V_V_TVALID
  u_fetch.io.gemm_queue_V_V_TREADY := io.gemm_queue.ready


  io.store_queue.bits := u_fetch.io.store_queue_V_V_TDATA
  io.store_queue.valid := u_fetch.io.store_queue_V_V_TVALID
  u_fetch.io.store_queue_V_V_TREADY := io.store_queue.ready
  io.interrupt := u_fetch.io.interrupt


//  connectAxiLite(u_fetch.io.s_axi_CONTROL_BUS, io.control_bus)

  def connectAxiMasterXilinx(instr: AXIMaster, m_axi_gmem: XilinxAXIMaster): Unit = {
    // memory
    m_axi_gmem.AWVALID := instr.aw.valid
    instr.aw.ready := m_axi_gmem.AWREADY
    m_axi_gmem.AWADDR := instr.aw.bits.addr
    m_axi_gmem.AWID := instr.aw.bits.id
    m_axi_gmem.AWUSER := instr.aw.bits.user
    m_axi_gmem.AWLEN := instr.aw.bits.len
    m_axi_gmem.AWSIZE := instr.aw.bits.size
    m_axi_gmem.AWBURST := instr.aw.bits.burst
    m_axi_gmem.AWLOCK := instr.aw.bits.lock
    m_axi_gmem.AWCACHE := instr.aw.bits.cache
    m_axi_gmem.AWPROT := instr.aw.bits.prot
    m_axi_gmem.AWQOS := instr.aw.bits.qos
    m_axi_gmem.AWREGION := instr.aw.bits.region

    m_axi_gmem.WVALID := instr.w.valid
    instr.w.ready := m_axi_gmem.WREADY
    m_axi_gmem.WDATA := instr.w.bits.data
    m_axi_gmem.WSTRB := instr.w.bits.strb
    m_axi_gmem.WLAST := instr.w.bits.last
    m_axi_gmem.WID := instr.w.bits.id
    m_axi_gmem.WUSER := instr.w.bits.user

    instr.b.valid := m_axi_gmem.BVALID
    m_axi_gmem.BREADY := instr.b.valid
    instr.b.bits.resp := m_axi_gmem.BRESP
    instr.b.bits.id := m_axi_gmem.BID
    instr.b.bits.user := m_axi_gmem.BUSER

    m_axi_gmem.ARVALID := instr.ar.valid
    instr.ar.ready := m_axi_gmem.ARREADY
    m_axi_gmem.ARADDR := instr.ar.bits.addr
    m_axi_gmem.ARID := instr.ar.bits.id
    m_axi_gmem.ARUSER := instr.ar.bits.user
    m_axi_gmem.ARLEN := instr.ar.bits.len
    m_axi_gmem.ARSIZE := instr.ar.bits.size
    m_axi_gmem.ARBURST := instr.ar.bits.burst
    m_axi_gmem.ARLOCK := instr.ar.bits.lock
    m_axi_gmem.ARCACHE := instr.ar.bits.cache
    m_axi_gmem.ARPROT := instr.ar.bits.prot
    m_axi_gmem.ARQOS := instr.ar.bits.qos
    m_axi_gmem.ARREGION := instr.ar.bits.region

    instr.r.valid := m_axi_gmem.RVALID
    m_axi_gmem.RREADY := instr.r.ready
    instr.r.bits.data := m_axi_gmem.RDATA
    instr.r.bits.resp := m_axi_gmem.RRESP
    instr.r.bits.last := m_axi_gmem.RLAST
    instr.r.bits.id := m_axi_gmem.RID
    instr.r.bits.user := m_axi_gmem.RUSER

  }
  def exportAxiMasterXilinx(instr: AXIMaster, m_axi_gmem: XilinxAXIMaster): Unit = {
    // memory

    instr.aw.valid            := m_axi_gmem.AWVALID
    m_axi_gmem.AWREADY        :=instr.aw.ready
    instr.aw.bits.addr        :=m_axi_gmem.AWADDR
    instr.aw.bits.id          :=m_axi_gmem.AWID
    instr.aw.bits.user        :=m_axi_gmem.AWUSER
    instr.aw.bits.len         :=m_axi_gmem.AWLEN
    instr.aw.bits.size        :=m_axi_gmem.AWSIZE
    instr.aw.bits.burst       :=m_axi_gmem.AWBURST
    instr.aw.bits.lock        :=m_axi_gmem.AWLOCK
    instr.aw.bits.cache       :=m_axi_gmem.AWCACHE
    instr.aw.bits.prot        :=m_axi_gmem.AWPROT
    instr.aw.bits.qos         :=m_axi_gmem.AWQOS
    instr.aw.bits.region      :=m_axi_gmem.AWREGION
    instr.w.valid             :=m_axi_gmem.WVALID
    m_axi_gmem.WREADY         :=instr.w.ready
    instr.w.bits.data         :=m_axi_gmem.WDATA
    instr.w.bits.strb         :=m_axi_gmem.WSTRB
    instr.w.bits.last         :=m_axi_gmem.WLAST
    instr.w.bits.id           :=m_axi_gmem.WID
    instr.w.bits.user         :=m_axi_gmem.WUSER
    m_axi_gmem.BVALID         :=instr.b.valid
    instr.b.ready         := m_axi_gmem.BREADY
    m_axi_gmem.BRESP          :=instr.b.bits.resp
    m_axi_gmem.BID            :=instr.b.bits.id
    m_axi_gmem.BUSER          :=instr.b.bits.user
    instr.ar.valid            :=m_axi_gmem.ARVALID
    m_axi_gmem.ARREADY        :=instr.ar.ready
    instr.ar.bits.addr        :=m_axi_gmem.ARADDR
    instr.ar.bits.id          :=m_axi_gmem.ARID
    instr.ar.bits.user        :=m_axi_gmem.ARUSER
    instr.ar.bits.len         :=m_axi_gmem.ARLEN
    instr.ar.bits.size        :=m_axi_gmem.ARSIZE
    instr.ar.bits.burst       :=m_axi_gmem.ARBURST
    instr.ar.bits.lock        :=m_axi_gmem.ARLOCK
    instr.ar.bits.cache       :=m_axi_gmem.ARCACHE
    instr.ar.bits.prot        :=m_axi_gmem.ARPROT
    instr.ar.bits.qos         :=m_axi_gmem.ARQOS
    instr.ar.bits.region      :=m_axi_gmem.ARREGION
    m_axi_gmem.RVALID         :=instr.r.valid
    instr.r.ready             :=m_axi_gmem.RREADY
    m_axi_gmem.RDATA          :=instr.r.bits.data
    m_axi_gmem.RRESP          :=instr.r.bits.resp
    m_axi_gmem.RLAST          :=instr.r.bits.last
    m_axi_gmem.RID            :=instr.r.bits.id
    m_axi_gmem.RUSER          :=instr.r.bits.user
  }
  def connectAxiLite(s_axi_control : XilinxAXILiteClient, host : AXILiteClient): Unit = {
    // host
    host.aw.valid := s_axi_control.AWVALID
    s_axi_control.AWREADY := host.aw.ready
    host.aw.bits.addr := s_axi_control.AWADDR

    host.w.valid := s_axi_control.WVALID
    s_axi_control.WREADY := host.w.ready
    host.w.bits.data := s_axi_control.WDATA
    host.w.bits.strb := s_axi_control.WSTRB

    s_axi_control.BVALID := host.b.valid
    host.b.ready := s_axi_control.BREADY
    s_axi_control.BRESP := host.b.bits.resp

    host.ar.valid := s_axi_control.ARVALID
    s_axi_control.ARREADY := host.ar.ready
    host.ar.bits.addr := s_axi_control.ARADDR

    s_axi_control.RVALID := host.r.valid
    host.r.ready := s_axi_control.RREADY
    s_axi_control.RDATA := host.r.bits.data
    s_axi_control.RRESP := host.r.bits.resp
  }

  def exportAxiLite(s_axi_control : XilinxAXILiteClient, host : AXILiteClient): Unit = {
    // host
    s_axi_control.AWVALID   := host.aw.valid
    host.aw.ready           :=s_axi_control.AWREADY
    s_axi_control.AWADDR    :=host.aw.bits.addr
    s_axi_control.WVALID    :=host.w.valid
    host.w.ready            :=s_axi_control.WREADY
    s_axi_control.WDATA     :=host.w.bits.data
    s_axi_control.WSTRB     :=host.w.bits.strb
    host.b.valid            :=s_axi_control.BVALID
    s_axi_control.BREADY    :=host.b.ready
    host.b.bits.resp        :=s_axi_control.BRESP
    s_axi_control.ARVALID   :=host.ar.valid
    host.ar.ready           :=s_axi_control.ARREADY
    s_axi_control.ARADDR    :=host.ar.bits.addr
    host.r.valid            :=s_axi_control.RVALID
    s_axi_control.RREADY    :=host.r.ready
    host.r.bits.data        :=s_axi_control.RDATA
    host.r.bits.resp        :=s_axi_control.RRESP
  }

}

// generate verilog here
object FetchHls_Gen extends App {
  (new ChiselStage).emitVerilog(new FetchHls, Array(
    "--target-dir",
    "test_run_dir/FetchHls"
  ))

}
