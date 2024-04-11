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
package vta.util

import vta.interface.axi.{AXILiteClient, XilinxAXILiteClient}

object ExportAxiLiteClient {
  def apply(s_axi_control : XilinxAXILiteClient, host : AXILiteClient): Unit = {
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
