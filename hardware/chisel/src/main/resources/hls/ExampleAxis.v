// ==============================================================
// RTL generated by Vivado(TM) HLS - High-Level Synthesis from C, C++ and SystemC
// Version: 2019.1
// Copyright (C) 1986-2019 Xilinx, Inc. All Rights Reserved.
// 
// ===========================================================

`timescale 1 ns / 1 ps 

(* CORE_GENERATION_INFO="example_axis,hls_ip_2019_1,{HLS_INPUT_TYPE=cxx,HLS_INPUT_FLOAT=0,HLS_INPUT_FIXED=0,HLS_INPUT_PART=xc7z020-clg484-2,HLS_INPUT_CLOCK=13.333000,HLS_INPUT_ARCH=others,HLS_SYN_CLOCK=1.966000,HLS_SYN_LAT=-1,HLS_SYN_TPT=none,HLS_SYN_MEM=0,HLS_SYN_DSP=0,HLS_SYN_FF=267,HLS_SYN_LUT=111,HLS_VERSION=2019_1}" *)

module ExampleAxis (
        ap_clk,
        ap_rst_n,
        ap_start,
        ap_done,
        ap_idle,
        ap_ready,
        A_V_TDATA,
        A_V_TVALID,
        A_V_TREADY,
        B_V_TDATA,
        B_V_TVALID,
        B_V_TREADY
);

parameter    ap_ST_fsm_state1 = 5'd1;
parameter    ap_ST_fsm_state2 = 5'd2;
parameter    ap_ST_fsm_state3 = 5'd4;
parameter    ap_ST_fsm_state4 = 5'd8;
parameter    ap_ST_fsm_state5 = 5'd16;

input   ap_clk;
input   ap_rst_n;
input   ap_start;
output   ap_done;
output   ap_idle;
output   ap_ready;
input  [31:0] A_V_TDATA;
input   A_V_TVALID;
output   A_V_TREADY;
output  [31:0] B_V_TDATA;
output   B_V_TVALID;
input   B_V_TREADY;

reg ap_done;
reg ap_idle;
reg ap_ready;

 reg    ap_rst_n_inv;
(* fsm_encoding = "none" *) reg   [4:0] ap_CS_fsm;
wire    ap_CS_fsm_state1;
reg   [31:0] A_V_0_data_out;
wire    A_V_0_vld_in;
wire    A_V_0_vld_out;
wire    A_V_0_ack_in;
reg    A_V_0_ack_out;
reg   [31:0] A_V_0_payload_A;
reg   [31:0] A_V_0_payload_B;
reg    A_V_0_sel_rd;
reg    A_V_0_sel_wr;
wire    A_V_0_sel;
wire    A_V_0_load_A;
wire    A_V_0_load_B;
reg   [1:0] A_V_0_state;
wire    A_V_0_state_cmp_full;
reg   [31:0] B_V_1_data_out;
reg    B_V_1_vld_in;
wire    B_V_1_vld_out;
wire    B_V_1_ack_in;
wire    B_V_1_ack_out;
reg   [31:0] B_V_1_payload_A;
reg   [31:0] B_V_1_payload_B;
reg    B_V_1_sel_rd;
reg    B_V_1_sel_wr;
wire    B_V_1_sel;
wire    B_V_1_load_A;
wire    B_V_1_load_B;
reg   [1:0] B_V_1_state;
wire    B_V_1_state_cmp_full;
reg    A_V_TDATA_blk_n;
wire    ap_CS_fsm_state3;
reg    B_V_TDATA_blk_n;
wire    ap_CS_fsm_state4;
wire    ap_CS_fsm_state5;
reg   [31:0] tmp_1_reg_98;
reg    ap_block_state1;
wire   [30:0] add_ln97_fu_86_p2;
reg   [30:0] add_ln97_reg_106;
wire    ap_CS_fsm_state2;
wire   [31:0] ret_fu_92_p2;
reg   [31:0] tmp_reg_53;
reg   [30:0] i_0_i_reg_66;
wire   [31:0] zext_ln97_fu_77_p1;
wire   [0:0] icmp_ln97_fu_81_p2;
reg    ap_block_state5;
reg   [4:0] ap_NS_fsm;

// power-on initialization
initial begin
#0 ap_CS_fsm = 5'd1;
#0 A_V_0_sel_rd = 1'b0;
#0 A_V_0_sel_wr = 1'b0;
#0 A_V_0_state = 2'd0;
#0 B_V_1_sel_rd = 1'b0;
#0 B_V_1_sel_wr = 1'b0;
#0 B_V_1_state = 2'd0;
end

always @ (posedge ap_clk) begin
    if (ap_rst_n_inv == 1'b1) begin
        A_V_0_sel_rd <= 1'b0;
    end else begin
        if (((1'b1 == A_V_0_ack_out) & (1'b1 == A_V_0_vld_out))) begin
            A_V_0_sel_rd <= ~A_V_0_sel_rd;
        end
    end
end

always @ (posedge ap_clk) begin
    if (ap_rst_n_inv == 1'b1) begin
        A_V_0_sel_wr <= 1'b0;
    end else begin
        if (((1'b1 == A_V_0_ack_in) & (1'b1 == A_V_0_vld_in))) begin
            A_V_0_sel_wr <= ~A_V_0_sel_wr;
        end
    end
end

always @ (posedge ap_clk) begin
    if (ap_rst_n_inv == 1'b1) begin
        A_V_0_state <= 2'd0;
    end else begin
        if ((((2'd2 == A_V_0_state) & (1'b0 == A_V_0_vld_in)) | ((2'd3 == A_V_0_state) & (1'b0 == A_V_0_vld_in) & (1'b1 == A_V_0_ack_out)))) begin
            A_V_0_state <= 2'd2;
        end else if ((((2'd1 == A_V_0_state) & (1'b0 == A_V_0_ack_out)) | ((2'd3 == A_V_0_state) & (1'b0 == A_V_0_ack_out) & (1'b1 == A_V_0_vld_in)))) begin
            A_V_0_state <= 2'd1;
        end else if (((~((1'b0 == A_V_0_vld_in) & (1'b1 == A_V_0_ack_out)) & ~((1'b0 == A_V_0_ack_out) & (1'b1 == A_V_0_vld_in)) & (2'd3 == A_V_0_state)) | ((2'd1 == A_V_0_state) & (1'b1 == A_V_0_ack_out)) | ((2'd2 == A_V_0_state) & (1'b1 == A_V_0_vld_in)))) begin
            A_V_0_state <= 2'd3;
        end else begin
            A_V_0_state <= 2'd2;
        end
    end
end

always @ (posedge ap_clk) begin
    if (ap_rst_n_inv == 1'b1) begin
        B_V_1_sel_rd <= 1'b0;
    end else begin
        if (((1'b1 == B_V_1_ack_out) & (1'b1 == B_V_1_vld_out))) begin
            B_V_1_sel_rd <= ~B_V_1_sel_rd;
        end
    end
end

always @ (posedge ap_clk) begin
    if (ap_rst_n_inv == 1'b1) begin
        B_V_1_sel_wr <= 1'b0;
    end else begin
        if (((1'b1 == B_V_1_ack_in) & (1'b1 == B_V_1_vld_in))) begin
            B_V_1_sel_wr <= ~B_V_1_sel_wr;
        end
    end
end

always @ (posedge ap_clk) begin
    if (ap_rst_n_inv == 1'b1) begin
        B_V_1_state <= 2'd0;
    end else begin
        if ((((2'd2 == B_V_1_state) & (1'b0 == B_V_1_vld_in)) | ((2'd3 == B_V_1_state) & (1'b0 == B_V_1_vld_in) & (1'b1 == B_V_1_ack_out)))) begin
            B_V_1_state <= 2'd2;
        end else if ((((2'd1 == B_V_1_state) & (1'b0 == B_V_TREADY)) | ((2'd3 == B_V_1_state) & (1'b0 == B_V_TREADY) & (1'b1 == B_V_1_vld_in)))) begin
            B_V_1_state <= 2'd1;
        end else if (((~((1'b0 == B_V_1_vld_in) & (1'b1 == B_V_1_ack_out)) & ~((1'b0 == B_V_TREADY) & (1'b1 == B_V_1_vld_in)) & (2'd3 == B_V_1_state)) | ((2'd1 == B_V_1_state) & (1'b1 == B_V_1_ack_out)) | ((2'd2 == B_V_1_state) & (1'b1 == B_V_1_vld_in)))) begin
            B_V_1_state <= 2'd3;
        end else begin
            B_V_1_state <= 2'd2;
        end
    end
end

always @ (posedge ap_clk) begin
    if (ap_rst_n_inv == 1'b1) begin
        ap_CS_fsm <= ap_ST_fsm_state1;
    end else begin
        ap_CS_fsm <= ap_NS_fsm;
    end
end

always @ (posedge ap_clk) begin
    if (((1'b1 == A_V_0_vld_out) & (1'b1 == ap_CS_fsm_state3))) begin
        i_0_i_reg_66 <= add_ln97_reg_106;
    end else if ((~((1'b0 == A_V_0_vld_out) | (ap_start == 1'b0)) & (1'b1 == ap_CS_fsm_state1))) begin
        i_0_i_reg_66 <= 31'd0;
    end
end

always @ (posedge ap_clk) begin
    if (((1'b1 == A_V_0_vld_out) & (1'b1 == ap_CS_fsm_state3))) begin
        tmp_reg_53 <= ret_fu_92_p2;
    end else if ((~((1'b0 == A_V_0_vld_out) | (ap_start == 1'b0)) & (1'b1 == ap_CS_fsm_state1))) begin
        tmp_reg_53 <= 32'd0;
    end
end

always @ (posedge ap_clk) begin
    if ((1'b1 == A_V_0_load_A)) begin
        A_V_0_payload_A <= A_V_TDATA;
    end
end

always @ (posedge ap_clk) begin
    if ((1'b1 == A_V_0_load_B)) begin
        A_V_0_payload_B <= A_V_TDATA;
    end
end

always @ (posedge ap_clk) begin
    if ((1'b1 == B_V_1_load_A)) begin
        B_V_1_payload_A <= tmp_reg_53;
    end
end

always @ (posedge ap_clk) begin
    if ((1'b1 == B_V_1_load_B)) begin
        B_V_1_payload_B <= tmp_reg_53;
    end
end

always @ (posedge ap_clk) begin
    if ((1'b1 == ap_CS_fsm_state2)) begin
        add_ln97_reg_106 <= add_ln97_fu_86_p2;
    end
end

always @ (posedge ap_clk) begin
    if ((~((1'b0 == A_V_0_vld_out) | (ap_start == 1'b0)) & (1'b1 == ap_CS_fsm_state1))) begin
        tmp_1_reg_98 <= A_V_0_data_out;
    end
end

always @ (*) begin
    if (((~((1'b0 == A_V_0_vld_out) | (ap_start == 1'b0)) & (1'b1 == ap_CS_fsm_state1)) | ((1'b1 == A_V_0_vld_out) & (1'b1 == ap_CS_fsm_state3)))) begin
        A_V_0_ack_out = 1'b1;
    end else begin
        A_V_0_ack_out = 1'b0;
    end
end

always @ (*) begin
    if ((1'b1 == A_V_0_sel)) begin
        A_V_0_data_out = A_V_0_payload_B;
    end else begin
        A_V_0_data_out = A_V_0_payload_A;
    end
end

always @ (*) begin
    if (((1'b1 == ap_CS_fsm_state3) | ((1'b1 == ap_CS_fsm_state1) & (ap_start == 1'b1)))) begin
        A_V_TDATA_blk_n = A_V_0_state[1'd0];
    end else begin
        A_V_TDATA_blk_n = 1'b1;
    end
end

always @ (*) begin
    if ((1'b1 == B_V_1_sel)) begin
        B_V_1_data_out = B_V_1_payload_B;
    end else begin
        B_V_1_data_out = B_V_1_payload_A;
    end
end

always @ (*) begin
    if (((1'b1 == ap_CS_fsm_state4) & (1'b1 == B_V_1_ack_in))) begin
        B_V_1_vld_in = 1'b1;
    end else begin
        B_V_1_vld_in = 1'b0;
    end
end

always @ (*) begin
    if (((1'b1 == ap_CS_fsm_state5) | (1'b1 == ap_CS_fsm_state4))) begin
        B_V_TDATA_blk_n = B_V_1_state[1'd1];
    end else begin
        B_V_TDATA_blk_n = 1'b1;
    end
end

always @ (*) begin
    if ((~((2'd1 == B_V_1_state) | (1'b0 == B_V_1_ack_in) | ((2'd3 == B_V_1_state) & (1'b0 == B_V_TREADY))) & (1'b1 == ap_CS_fsm_state5))) begin
        ap_done = 1'b1;
    end else begin
        ap_done = 1'b0;
    end
end

always @ (*) begin
    if (((ap_start == 1'b0) & (1'b1 == ap_CS_fsm_state1))) begin
        ap_idle = 1'b1;
    end else begin
        ap_idle = 1'b0;
    end
end

always @ (*) begin
    if ((~((2'd1 == B_V_1_state) | (1'b0 == B_V_1_ack_in) | ((2'd3 == B_V_1_state) & (1'b0 == B_V_TREADY))) & (1'b1 == ap_CS_fsm_state5))) begin
        ap_ready = 1'b1;
    end else begin
        ap_ready = 1'b0;
    end
end

always @ (*) begin
    case (ap_CS_fsm)
        ap_ST_fsm_state1 : begin
            if ((~((1'b0 == A_V_0_vld_out) | (ap_start == 1'b0)) & (1'b1 == ap_CS_fsm_state1))) begin
                ap_NS_fsm = ap_ST_fsm_state2;
            end else begin
                ap_NS_fsm = ap_ST_fsm_state1;
            end
        end
        ap_ST_fsm_state2 : begin
            if (((icmp_ln97_fu_81_p2 == 1'd1) & (1'b1 == ap_CS_fsm_state2))) begin
                ap_NS_fsm = ap_ST_fsm_state3;
            end else begin
                ap_NS_fsm = ap_ST_fsm_state4;
            end
        end
        ap_ST_fsm_state3 : begin
            if (((1'b1 == A_V_0_vld_out) & (1'b1 == ap_CS_fsm_state3))) begin
                ap_NS_fsm = ap_ST_fsm_state2;
            end else begin
                ap_NS_fsm = ap_ST_fsm_state3;
            end
        end
        ap_ST_fsm_state4 : begin
            if (((1'b1 == ap_CS_fsm_state4) & (1'b1 == B_V_1_ack_in))) begin
                ap_NS_fsm = ap_ST_fsm_state5;
            end else begin
                ap_NS_fsm = ap_ST_fsm_state4;
            end
        end
        ap_ST_fsm_state5 : begin
            if ((~((2'd1 == B_V_1_state) | (1'b0 == B_V_1_ack_in) | ((2'd3 == B_V_1_state) & (1'b0 == B_V_TREADY))) & (1'b1 == ap_CS_fsm_state5))) begin
                ap_NS_fsm = ap_ST_fsm_state1;
            end else begin
                ap_NS_fsm = ap_ST_fsm_state5;
            end
        end
        default : begin
            ap_NS_fsm = 'bx;
        end
    endcase
end

assign A_V_0_ack_in = A_V_0_state[1'd1];

assign A_V_0_load_A = (~A_V_0_sel_wr & A_V_0_state_cmp_full);

assign A_V_0_load_B = (A_V_0_state_cmp_full & A_V_0_sel_wr);

assign A_V_0_sel = A_V_0_sel_rd;

assign A_V_0_state_cmp_full = ((A_V_0_state != 2'd1) ? 1'b1 : 1'b0);

assign A_V_0_vld_in = A_V_TVALID;

assign A_V_0_vld_out = A_V_0_state[1'd0];

assign A_V_TREADY = A_V_0_state[1'd1];

assign B_V_1_ack_in = B_V_1_state[1'd1];

assign B_V_1_ack_out = B_V_TREADY;

assign B_V_1_load_A = (~B_V_1_sel_wr & B_V_1_state_cmp_full);

assign B_V_1_load_B = (B_V_1_state_cmp_full & B_V_1_sel_wr);

assign B_V_1_sel = B_V_1_sel_rd;

assign B_V_1_state_cmp_full = ((B_V_1_state != 2'd1) ? 1'b1 : 1'b0);

assign B_V_1_vld_out = B_V_1_state[1'd0];

assign B_V_TDATA = B_V_1_data_out;

assign B_V_TVALID = B_V_1_state[1'd0];

assign add_ln97_fu_86_p2 = (i_0_i_reg_66 + 31'd1);

assign ap_CS_fsm_state1 = ap_CS_fsm[32'd0];

assign ap_CS_fsm_state2 = ap_CS_fsm[32'd1];

assign ap_CS_fsm_state3 = ap_CS_fsm[32'd2];

assign ap_CS_fsm_state4 = ap_CS_fsm[32'd3];

assign ap_CS_fsm_state5 = ap_CS_fsm[32'd4];

always @ (*) begin
    ap_block_state1 = ((1'b0 == A_V_0_vld_out) | (ap_start == 1'b0));
end

always @ (*) begin
    ap_block_state5 = ((2'd1 == B_V_1_state) | ((2'd3 == B_V_1_state) & (1'b0 == B_V_TREADY)));
end

always @ (*) begin
    ap_rst_n_inv = ~ap_rst_n;
end

assign icmp_ln97_fu_81_p2 = (($signed(zext_ln97_fu_77_p1) < $signed(tmp_1_reg_98)) ? 1'b1 : 1'b0);

assign ret_fu_92_p2 = (A_V_0_data_out + tmp_reg_53);

assign zext_ln97_fu_77_p1 = i_0_i_reg_66;

endmodule //example_axis