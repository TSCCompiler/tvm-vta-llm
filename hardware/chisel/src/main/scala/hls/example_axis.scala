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
class ExampleAxis extends BlackBox with HasBlackBoxResource {
  val io = IO(new Bundle() {
    val ap_clk = Input(Clock())
    val ap_rst_n = Input(Bool())
    val ap_start = Input(Bool())
    val ap_done = Output(Bool())
    val ap_idle = Output(Bool())
    val ap_ready = Output(Bool())
    val A_V_TDATA = Input(UInt(32.W))
    val A_V_TVALID = Input(Bool())
    val A_V_TREADY = Output(Bool())

    val B_V_TDATA = Output(UInt(32.W))
    val B_V_TVALID = Output(Bool())
    val B_V_TREADY = Input(Bool())
  })
  addResource("/hls/ExampleAxis.v")
}
class ExampleAxisShell extends Module {
  val io = IO(new Bundle() {
    val ap_clk = Input(Clock())
    val ap_rst_n = Input(Bool())
    val ap_start = Input(Bool())
    val ap_done = Output(Bool())
    val ap_idle = Output(Bool())
    val ap_ready = Output(Bool())
    val A = Flipped(DecoupledIO(UInt(32.W)))
    val B = DecoupledIO(UInt(32.W))
  })
  val u_adder_axis = Module(new ExampleAxis())
  u_adder_axis.io.ap_clk := io.ap_clk
  u_adder_axis.io.ap_rst_n := io.ap_rst_n
  u_adder_axis.io.ap_start := io.ap_start
  io.ap_done := u_adder_axis.io.ap_done
  io.ap_idle := u_adder_axis.io.ap_idle
  io.ap_ready := u_adder_axis.io.ap_ready

  u_adder_axis.io.A_V_TDATA := io.A.bits
  u_adder_axis.io.A_V_TVALID := io.A.valid
  io.A.ready := u_adder_axis.io.A_V_TREADY

  io.B.bits := u_adder_axis.io.B_V_TDATA
  io.B.valid := u_adder_axis.io.B_V_TVALID
  u_adder_axis.io.B_V_TREADY := io.B.ready
}
