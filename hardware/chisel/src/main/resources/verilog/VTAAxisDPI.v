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
 (
    input                        clock,
    input                        reset,
    input [127:0]               queue_bits,
    input                       queue_valid,
    output                      queue_ready,
    output [7:0]                recv_cnt
 );
   import "DPI-C" function void VTAAxisDPI
   (
     input longint  unsigned    rd_bits[],
     input byte     unsigned    rd_valid,
     output byte    unsigned    rd_ready,
   );
   typedef longint      dpi_data_t  [1:0];
   typedef logic        dpi1_t;
   typedef logic  [7:0] dpi8_t;
   typedef logic [31:0] dpi32_t;

   dpi_data_t   __rd_value;
   dpi8_t       __rd_valid;
   dpi8_t       __rd_ready;
   dpi8_t       __recv_cnt;
   dpi1_t       __reset;

   // reset
   always_ff @(posedge clock) begin
        __reset <= reset;
   end


   always_ff @(posedge clock) begin
        if (reset ) begin
            __recv_cnt = 0;
            __rd_ready = 1;
        end
        else begin
            VTAAxisDPI(__rd_value,
                                __rd_valid,
                                __rd_ready);
            if(queue_valid) begin
                __recv_cnt = __recv_cnt+1;
            end


        end
   end // always_ff

  genvar i;
  generate
  for (i = 0; i < 2; i= i+1) begin
      assign __rd_value[i] = queue_bits[64*i +: 64];
  end
  endgenerate
  assign __rd_valid = dpi8_t ' (queue_valid);
  assign queue_ready = dpi1_t ' (__rd_ready);
  assign recv_cnt = __recv_cnt;

 endmodule
