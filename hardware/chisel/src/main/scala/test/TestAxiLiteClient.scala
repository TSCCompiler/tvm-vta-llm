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
import vta.shell.ShellKey
import vta.util.config.Parameters
import vta._

class DummyHostAxiLiteMaster(implicit val p : Parameters) extends Module{
  val io = IO(new Bundle() {
    val ap_clk = Input(Clock())
    val ap_rst_n = Input(Bool())
    val host_reg = new AXILiteMaster(p(ShellKey).hostParams)
    val interrupt = Input(Bool())
  })
  io.host_reg.tieoff()
}

class SimAxiliteModule extends Module {
  implicit val p : Parameters = new DefaultCustomConfig
  val io = IO(new Bundle() {
    val interrupt = Output(Bool())
  })
  val u_dummy = Module(new DummyHostAxiLiteMaster())
  val u_calc = Module(new AxiliteExampleHls())

  u_dummy.io.ap_clk := clock
  u_dummy.io.ap_rst_n := reset.asBool()

  u_calc.io.ap_clk := clock
  u_calc.io.ap_rst_n := reset.asBool()

  u_calc.io.s_axi_BUS_A <> u_dummy.io.host_reg
  u_dummy.io.interrupt := u_calc.io.interrupt
  io.interrupt := u_calc.io.interrupt

}

class SimAxiliteModulePoker(c:SimAxiliteModule) extends PeekPokeTester(c) {
  step(100)

  val is_done = peek(c.io.interrupt)
  println(s"final outputs is $is_done")
}

object SimAxiliteModuleRunner extends App {
  Driver.execute(Array(
    "--generate-vcd-output", "on",
    "--target-dir", s"test_run_dir/SimAxiliteModuleRunner",
    "--top-name", s"SimAxiliteModule",
    //      "--backend-name", "treadle",
    "--backend-name", "verilator",
  ), ()=>new SimAxiliteModule())(
    c=>new SimAxiliteModulePoker(c)
  )
}

