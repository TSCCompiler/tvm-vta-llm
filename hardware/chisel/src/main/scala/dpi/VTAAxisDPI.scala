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
package vta.dpi
import chisel3._
import chisel3.util._
class VTAAxisDPI(user_id: Int, data_len: Int) extends BlackBox(Map(
  "DATA_BITS"->data_len,
  "USER_ID"->user_id
)) with HasBlackBoxResource {

  val io = IO(new Bundle() {
    val clock = Input(Clock())
    val reset = Input(Bool())
    val queue = Flipped(DecoupledIO(UInt(data_len.W)))
    val recv_cnt = Output(UInt(8.W))
//    val user_id = Output(UInt(32.W))
  })
  addResource("/verilog/VTAAxisDPI.v")

}
