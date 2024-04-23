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
import vta.{AXI4MasterConfig, AXI4FetchConfig}
import vta.dpi._
import vta.hls.blackboxes._
import vta.interface.axi.{AXIClient, AXILiteMaster, AXIParams}
import vta.util.config.Parameters
class DummyHostModule extends Module{
  val inst_v_param = AXIParams(idBits = 1, dataBits = 128)
  val control_bus_param = AXIParams(idBits = 0, dataBits = 32, addrBits = 5)
  val io = IO(new Bundle() {
    val ap_clk = Input(Clock())
    val ap_rst_n = Input(Bool())
    val host_instr = new AXIClient(inst_v_param)
    val host_control = new AXILiteMaster(control_bus_param)
    val load_queue = Flipped(DecoupledIO(UInt(128.W)))
    val gemm_queue = Flipped(DecoupledIO(UInt(128.W)))
    val store_queue = Flipped(DecoupledIO(UInt(128.W)))
    val interrupt = Input(Bool())
  })
  io.host_instr.tieoff()
  io.host_control.tieoff()
  io.load_queue.ready := false.B
  io.gemm_queue.ready := false.B
  io.store_queue.ready := false.B
}

class SimEnvModule extends Module {
  val io = IO(new Bundle() {
    val interrupt = Output(Bool())
  })
  val u_dummy_host = Module(new DummyHostModule())
  val u_fetch_hls = Module(new FetchHls())

  u_dummy_host.io.ap_clk := clock
  u_dummy_host.io.ap_rst_n := reset.asBool()

  u_fetch_hls.io.ap_clk := clock
  u_fetch_hls.io.ap_rst_n := reset.asBool()

  u_dummy_host.io.host_instr <> u_fetch_hls.io.instr
  u_fetch_hls.io.control_bus <> u_dummy_host.io.host_control
  u_dummy_host.io.load_queue <> u_fetch_hls.io.load_queue
  u_dummy_host.io.gemm_queue <> u_fetch_hls.io.gemm_queue
  u_dummy_host.io.store_queue <> u_fetch_hls.io.store_queue
  u_dummy_host.io.interrupt := u_fetch_hls.io.interrupt
  io.interrupt := u_fetch_hls.io.interrupt
}

class DPISimFetchModule extends Module {
  implicit val p : Parameters = new AXI4FetchConfig
  val io = IO(new Bundle() {
    val interrupt = Output(Bool())
  })
}

class SimEnvModulePoker(c:SimEnvModule) extends PeekPokeTester(c) {
  step(100)

  val is_done = peek(c.io.interrupt)
  println(s"final outputs is $is_done")
}

object SimEnvModuleRunner extends App {
  Driver.execute(Array(
    "--generate-vcd-output", "on",
    "--target-dir", s"test_run_dir/SimEnvModuleRunner",
    "--top-name", s"SimEnvModule",
    //      "--backend-name", "treadle",
    "--backend-name", "verilator",
  ), ()=>new SimEnvModule())(
    c=>new SimEnvModulePoker(c)
  )
}

