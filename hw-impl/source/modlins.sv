`timescale 1ns / 1ps
`include "../define/params.svh"
`include "../define/param_pre.svh"
/*
4 cycle addition
ensure the input data < SMP_P*
op: 0 - neg; 1 - dbl
op: 2 - add; 3 - sub
*/
module modlins #(
    parameter thres = 160
)(
        input clk,
        input rst_n,
        input en,
        input [`WORDSZ-1:0] a0,
        input [`WORDSZ-1:0] b0,
        input [`RFSZLOG2-1:0] rn0,
        input [1:0]op,
        output[`RFSZLOG2-1:0] rn,
        output [`WORDSZ-1:0] res
    );
     
    logic [1:0]op_r[3];
    logic [`WORDSZ-1:0]a_reg;
    logic [`WORDSZ-1:0]b_reg;

    logic [`WORDSZ-1:0]neg_r;
    wire  [`WORDSZ:0]neg_t;
    logic [`WORDSZ:0]neg_t_r;

    logic [`WORDSZ:0]dbl_r0;
    logic [`WORDSZ-1:0]dbl_r1;
    wire  [`WORDSZ:0]dbl_t;
    wire  [`WORDSZ:0]dbl_red_t;
    logic [`WORDSZ:0]dbl_red_r;
    wire  [`WORDSZ-1:0]dbl_w;
    
    logic [`WORDSZ:0]add_r0;
    logic [`WORDSZ-1:0]add_r1;
    wire  [`WORDSZ:0]add_red;
    wire  [`WORDSZ:0]add_t;
    wire  [`WORDSZ-1:0]add_res;

    logic [`WORDSZ:0]sub_r0;
    logic [`WORDSZ-1:0]sub_r1;
    wire  [`WORDSZ:0]sub_t;
    wire  [`WORDSZ:0]sub_red;
    wire  [`WORDSZ-1:0]sub_res;

    logic [`WORDSZ-1:0]res_r;
    logic [`RFSZLOG2-1:0]rn_r[4]; // 21 pipeline
    
    wire [`WORDSZ-1:0]p = `P;
    wire [`WORDSZ:0]smp_p_n = {1'b1,~p} + 1;

    // op
    always @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            {op_r[2],op_r[1],op_r[0]} <= 0;
        else
            {op_r[2],op_r[1],op_r[0]} <= {op_r[1],op_r[0],op};
    end

    // in_reg -- pipeline 1
    always @(posedge clk, negedge rst_n) begin
        if(!rst_n)begin
            a_reg <= 0;
            b_reg <= 0;
        end
        else begin
            if(en)begin
                a_reg <= a0;
                b_reg <= b0;
            end
            else begin
                a_reg <= 0;
                b_reg <= 0;
            end
        end
    end
    
    // ================ neg ================
    // attention: when the a_reg = 0 -> the neg_t = {1'b1,p}
    addcpred #(.WIDTH(`WORDSZ+1), .THRES(thres))
        u_neg(.a({1'b0,p}), .b({1'b1,~a_reg + 1'b1}), .cin(1'b0), .o(neg_t), .cout());

    // neg_reg -- pipeline 2
    always @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            neg_t_r <= 0;
        else
            neg_t_r <= neg_t;
    end

    wire[`WORDSZ-1:0] neg_w = (neg_t_r[`WORDSZ] == 1)? `WORDSZ'd0:neg_t_r[`WORDSZ-1:0];

    // neg_reg -- pipeline 3
    always @(posedge clk, negedge rst_n) begin
        if(!rst_n)begin
            neg_r <= 0;
        end
        else begin
            neg_r <= neg_w;
        end
    end

    // ================ dbl ================
    assign dbl_t = {a_reg,1'b0};

    addcpred #(.WIDTH(`WORDSZ+1), .THRES(thres))
        u_dbl(.a(dbl_t), .b(smp_p_n), .cin(1'b0), .o(dbl_red_t), .cout());

    always @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            dbl_red_r <= 0;
        else
            dbl_red_r <= dbl_red_t;
    end

    assign dbl_w = (dbl_red_r[`WORDSZ] == 0)? dbl_red_r[`WORDSZ-1:0]:dbl_r0;
    // dbl reg -- pipeline 2 3
    always @(posedge clk, negedge rst_n) begin
        if(!rst_n)begin
            {dbl_r1,dbl_r0} <= 0;
        end
        else
            {dbl_r1,dbl_r0} <= {dbl_w,dbl_t};
    end

    // ================ add ================
    // unsigned add
    addcpred #(.WIDTH(`WORDSZ), .THRES(thres))
        add1(.a(a_reg), .b(b_reg), .cin(1'b0), .o(add_t[`WORDSZ-1:0]), .cout(add_t[`WORDSZ]));

    // signed add->sub
    addcpred #(.WIDTH(`WORDSZ+1), .THRES(thres))
    add2(.a(add_r0), .b(smp_p_n), .cin(1'b0), .o(add_red), .cout());

    assign add_res = (add_red[`WORDSZ] == 1'b0)?add_red[`WORDSZ-1:0]:add_r0[`WORDSZ-1:0];

    always @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            {add_r1,add_r0} <= 0;
        else
            {add_r1,add_r0} <= {add_res,add_t};
    end

    // ================ sub ================
    // signed add->sub
    addcpred #(.WIDTH(`WORDSZ+1), .THRES(thres))
    sub1(.a({1'b0,a_reg}), .b({1'b1,~b_reg} + 1), .cin(1'b0), .o(sub_t[`WORDSZ:0]), .cout());
    // signed add
    addcpred #(.WIDTH(`WORDSZ+1), .THRES(thres))
    sub2(.a(sub_r0), .b({1'b0,p}), .cin(1'b0), .o(sub_red), .cout());

    assign sub_res = (sub_r0[`WORDSZ]==1'b0)?sub_r0[`WORDSZ-1:0]:sub_red[`WORDSZ-1:0];

    // sub pipeline - 2 3
    always @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            {sub_r1,sub_r0} <= 0;
        else
            {sub_r1,sub_r0} <= {sub_res,sub_t};
    end

    // ================ res ================ 
    wire [`WORDSZ-1:0]res_w = 
                            {`WORDSZ{op_r[2] == 2'b00}} & neg_r  |
                            {`WORDSZ{op_r[2] == 2'b01}} & dbl_r1 |
                            {`WORDSZ{op_r[2] == 2'b10}} & add_r1 |
                            {`WORDSZ{op_r[2] == 2'b11}} & sub_r1 ;

    // mux - pipeline 4
    always @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            res_r <= 0;
        else
            res_r <= res_w;
    end

    always @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            {rn_r[3],rn_r[2],rn_r[1],rn_r[0]} <= 0;
        else
            if(en)
                {rn_r[3],rn_r[2],rn_r[1],rn_r[0]} <= {rn_r[2],rn_r[1],rn_r[0],rn0};
            else
                {rn_r[3],rn_r[2],rn_r[1],rn_r[0]} <= {rn_r[2],rn_r[1],rn_r[0],`RFSZLOG2'd0};
    end

assign res = res_r;
assign rn = rn_r[3];

endmodule
