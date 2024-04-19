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

import vta.interface.axi.{AXILiteClient, XilinxAXILiteClient, AXIMaster, XilinxAXIMaster}

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

object ExportXilinxAxiMaster {
  def apply(m_axi_gmem : XilinxAXIMaster, mem : AXIMaster): Unit = {
    // memory
    mem.aw.valid        :=  m_axi_gmem.AWVALID
    m_axi_gmem.AWREADY  :=  mem.aw.ready

    //////////////////////////////////////////////////////////////////////////////////
    mem.aw.bits.addr    := m_axi_gmem.AWADDR
    mem.aw.bits.id      := m_axi_gmem.AWID
    mem.aw.bits.user    := m_axi_gmem.AWUSER
    mem.aw.bits.len     := m_axi_gmem.AWLEN
    mem.aw.bits.size    := m_axi_gmem.AWSIZE
    mem.aw.bits.burst   := m_axi_gmem.AWBURST
    mem.aw.bits.lock    := m_axi_gmem.AWLOCK
    mem.aw.bits.cache   := m_axi_gmem.AWCACHE
    mem.aw.bits.prot    := m_axi_gmem.AWPROT
    mem.aw.bits.qos     := m_axi_gmem.AWQOS
    mem.aw.bits.region  := m_axi_gmem.AWREGION
    mem.w.valid         := m_axi_gmem.WVALID
    m_axi_gmem.WREADY   := mem.w.ready
    mem.w.bits.data     := m_axi_gmem.WDATA
    mem.w.bits.strb     := m_axi_gmem.WSTRB
    mem.w.bits.last     := m_axi_gmem.WLAST
    mem.w.bits.id       := m_axi_gmem.WID
    mem.w.bits.user     := m_axi_gmem.WUSER
    m_axi_gmem.BVALID   := mem.b.valid
    mem.b.ready         := m_axi_gmem.BREADY
    m_axi_gmem.BRESP    := mem.b.bits.resp
    m_axi_gmem.BID      := mem.b.bits.id
    m_axi_gmem.BUSER    := mem.b.bits.user
    mem.ar.valid        := m_axi_gmem.ARVALID
    m_axi_gmem.ARREADY  := mem.ar.ready
    mem.ar.bits.addr    := m_axi_gmem.ARADDR
    mem.ar.bits.id      := m_axi_gmem.ARID
    mem.ar.bits.user    := m_axi_gmem.ARUSER
    mem.ar.bits.len     := m_axi_gmem.ARLEN
    mem.ar.bits.size    := m_axi_gmem.ARSIZE
    mem.ar.bits.burst   := m_axi_gmem.ARBURST
    mem.ar.bits.lock    := m_axi_gmem.ARLOCK
    mem.ar.bits.cache   := m_axi_gmem.ARCACHE
    mem.ar.bits.prot    := m_axi_gmem.ARPROT
    mem.ar.bits.qos     := m_axi_gmem.ARQOS
    mem.ar.bits.region  := m_axi_gmem.ARREGION
    m_axi_gmem.RVALID   := mem.r.valid
    mem.r.ready         := m_axi_gmem.RREADY
    m_axi_gmem.RDATA    := mem.r.bits.data
    m_axi_gmem.RRESP    := mem.r.bits.resp
    m_axi_gmem.RLAST    := mem.r.bits.last
    m_axi_gmem.RID      := mem.r.bits.id
    m_axi_gmem.RUSER    := mem.r.bits.user
  }
}
