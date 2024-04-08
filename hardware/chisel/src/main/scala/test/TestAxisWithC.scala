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

class TestAxisWithC extends Module{
  val io = IO(new Bundle() {
    val clk = Input(Clock())
    val queue = DecoupledIO(UInt(128.W))
  })
  val cnt = RegInit("b0".asUInt(128.W))
  val _valid = RegInit(false.B)
  withClock(io.clk){
    when(io.queue.ready){
      cnt := cnt + "b1".asUInt(128.W)
      _valid:=true.B
      //io.queue.valid := true.B
      //io.queue.valid := RegNext(true.B, false.B)
      //io.queue.bits := cnt
    }
    io.queue.valid := _valid
    io.queue.bits := cnt
  }
}
class TestTopWithCHLS extends Module {
  val io = IO(new Bundle() {
    val queue = DecoupledIO(UInt(128.W))
    val recv_cnt = Output(UInt(8.W))
  })
  val u_axis_data_producer = Module(new TestAxisWithC)
  val u_axis_host = Module(new VTAAxisDPI)
  io.queue <> u_axis_data_producer.io.queue
  u_axis_host.io.queue <> u_axis_data_producer.io.queue
  u_axis_host.io.clock := clock
  u_axis_host.io.reset := reset.asBool()
  io.recv_cnt := u_axis_host.io.recv_cnt
  u_axis_data_producer.io.clk := clock

}
class TestTop extends Module {
  val io = IO(new Bundle() {
    val queue = DecoupledIO(UInt(128.W))
  })
  val u_axis_master = Module(new TestAxisWithC)
  u_axis_master.io.clk := clock
  io.queue <> u_axis_master.io.queue
}

class TestAxisWithCTester(c:TestTop) extends PeekPokeTester(c) {
  poke(c.io.queue.ready, 1)

  step(8)

  val data = peek(c.io.queue.bits)

  println(s"final outputs $data")

}
class TestAxisWithCHLSTester(c:TestTopWithCHLS) extends PeekPokeTester(c) {
  poke(c.io.queue.ready, 1)

  step(8)

  val data = peek(c.io.queue.bits)
  val cnt = peek(c.io.recv_cnt)

  println(s"final outputs $data and recv_cnt $cnt")

}

object Tester_Runner extends App {
  (new ChiselStage).emitVerilog(new TestTop, Array(
    "--target-dir",
    "test_run_dir/TestTopVerilog"
  ))
  Driver.execute(Array(
    "--generate-vcd-output", "on",
    "--target-dir", s"test_run_dir/TestTopAxisMaster",
    "--top-name", s"TestTop",
    //      "--backend-name", "treadle",
    "--backend-name", "verilator",

  ), ()=> new TestTop())(
    c=>new TestAxisWithCTester(c)
  )
}
object TestTopWithCHLS_Runner extends App {
  (new ChiselStage).emitVerilog(new TestTopWithCHLS, Array(
    "--target-dir",
    "test_run_dir/TestTopWithCHLS"
  ))
  Driver.execute(Array(
    "--generate-vcd-output", "on",
    "--target-dir", s"test_run_dir/TestTopWithCHLS_Runner",
    "--top-name", s"TestTop",
    //      "--backend-name", "treadle",
    "--backend-name", "verilator",

  ), ()=> new TestTopWithCHLS())(
    c=>new TestAxisWithCHLSTester(c)
  )

}
