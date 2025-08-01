/* 
    This is double port SRAM/RegisterFile with 512(depth)x64(width) bits. Replace "dprf512x64" with the PDK memory model used.
*/
module sram_512x64 (
    input clk,
    input [8:0]raddr,
    input [8:0]waddr,
    input [63:0]wdata,
    output [63:0]rdata
);

wire [63:0]bweb = 64'h00000000;
wire web = 1'b0;
wire reb = 1'b0;
wire pd = 1'b0;

// port A write port B read
dprf512x64 u_512x64(
    .AA(waddr),
    .D(wdata),
    .BWEB(bweb),
    .WEB(web),
    .CLKW(clk),
    .AB(raddr),
    .REB(reb),
    .CLKR(clk),
    .PD(pd),
    .AMA(9'h0),     // not use(BIST mode)
    .DM(64'h0),      // not use(BIST mode)
    .BWEBM(bweb),   // not use(BIST mode)   
    .WEBM(1'b1),    // not use(BIST mode)   
    .AMB(9'h0),     // not use(BIST mode)
    .REBM(1'b1),    // not use(BIST mode)   
    .BIST(1'b0),    // not use(BIST mode)   
    .Q(rdata)
    );
    
endmodule