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
package vta.test

import chisel3._
import chisel3.iotesters.{Driver, PeekPokeTester}
import chisel3.stage.ChiselStage
import chisel3.util._
import vta.dpi._
import vta.hls.blackboxes._
import vta.interface.axi.{AXIClient, AXILiteMaster, AXIParams}
import vta.shell.{ShellKey, VTAHost, VTAHostSim, VTAMemSim}
import vta.util.config.Parameters
import vta._

class DummyHostLiteMem(implicit val p: Parameters) extends Module {
  val io = IO(new Bundle() {
    val ap_clk = Input(Clock())
    val ap_rst_n = Input(Bool())
    val host_reg = new AXILiteMaster(p(ShellKey).hostParams)
    val host_mem = new AXIClient(p(ShellKey).memParams)
  })
  io.host_reg.tieoff()
  io.host_mem.tieoff()
}

class SimAxi4MasterModule extends Module {
  implicit val p : Parameters = new AXI4MasterConfig
  val io = IO(new Bundle() {
    val interrupted = Output(Bool())
  })
  val u_dummy = Module(new DummyHostLiteMem())
  val u_calc = Module(new Axi4MasterHls())

  u_dummy.io.ap_clk := clock
  u_dummy.io.ap_rst_n := ~reset.asBool()

  u_calc.io.ap_clk := clock
  u_calc.io.ap_rst_n := ~reset.asBool()

  u_calc.io.s_axi_AXILiteS <> u_dummy.io.host_reg
  u_dummy.io.host_mem <> u_calc.io.m_axi_gmem

  io.interrupted := u_calc.io.interrupt
}

class DPISimAxi4MasterModule extends Module {
  implicit val p : Parameters = new AXI4MasterConfig
  val io = IO(new Bundle() {
    val interrupt = Output(Bool())
  })
  val u_host_mem = Module(new VTAMemSim())
  val u_host_slite = Module(new VTAHostSim())
  val u_calc = Module(new Axi4MasterHls())

  u_calc.io.ap_clk := clock
  u_calc.io.ap_rst_n := ~reset.asBool()

  u_host_mem.io.ap_clk := clock
  u_host_mem.io.ap_rst := reset.asBool()

  u_host_slite.io.ap_clk := clock
  u_host_slite.io.ap_rst_n := reset.asBool()

  io.interrupt := u_calc.io.interrupt

  u_calc.io.s_axi_AXILiteS <> u_host_slite.io.axi
  u_host_mem.io.axi <> u_calc.io.m_axi_gmem

}
//.\BinDeply\test_loader.exe ../uploads/ppe_infer/xxx.json main
object DPISimAxi4MasterModuleVeri extends App {
  (new ChiselStage).emitVerilog(new DPISimAxi4MasterModule, Array(
    "--target-dir",
    "test_run_dir/DPISimAxi4MasterModule"
  ))
}
class SimAxi4MasterModulePoker(c:SimAxi4MasterModule) extends PeekPokeTester(c) {
  step(100)

  val is_done = peek(c.io.interrupted)
  println(s"final outputs is $is_done")
}

object SimAxi4MasterModulePokerRunner extends App {
  Driver.execute(Array(
    "--generate-vcd-output", "on",
    "--target-dir", s"test_run_dir/SimAxi4MasterModulePokerRunner",
    "--top-name", s"SimAxi4MasterModule",
    //      "--backend-name", "treadle",
    "--backend-name", "verilator",
  ), ()=>new SimAxi4MasterModule())(
    c=>new SimAxi4MasterModulePoker(c)
  )
}

class TestAxi4Master {

}
