`timescale 1ns / 1ps

/*
    Carry Save Adder
    o0:SUM
    o1:CARRY >> 1

    hence: RES = o0 + (o1 << 1)
*/

module add3to2
#(parameter integer WIDTH = 1)
(
    input [WIDTH-1:0] i0,
    input [WIDTH-1:0] i1,
    input [WIDTH-1:0] i2,
    output [WIDTH-1:0] o0,
    output [WIDTH-1:0] o1
);

assign o0 = i0 ^ i1 ^ i2;
assign o1 = (i0 & i1) | (i1 & i2) | (i2 & i0);

endmodule
