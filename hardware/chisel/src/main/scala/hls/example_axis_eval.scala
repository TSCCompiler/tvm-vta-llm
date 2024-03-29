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

package vta.hls

import chisel3._
import chisel3.util._
import chisel3.iotesters.{Driver, PeekPokeTester}
class example_axis_TestModule extends Module{
  val io = IO(new Bundle() {
    val ap_start = Input(Bool())
    val ap_done = Output(Bool())
    val ap_idle = Output(Bool())
    val ap_ready = Output(Bool())
    val A = Flipped(DecoupledIO(UInt(32.W)))
    val B = DecoupledIO(UInt(32.W))
  })
  val u_example = Module(new ExampleAxisShell)
  u_example.io.ap_clk := clock
  u_example.io.ap_rst_n := ~reset.asUInt().asBool()
  u_example.io.ap_start := io.ap_start
  io.ap_done := u_example.io.ap_done
  io.ap_idle := u_example.io.ap_idle
  io.ap_ready := u_example.io.ap_ready
  u_example.io.A <> io.A
  io.B <> u_example.io.B
}

class Example_axis_EvalTests(c:example_axis_TestModule) extends PeekPokeTester(c) {
  poke(c.io.ap_start, 1)
  step(10)
  poke(c.io.B.ready, 1)
  for (i <- 0 until 1){
    poke(c.io.A.valid, 1)
    poke(c.io.A.bits, 50)
    step(240)
  }
}

object Example_axis_eval extends App {
  Driver.execute(Array(
    "--generate-vcd-output", "on",
    "--target-dir", s"test_run_dir/Example_axis_EvalTests",
    "--top-name", s"example_axis_TestModule",
    //      "--backend-name", "treadle",
    "--backend-name", "verilator",
  ), ()=> new example_axis_TestModule)(c=>new Example_axis_EvalTests(c))

}
