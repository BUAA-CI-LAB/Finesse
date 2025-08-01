/* 
    This is double port SRAM/RegisterFile with 1024(depth)x36(width) bits. Replace "dprf1024x36" with the PDK memory model used.
*/
module sram_1024x36 (
    input clk,
    input [9:0]raddr,
    input [9:0]waddr,
    input [35:0]wdata,
    output [35:0]rdata
);

wire [35:0]bweb = 36'h00000000;
wire web = 1'b0;
wire reb = 1'b0;
wire pd = 1'b0;

// port A write port B read
dprf1024x36 u_1024x36(
    .AA(waddr),
    .D(wdata),
    .BWEB(bweb),
    .WEB(web),
    .CLKW(clk),
    .AB(raddr),
    .REB(reb),
    .CLKR(clk),
    .PD(pd),
    .AMA(10'h0),     // not use(BIST mode)
    .DM(36'h0),      // not use(BIST mode)
    .BWEBM(bweb),   // not use(BIST mode)   
    .WEBM(1'b1),    // not use(BIST mode)   
    .AMB(10'h0),     // not use(BIST mode)
    .REBM(1'b1),    // not use(BIST mode)   
    .BIST(1'b0),    // not use(BIST mode)   
    .Q(rdata)
    );
    
endmodule