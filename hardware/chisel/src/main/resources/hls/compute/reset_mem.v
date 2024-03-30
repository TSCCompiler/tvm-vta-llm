// ==============================================================
// RTL generated by Vivado(TM) HLS - High-Level Synthesis from C, C++ and SystemC
// Version: 2019.1
// Copyright (C) 1986-2019 Xilinx, Inc. All Rights Reserved.
// 
// ===========================================================

`timescale 1 ns / 1 ps 

module reset_mem (
        ap_clk,
        ap_rst,
        ap_start,
        ap_done,
        ap_idle,
        ap_ready,
        sram_idx_V_read,
        range_V,
        mem_V_address0,
        mem_V_ce0,
        mem_V_we0,
        mem_V_d0,
        ap_return
);

parameter    ap_ST_fsm_state1 = 2'd1;
parameter    ap_ST_fsm_state2 = 2'd2;

input   ap_clk;
input   ap_rst;
input   ap_start;
output   ap_done;
output   ap_idle;
output   ap_ready;
input  [15:0] sram_idx_V_read;
input  [15:0] range_V;
output  [10:0] mem_V_address0;
output   mem_V_ce0;
output  [63:0] mem_V_we0;
output  [511:0] mem_V_d0;
output  [15:0] ap_return;

reg ap_done;
reg ap_idle;
reg ap_ready;
reg mem_V_ce0;
reg[63:0] mem_V_we0;

(* fsm_encoding = "none" *) reg   [1:0] ap_CS_fsm;
wire    ap_CS_fsm_state1;
wire   [15:0] add_ln37_fu_70_p2;
reg   [15:0] add_ln37_reg_108;
wire   [15:0] i_fu_81_p2;
wire    ap_CS_fsm_state2;
wire   [15:0] add_ln700_fu_92_p2;
wire   [0:0] icmp_ln37_fu_76_p2;
reg   [15:0] t_V_reg_50;
reg   [15:0] i_op_assign_reg_59;
wire   [63:0] zext_ln544_fu_87_p1;
reg   [1:0] ap_NS_fsm;

// power-on initialization
initial begin
#0 ap_CS_fsm = 2'd1;
end

always @ (posedge ap_clk) begin
    if (ap_rst == 1'b1) begin
        ap_CS_fsm <= ap_ST_fsm_state1;
    end else begin
        ap_CS_fsm <= ap_NS_fsm;
    end
end

always @ (posedge ap_clk) begin
    if (((icmp_ln37_fu_76_p2 == 1'd0) & (1'b1 == ap_CS_fsm_state2))) begin
        i_op_assign_reg_59 <= i_fu_81_p2;
    end else if (((ap_start == 1'b1) & (1'b1 == ap_CS_fsm_state1))) begin
        i_op_assign_reg_59 <= 16'd0;
    end
end

always @ (posedge ap_clk) begin
    if (((icmp_ln37_fu_76_p2 == 1'd0) & (1'b1 == ap_CS_fsm_state2))) begin
        t_V_reg_50 <= add_ln700_fu_92_p2;
    end else if (((ap_start == 1'b1) & (1'b1 == ap_CS_fsm_state1))) begin
        t_V_reg_50 <= sram_idx_V_read;
    end
end

always @ (posedge ap_clk) begin
    if (((ap_start == 1'b1) & (1'b1 == ap_CS_fsm_state1))) begin
        add_ln37_reg_108 <= add_ln37_fu_70_p2;
    end
end

always @ (*) begin
    if ((((ap_start == 1'b0) & (1'b1 == ap_CS_fsm_state1)) | ((icmp_ln37_fu_76_p2 == 1'd1) & (1'b1 == ap_CS_fsm_state2)))) begin
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
    if (((icmp_ln37_fu_76_p2 == 1'd1) & (1'b1 == ap_CS_fsm_state2))) begin
        ap_ready = 1'b1;
    end else begin
        ap_ready = 1'b0;
    end
end

always @ (*) begin
    if ((1'b1 == ap_CS_fsm_state2)) begin
        mem_V_ce0 = 1'b1;
    end else begin
        mem_V_ce0 = 1'b0;
    end
end

always @ (*) begin
    if (((icmp_ln37_fu_76_p2 == 1'd0) & (1'b1 == ap_CS_fsm_state2))) begin
        mem_V_we0 = 64'd18446744073709551615;
    end else begin
        mem_V_we0 = 64'd0;
    end
end

always @ (*) begin
    case (ap_CS_fsm)
        ap_ST_fsm_state1 : begin
            if (((ap_start == 1'b1) & (1'b1 == ap_CS_fsm_state1))) begin
                ap_NS_fsm = ap_ST_fsm_state2;
            end else begin
                ap_NS_fsm = ap_ST_fsm_state1;
            end
        end
        ap_ST_fsm_state2 : begin
            if (((icmp_ln37_fu_76_p2 == 1'd1) & (1'b1 == ap_CS_fsm_state2))) begin
                ap_NS_fsm = ap_ST_fsm_state1;
            end else begin
                ap_NS_fsm = ap_ST_fsm_state2;
            end
        end
        default : begin
            ap_NS_fsm = 'bx;
        end
    endcase
end

assign add_ln37_fu_70_p2 = (range_V + sram_idx_V_read);

assign add_ln700_fu_92_p2 = (t_V_reg_50 + 16'd1);

assign ap_CS_fsm_state1 = ap_CS_fsm[32'd0];

assign ap_CS_fsm_state2 = ap_CS_fsm[32'd1];

assign ap_return = add_ln37_reg_108;

assign i_fu_81_p2 = (i_op_assign_reg_59 + 16'd1);

assign icmp_ln37_fu_76_p2 = ((i_op_assign_reg_59 == range_V) ? 1'b1 : 1'b0);

assign mem_V_address0 = zext_ln544_fu_87_p1;

assign mem_V_d0 = 512'd0;

assign zext_ln544_fu_87_p1 = t_V_reg_50;

endmodule //reset_mem
