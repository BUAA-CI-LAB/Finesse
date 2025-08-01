`timescale 1ns/1ps
`include "../define/params.svh"
`include "../define/param_pre.svh"

// pairing top

module micro_top (
    input clk,
    input rst_n,
    input [`CORELOG2-1:0]chip_sel,
    input [`FUNCIDW-1:0]funcid,
    input start,
    input wen,
    input [`PORTAW-1:0]waddr,   // {waddr_inner[`RFSZLOG2-1:0],waddr_sel[4:0]}
    input [`PORTW-1:0]wdata,
    input ren,
    input [`PORTAW-1:0]raddr,
    output[`PORTW-1:0]rdata,
    output rdata_valid,
    output busy
);

wire wen_inner;
logic [`RFSZLOG2-1:0]waddr_inner;
logic [`WORDSZ-1:0]wdata_inner;
wire ren_inner;
wire [`RFSZLOG2-1:0]raddr_inner;
wire [`WORDSZ-1:0]rdata_inner;
logic [`PORTW-1:0]rdata_r;
logic rdata_valid_r;

// WORDSZ/PORTW
parameter SERSZ = `WORDSZ % `PORTW == 0 ? `WORDSZ / `PORTW : `WORDSZ / `PORTW + 1; 

// write 32 -> WORDSZ(MAX = 638 SO THE MAX TRANSNUM = 20)
logic [31:0]ready;
wire full = &(ready[SERSZ-1:0]);
always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        ready <= 32'h00000000;
    else
        if(full)
            if(wen)
                ready <= 32'h00000001;
            else
                ready <= 0;
        else if(wen)
            ready[waddr[4:0]] <= 1'b1;
        else
            ready <= ready;
end
assign wen_inner = full && (!busy); // outside can not write when micro is running 

// waddr_inner
always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        waddr_inner <= 0;
    else
        if(wen)
            waddr_inner <= waddr[`PORTAW-1:5];
end

// wdata_inner: THE low 5 bit store the location information
always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        wdata_inner <= 0;
    else
        if(wen)
            wdata_inner[{waddr[4:0], 5'b00000} +: `PORTW] <= wdata;
end


// read WORDSZ -> 32
logic [4:0]raddr_t[3]; // store the Byte addr
logic ren_t[3];        // store the ren signal
assign ren_inner = ren;
assign raddr_inner = raddr[`PORTAW-1:5];
always @(posedge clk, negedge rst_n) begin
    if(!rst_n)begin
        {raddr_t[2],raddr_t[1],raddr_t[0]} <= 0;
        {ren_t[2],ren_t[1],ren_t[0]} <= 0;
    end
    else begin
        {ren_t[2],ren_t[1],ren_t[0]} <= {ren_t[1],ren_t[0],ren};
        if(ren)begin
            {raddr_t[2],raddr_t[1],raddr_t[0]} <= {raddr_t[1],raddr_t[0],raddr[4:0]};
        end
        else begin
            {raddr_t[2],raddr_t[1],raddr_t[0]} <= {raddr_t[1],raddr_t[0],5'd0};
        end
    end
end

// rdata_valid
always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        rdata_valid_r <= 0;
    else
        rdata_valid_r <= ren_t[2];
end
assign rdata_valid = rdata_valid_r;

// rdata
always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        rdata_r <= 0;
    else
        rdata_r <= rdata_inner[{raddr_t[2],5'b00000} +: `PORTW];
end
assign rdata = rdata_r;

wire [`CORELOG2-1:0]chip_sel_t = (`CORE_NUM == 1) ? 0 : chip_sel;

micro u_micro(
    .clk(clk),
    .rst_n(rst_n),
    .chip_sel(chip_sel_t),
    .funcid(funcid),
    .start(start),
    .wen(wen_inner),
    .waddr(waddr_inner),
    .wdata(wdata_inner),
    .ren(ren_inner),
    .raddr(raddr_inner),
    .rdata(rdata_inner),
    .busy(busy)
);

endmodule

