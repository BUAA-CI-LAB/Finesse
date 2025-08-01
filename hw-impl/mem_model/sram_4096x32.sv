/* 
    This is single port SRAM with 4096(depth)x32(width) bits (use as rom). Replace "spsram4096x32" with the PDK memory model used.

    The hexfile_init parameter facilitates memory initialization using a hex file. This hex file is parsed into multiple sections, each of which is then used to initialize a corresponding portion of the ROM. Specifically, hexfile_init indicates the starting line within the hex file for the current ROM's initialization data.
*/
module sram_4096x32 #(
    parameter hexfile_init = 0
) (
    input  clk,
    input  ce, // high valid
    input  [11:0]addr,
    output [31:0]i_out
);

wire pd = 1'b0;
wire ceb = ~ce;
wire web = 1'b1; // always read
wire bist = 1'b0;
wire [31:0]din = 32'b0;

spsram4096x32 #(
    .hexfile_init(hexfile_init)
)
        u_4096x32(
            .PD(pd),    // power down mode 
            .CLK(clk),  // clk
            .CEB(ceb),  // chip select
            .WEB(web),  // write enable - 0:w / 1:r
            .CEBM(1'b0),    // not use
            .WEBM(1'b1),    // not use
            .AWT(1'b0),     // not use
            .A(addr),   // read addr
            .D(din),    // not use
            .BWEB(32'h00000000),    // 
            .AM(addr),      // not use
            .DM(din),      // not use
            .BWEBM(32'h00000000),   // not use
            .BIST(bist),// BIST mode 0:normal 1:BIST
            .Q(i_out)   // output
        );  

endmodule