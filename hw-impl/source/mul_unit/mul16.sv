`timescale 1ns / 1ps

module mul16(
    input clk,
    input [15 : 0] a,
    input [15 : 0] b,
    output logic [31 : 0] c
);

    always @(posedge clk) begin
        c <= a * b;
    end

endmodule
