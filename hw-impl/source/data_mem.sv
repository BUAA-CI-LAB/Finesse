`timescale 1ns/1ps
`include "../define/params.svh"
`include "../define/param_pre.svh"

/*
    arbiter + single port sram x 2
    sram: store the same data
    arbiter: control the data source and direction
*/
module data_mem (
    input clk,
    
    // begin from ifetch, end with execute unit
    // indicate the micro is runing
    input busy,

    // to data fetch
    input ren_df_0,
    input [`RFSZLOG2-1:0]raddr_df_0,
    output [`WORDSZ-1:0]op_df_0,
    input ren_df_1,
    input [`RFSZLOG2-1:0]raddr_df_1,
    output [`WORDSZ-1:0]op_df_1,

    // from alu ex res
    input wen_alu,
    input [`RFSZLOG2-1:0]waddr_alu,
    input [`WORDSZ-1:0]res_alu,

    // from interface
    input wen_io,
    input [`RFSZLOG2-1:0]waddr_io,
    input [`WORDSZ-1:0]data_in,
    input ren_io,
    input [`RFSZLOG2-1:0]raddr_io,
    output [`WORDSZ-1:0]data_out
);

wire ren_m0,ren_m1,wen;

wire [`RFSZLOG2-1:0]raddr_m0,raddr_m1,waddr;

wire [`WORDSZ-1:0]rdata_m0,rdata_m1,wdata;

// data source(write)
// the two sram write the same data
assign wen = (busy == 1)? wen_alu : wen_io;
assign waddr = (busy == 1)? waddr_alu : waddr_io;
assign wdata = (busy == 1)? (waddr == 0? 0:res_alu) : (waddr == 0? 0:data_in);

// data direction(read)
// io read the m0; dfetch read the different addr data from the two sram
assign ren_m0 = (busy == 1)? ren_df_0 : ren_io;
assign raddr_m0 = (busy == 1)? raddr_df_0 : raddr_io;
assign ren_m1 = (busy == 1)? ren_df_1 : 0;
assign raddr_m1 = (busy == 1)? raddr_df_1 : 0;

assign data_out = (busy == 1)? 0 : rdata_m0;
assign op_df_0 = (busy == 1)? rdata_m0 : 0;
assign op_df_1 = (busy == 1)? rdata_m1 : 0;

sram_mxn m0(
    .clk(clk),
    
    .ren(ren_m0),
    .raddr(raddr_m0),
    .rdata(rdata_m0),

    .wen(wen),
    .waddr(waddr),
    .wdata(wdata)
);

    
sram_mxn m1(
    .clk(clk),
    
    .ren(ren_m1),
    .raddr(raddr_m1),
    .rdata(rdata_m1),

    .wen(wen),
    .waddr(waddr),
    .wdata(wdata)
);



endmodule