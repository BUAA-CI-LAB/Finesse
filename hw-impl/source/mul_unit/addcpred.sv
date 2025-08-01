`timescale 1ns / 1ps

module addcpred
#(parameter integer WIDTH = 256, parameter integer THRES = 80)
(
    input [WIDTH-1:0] a,
    input [WIDTH-1:0] b,
    input cin,
    output [WIDTH-1:0] o,
    output cout
);
generate
    if (WIDTH < THRES) begin : gen_plain_addition   // Direct addition if width is less than threshold
        assign {cout, o} = a + b + cin;
    end else begin : gen_carry_predict_addition 
        localparam integer HI = WIDTH >> 1, LO = (WIDTH + 1) >> 1;  // LO needs +1 to ensure correct split when WIDTH is odd
        wire [HI-1:0] ahi, bhi, hi0, hi1;
        wire [LO-1:0] alo, blo, lo;
        wire carry_lo, carry_hi0, carry_hi1;
        assign {ahi, alo} = a;
        assign {bhi, blo} = b;
        addcpred #(.WIDTH(HI), .THRES(THRES))   // Precompute high bits when low carry-in is 0
            add_hi0(.a(ahi), .b(bhi), .cin(1'b0), .o(hi0), .cout(carry_hi0));
        addcpred #(.WIDTH(HI), .THRES(THRES))   // Precompute high bits when low carry-in is 1
            add_hi1(.a(ahi), .b(bhi), .cin(1'b1), .o(hi1), .cout(carry_hi1));
        addcpred #(.WIDTH(LO), .THRES(THRES))
            add_lo(.a(alo), .b(blo), .cin(cin), .o(lo), .cout(carry_lo));
        assign o = {(carry_lo ? hi1 : hi0), lo};    // Select high bits based on actual carry-out from low bits
        assign cout = carry_lo ? carry_hi1 : carry_hi0;
    end
endgenerate
endmodule
