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
import vta.util.ExportAxiLiteClient
import vta.util.config._
import vta.DefaultCustomConfig
class AxiliteExample(implicit val p: Parameters) extends BlackBox with HasBlackBoxResource {
  val io = IO(new Bundle() {
    val ap_clk = Input(Clock())
    val ap_rst_n = Input(Bool())
    val s_axi_BUS_A = new XilinxAXILiteClient(p(ShellKey).hostParams)
    val interrupt = Output(Bool())
  })
  addResource("/hls/axilite_example/AxiliteExample.v")
  addResource("/hls/axilite_example/AxiliteExample_BUS_A_s_axi.v")
}
class AxiliteExampleHls(implicit val p : Parameters) extends Module {
  val io = IO(new Bundle() {
    val ap_clk = Input(Clock())
    val ap_rst_n = Input(Bool())
    val s_axi_BUS_A = new AXILiteClient(p(ShellKey).hostParams)
    val interrupt = Output(Bool())
  })
  val u_axilite_exam = Module(new AxiliteExample())
  u_axilite_exam.io.ap_clk := io.ap_clk
  u_axilite_exam.io.ap_rst_n := io.ap_rst_n
  ExportAxiLiteClient(u_axilite_exam.io.s_axi_BUS_A, io.s_axi_BUS_A)
  io.interrupt := u_axilite_exam.io.interrupt
}

// generate verilog here
object AxiliteExampleHls_Gen extends App {
  implicit val p : Parameters = new DefaultCustomConfig
  (new ChiselStage).emitVerilog(new AxiliteExampleHls, Array(
    "--target-dir",
    "test_run_dir/AxiliteExampleHls"
  ))

}