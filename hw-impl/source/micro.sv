/*
Author: Tianao Dai
Time:   2024/5/23
*/

`timescale 1ns/1ps
`include "../define/params.svh"
`include "../define/param_pre.svh"

// pairing top

module micro (
    input clk,
    input rst_n,
    input [`FUNCIDW-1:0] funcid,
    input start,    // means the pairing start
    input wen,
    input [`CORELOG2-1:0]chip_sel,
    input [`RFSZLOG2-1:0] waddr,
    input [`WORDSZ-1:0] wdata,
    input ren,
    input [`RFSZLOG2-1:0] raddr,
    output [`WORDSZ-1:0] rdata,
    output busy
);

wire [`IMSZLOG2-1:0]pc_if;
wire iren;
wire [`INSTRW-1:0]instr_im,instr_if;
wire ins_valid;
wire halt_if;
wire run_if;
wire run_ex;

// from ins fetch to execute end
assign busy = run_if | run_ex;

instr_fetch u_if(
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .funcid(funcid),

    .pc_o(pc_if),
    .iren(iren),
    .instr_i(instr_im),

    .ins_valid(ins_valid),
    .instr_o(instr_if), // delay 2 cycle to update
    .halt(halt_if),

    .run_if(run_if)   // Indicates that an instruction fetch is running
);
    
instr_mem u_im(
    .clk(clk),
    .rst_n(rst_n),
    .halt(halt_if),
    .addr_i(pc_if),
    .ren(iren),
    .im_o(instr_im),
    .ins_valid(ins_valid)
);

wire ins_valid_de[`CORE_NUM];
wire [`INSTRW-1:0]instr_if_de[`CORE_NUM];
wire run_if_de[`CORE_NUM];
wire [`CORE_NUM-1:0]halt_if_de;
wire wen_de[`CORE_NUM];
wire [`RFSZLOG2-1:0]waddr_de[`CORE_NUM];
wire [`WORDSZ-1:0]wdata_de[`CORE_NUM];
wire ren_de[`CORE_NUM];
wire [`RFSZLOG2-1:0]raddr_de[`CORE_NUM];
wire [`WORDSZ-1:0]rdata_de[`CORE_NUM];
wire [`CORE_NUM-1:0]run_ex_de;

genvar i;
generate
    for(i=0;i<`CORE_NUM;i=i+1)begin
        assign ins_valid_de[i] = ins_valid;
        assign instr_if_de[i] = instr_if;
        assign run_if_de[i] = run_if;
        assign wen_de[i] = chip_sel == i & wen;
        assign waddr_de[i] = {`RFSZLOG2{chip_sel == i}} & waddr;
        assign wdata_de[i] = {`WORDSZ{chip_sel == i}} & wdata;
        assign ren_de[i] = chip_sel == i & ren;
        assign raddr_de[i] = {`RFSZLOG2{chip_sel == i}} & raddr;
        data_ex u_de(
            .clk(clk),
            .rst_n(rst_n),
            .ins_valid(ins_valid_de[i]),
            .instr_if(instr_if_de[i]),
            .run_if(run_if_de[i]),
            .halt_if(halt_if_de[i]),
            .wen_io(wen_de[i]),
            .waddr_io(waddr_de[i]),
            .wdata_io(wdata_de[i]),
            .ren_io(ren_de[i]),
            .raddr_io(raddr_de[i]),
            .rdata_io(rdata_de[i]),
            .busy(busy),
            .run_ex(run_ex_de[i])
        );
    end
endgenerate

// or all
assign halt_if = | halt_if_de;
assign run_ex = | run_ex_de;
assign rdata = rdata_de[chip_sel];

endmodule
