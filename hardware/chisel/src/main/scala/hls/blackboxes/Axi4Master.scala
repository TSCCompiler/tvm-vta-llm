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
import vta.shell.ShellKey
import vta.util.{ExportAxiLiteClient, ExportXilinxAxiMaster}
import vta.util.config._
import vta.{AXI4MasterConfig, DefaultCustomConfig}
class Axi4Master(implicit val p : Parameters) extends BlackBox with HasBlackBoxResource {
  val io = IO(new Bundle() {
    val ap_clk = Input(Clock())
    val ap_rst_n = Input(Bool())
    val m_axi_gmem = new XilinxAXIMaster(p(ShellKey).memParams)
    val s_axi_AXILiteS = new XilinxAXILiteClient(p(ShellKey).hostParams)
    val interrupt = Output(Bool())
  })
  addResource("/hls/axi4Master/Axi4Master.v")
  addResource("/hls/axi4Master/Axi4Master_AXILiteS_s_axi.v")
  addResource("/hls/axi4Master/Axi4Master_gmem_m_axi.v")
}
class Axi4MasterHls(implicit val p: Parameters) extends Module {
  val io = IO(new Bundle() {
    val ap_clk = Input(Clock())
    val ap_rst_n = Input(Bool())
    val m_axi_gmem = new AXIMaster(p(ShellKey).memParams)
    val s_axi_AXILiteS = new AXILiteClient(p(ShellKey).hostParams)
    val interrupt = Output(Bool())
  })
  val u_axi4_master = Module(new Axi4Master())
  u_axi4_master.io.ap_clk := io.ap_clk
  u_axi4_master.io.ap_rst_n := io.ap_rst_n
  io.interrupt := u_axi4_master.io.interrupt
  ExportAxiLiteClient(u_axi4_master.io.s_axi_AXILiteS, io.s_axi_AXILiteS)
  ExportXilinxAxiMaster(u_axi4_master.io.m_axi_gmem, io.m_axi_gmem)
}


// generate verilog here
object Axi4MasterHls_Gen extends App {
  implicit val p : Parameters = new AXI4MasterConfig
  (new ChiselStage).emitVerilog(new Axi4MasterHls, Array(
    "--target-dir",
    "test_run_dir/Axi4MasterHls"
  ))

}