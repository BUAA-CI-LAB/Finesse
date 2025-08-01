`timescale 1ns/1ps
`include "../define/params.svh"
`include "../define/param_pre.svh"

module execute_unit(
    input clk,
    input rst_n,

    input run_if,
    input halt_ex,
    input [`INS_FUNC-1:0]func_op,
    input ex_valid,
    input [`WORDSZ-1:0]op_0,
    input [`WORDSZ-1:0]op_1,
    input [`RFSZLOG2-1:0]rn_df,

    output wen_ex,
    output [`RFSZLOG2-1:0]waddr_ex,
    output [`WORDSZ-1:0]res_ex,

    output run_ex
);

// halt_ex_d: when the halt signal valid then delay the max cycles(21)
logic [`MODMUL-1:0]halt_ex_d;

wire alum_en,alul_en,alut_en,alui_en;
wire alui_done;

// operation decode
assign alum_en = (func_op == `OP_SQR | func_op == `OP_MUL | func_op == `OP_CVT | func_op == `OP_ICV) & ex_valid;
assign alul_en = (func_op == `OP_ADD | func_op == `OP_SUB | func_op == `OP_NEG | func_op == `OP_DBL) & ex_valid;
assign alut_en = (func_op == `OP_TPL) & ex_valid;
assign alui_en = (func_op == `OP_INV) & ex_valid;

// operate number mul
wire [`WORDSZ-1:0] alum_a0 = op_0;
wire [`WORDSZ-1:0] alum_b0 =(func_op == `OP_SQR) ? op_0 :
                            (func_op == `OP_CVT) ? `P_CVT :
                            (func_op == `OP_ICV) ? `WORDSZ'h1 : op_1;

// operate number lins
wire [1:0]alul_op = (func_op == `OP_NEG)? 2'b00:
                    (func_op == `OP_DBL)? 2'b01:
                    (func_op == `OP_ADD)? 2'b10:
                    (func_op == `OP_SUB)? 2'b11:2'b00;
wire [`WORDSZ-1:0] alul_a0 = op_0;
wire [`WORDSZ-1:0] alul_b0 = op_1;

// operate number tpl
wire [`WORDSZ-1:0] alut_a0 = op_0;

// operate number inv
wire [`WORDSZ-1:0] alui_a0 = op_0;

// res wen
wire [`RFSZLOG2-1:0]rn_in = rn_df;
wire [`RFSZLOG2-1:0]alum_rn,alut_rn,alul_rn,alui_rn;
wire  wen_t = |(alui_rn | alum_rn | alut_rn | alul_rn);
assign wen_ex = run_ex || wen_t;

// res addr
assign waddr_ex = (alui_rn | alum_rn | alut_rn | alul_rn);

// res
wire [`WORDSZ-1:0]alum_res,alut_res,alul_res,alui_res;
assign res_ex = alui_res | alum_res | alut_res | alul_res;

// run_ex
genvar k;
generate
    always @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            halt_ex_d[0] <= 0;
        else begin
            halt_ex_d[0] <= halt_ex;
        end
    end
    for(k = 1; k < `MODMUL; k = k + 1)begin
        always @(posedge clk, negedge rst_n) begin
            if(!rst_n)
                halt_ex_d[k] <= 0;
            else begin
                halt_ex_d[k] <= halt_ex_d[k-1];
            end
        end
    end
endgenerate
wire ex_end = (halt_ex_d[`MODMUL-1] == 1'b1);
logic run_ex_r;
always @(posedge clk,negedge rst_n) begin
    if(!rst_n)
        run_ex_r <= 0;
    else
        if(ex_end)
            run_ex_r <= 0;
        else if(run_if && (wen_t))
            run_ex_r <= 1;
        else
            run_ex_r <= run_ex_r;
end
assign run_ex = run_ex_r | wen_t;

modmul #(
    .thres(`ADDCTHRES)
) mm(
    .clk(clk),
    .rst_n(rst_n),
    .en(alum_en),
    .a0(alum_a0),
    .b0(alum_b0),
    .rn0(rn_in),
    .rn(alum_rn),
    .res(alum_res)
);

modlins #(
    .thres(`ADDCTHRES)
) ml(
    .clk(clk),
    .rst_n(rst_n),
    .en(alul_en),
    .a0(alul_a0),
    .b0(alul_b0),
    .rn0(rn_in),
    .op(alul_op),
    .rn(alul_rn),
    .res(alul_res)
);

modtpl #(
    .thres(`ADDCTHRES)
) mt(
    .clk(clk),
    .rst_n(rst_n),
    .en(alut_en),
    .a0(alut_a0),
    .rn0(rn_in),
    .rn(alut_rn),
    .res(alut_res)
);

modinv #(
    .thres(`ADDCTHRES)
) mi(
    .clk(clk),
    .rst_n(rst_n),
    .en(alui_en),
    .a0(alui_a0),
    .rn0(rn_in),
    .rn(alui_rn),
    .res(alui_res),
    .done(alui_done)
);

endmodule