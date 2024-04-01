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

 module VTAAxisDPI
 {
    input [127:0]               queue_bits,
    input                       queue_valid,
    output                      queue_ready,
 };
   import "DPI-C" function void VTAAxisDPI
   (
     input longint  unsigned    rd_bits[],
     input byte     unsigned    rd_valid,
     output byte    unsigned    rd_ready,
   );
   typedef longint      dpi_data_t  [1:0];

   dpi_data_t   __rd_value;
   dpi8_t       __rd_valid;
   dpi8_t       __rd_ready;



   integer i;
   for (i = 0; i < 2; i= i+1) begin
       assign __rd_value[i] = queue_bits[64*i +: 64]
   end
   assign __rd_valid = dpi8_t ' (queue_valid)
   assign queue_ready = dpi1_t ' (__rd_ready);

   always_ff @(posedge clock) begin
    VTAAxisDPI(__rd_value,
                __rd_valid,
                __rd_ready)
   end // always_ff

 endmodule
