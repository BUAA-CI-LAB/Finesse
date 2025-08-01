`timescale 1ns/1ps
`include "../define/params.svh"
`include "../define/param_pre.svh"
/*
    data fetch logic: 3 cycles(mainly read/write data mem)
    features: read/write data mem; decode the instruction to execute unit
    IS: 5(func) 9(res addr) 9(op0 addr) 9(op1 addr)
*/

module data_fetch (
    input clk,
    input rst_n,

    // from/to ifetch
    input ins_valid,
    input [`INSTRW-1:0]instr,
    output halt_if, // decode the halt to ifetch immediately

    // to/from datamem
    output ren_dm_0,
    output [`RFSZLOG2-1:0]raddr_dm_0,
    input  [`WORDSZ-1:0]op_dm_0,
    output ren_dm_1,
    output [`RFSZLOG2-1:0]raddr_dm_1,
    input  [`WORDSZ-1:0]op_dm_1,

    // to execute unit
    output halt_ex, // delay 3 cycles halt to execute unit
    output [`INS_FUNC-1:0]func_op,
    output ex_valid,
    output [`WORDSZ-1:0]op_ex_0,
    output [`WORDSZ-1:0]op_ex_1,
    output [`RFSZLOG2-1:0]rn_ex_0
);

logic [`INS_FUNC-1:0]func_t[3]; // delay 3 cycles pipeline
logic [`RFSZLOG2-1:0]rn_t[3];
logic ex_valid_t[3];

wire [`INS_FUNC-1:0]func;
wire [`RFSZLOG2-1:0]rn_w;

assign func = instr[`INSTRW-1:`INSTRW-`INS_FUNC];

// func_op
always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        {func_t[2],func_t[1],func_t[0]} <= 0;
    else
        if(ins_valid)
            {func_t[2],func_t[1],func_t[0]} <= {func_t[1],func_t[0],func};
        else
            {func_t[2],func_t[1],func_t[0]} <= {func_t[1],func_t[0],`INS_FUNC'b0};
end
assign func_op = func_t[2];

// ex_valid
always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        {ex_valid_t[2],ex_valid_t[1],ex_valid_t[0]} <= 0;
    else
        {ex_valid_t[2],ex_valid_t[1],ex_valid_t[0]} <= {ex_valid_t[1],ex_valid_t[0],ins_valid};
end
assign ex_valid = ex_valid_t[2];

/*
    data read
    ins_valid is high then read
    wait 3 cycles pipeline out data
*/
assign ren_dm_0 = (ins_valid == 1) && (func != 0);
assign raddr_dm_0 = (func == `OP_CVT | func == `OP_ICV)? 
                    instr[`INSTRW -`INS_FUNC-1:`INSTRW -`INS_FUNC-`INS_RES]:instr[`INS_OP0+`INS_OP1-1:`INS_OP1]; // icv and cvt read the "res" addr to change
assign ren_dm_1 = (ins_valid == 1) && (func != 0);
assign raddr_dm_1 = instr[`INS_OP0-1:0];

assign op_ex_0 = op_dm_0;
assign op_ex_1 = op_dm_1;

/*
    res addr trans
*/
assign rn_w = instr[`INSTRW -`INS_FUNC-1:`INSTRW -`INS_FUNC-`INS_RES];
always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        {rn_t[2],rn_t[1],rn_t[0]} <= 0;
    else
        if(ins_valid)
            {rn_t[2],rn_t[1],rn_t[0]} <= {rn_t[1],rn_t[0],rn_w};
        else
            {rn_t[2],rn_t[1],rn_t[0]} <= {rn_t[1],rn_t[0],`RFSZLOG2'b0};
end
assign rn_ex_0 = rn_t[2];

// this may change to func == `op_halt
assign halt_if = (ins_valid == 1) && (instr == `HALT_INSTR);

// halt to ex
logic halt_ex_t[3];
always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        {halt_ex_t[2],halt_ex_t[1],halt_ex_t[0]} <= 0;
    else
        {halt_ex_t[2],halt_ex_t[1],halt_ex_t[0]} <= {halt_ex_t[1],halt_ex_t[0],halt_if};
end
assign halt_ex = halt_ex_t[2];

endmodule