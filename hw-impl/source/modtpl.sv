`timescale 1ns / 1ps
`include "../define/params.svh"
`include "../define/param_pre.svh"
/*
    ensure the indata < p
    func: a0 * 3 mod p
*/


// 21 cycles pipeline
module modtpl #(
    parameter thres = 160
)(
    input clk,
    input rst_n,
    input en,
    input [`WORDSZ-1:0] a0,
    input [`RFSZLOG2-1:0]rn0,
    output[`RFSZLOG2-1:0]rn,
    output [`WORDSZ-1:0] res
);

logic [`WORDSZ-1:0]in_r0,in_r1;
logic [1:0]op_r0,op_r1,op_r2,op_r3;
logic [`WORDSZ-1:0]neg_r0,neg_r1,neg_r2;
logic [`WORDSZ-1:0]dbl_r0,dbl_r1,dbl_r2;
logic [`WORDSZ:0]tpl_r0;
logic [`WORDSZ-1:0]tpl_r1;

logic [`RFSZLOG2-1:0]rn_r[4];

wire [`WORDSZ:0]neg_t;
wire [`WORDSZ-1:0]neg_w;

wire [`WORDSZ:0]dbl_t;
wire [`WORDSZ:0]dbl_red_t;
wire [`WORDSZ-1:0]dbl_w;

wire [`WORDSZ:0]tpl_w0;
wire [`WORDSZ-1:0]tpl_w1;
wire [`WORDSZ:0]tpl_red_t;

wire [`WORDSZ-1:0]res_w;

wire [`WORDSZ-1:0]p = `P;
wire [`WORDSZ:0]p_n = {1'b1,~p} + 1;

// in_r pipe - 1
always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        {in_r1,in_r0} <= 0;
    else
        if(en)
            {in_r1,in_r0} <= {in_r0,a0};
        else
            {in_r1,in_r0} <= {in_r0,`WORDSZ'b0};
end

// dbl pipe - 2
assign dbl_t = {in_r0,1'b0};

addcpred #(.WIDTH(`WORDSZ+1), .THRES(thres))
    u_dbl(.a(dbl_t), .b(p_n), .cin(1'b0), .o(dbl_red_t), .cout());

assign dbl_w = (dbl_red_t[`WORDSZ] == 0)? dbl_red_t[`WORDSZ-1:0]:dbl_t[`WORDSZ-1:0];

always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        dbl_r0 <= 0;
    else
        dbl_r0 <= dbl_w;
end

// tpl pipe - 3 4
addcpred #(.WIDTH(`WORDSZ), .THRES(thres))
    u_tpl0(.a(in_r1), .b(dbl_r0), .cin(1'b0), .o(tpl_w0[`WORDSZ-1:0]), .cout(tpl_w0[`WORDSZ]));

addcpred #(.WIDTH(`WORDSZ+1), .THRES(thres))
    u_tpl1(.a(tpl_r0), .b(p_n), .cin(1'b0), .o(tpl_red_t), .cout());

assign tpl_w1 = (tpl_red_t[`WORDSZ] == 0)? tpl_red_t[`WORDSZ-1:0]:tpl_r0[`WORDSZ-1:0];

always @(posedge clk, negedge rst_n) begin
    if(!rst_n)begin
        tpl_r0 <= 0;
        tpl_r1 <= 0;
    end
    else begin
        tpl_r0 <= tpl_w0;
        tpl_r1 <= tpl_w1;
    end
end

// rn
always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        {rn_r[3],rn_r[2],rn_r[1],rn_r[0]} <= 0;
    else
        if(en)
            {rn_r[3],rn_r[2],rn_r[1],rn_r[0]} <= {rn_r[2],rn_r[1],rn_r[0],rn0};
        else
            {rn_r[3],rn_r[2],rn_r[1],rn_r[0]} <= {rn_r[2],rn_r[1],rn_r[0],`RFSZLOG2'd0};
end

assign res = tpl_r1;
assign rn = rn_r[3];

endmodule
