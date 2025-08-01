`timescale 1ns / 1ps

/*
    parameterized multiplier for lower half bit
    WIDTH must in [256, 640]
    9 cycle
*/

module mulparamlo
#(parameter integer WIDTH = 256)
(
    input clk,
    input [WIDTH - 1 : 0] a,
    input [WIDTH - 1 : 0] b,
    output logic [WIDTH - 1: 0] c
);

    genvar i;

    // WIDTH must be divided by 8
    localparam integer W = WIDTH % 8 == 0 ? WIDTH : (WIDTH / 8 + 1) * 8;    // width
    localparam integer WH = W / 2;                                          // half width
    localparam integer WU = W / 8;                                          // unit width

    wire [WU - 1 : 0] a1 [7 : 0];
    wire [WU - 1 : 0] b1 [7 : 0];

    generate
        for (i = 0; i < 7; i++) begin
            assign a1[i] = a[i * WU +: WU];
            assign b1[i] = b[i * WU +: WU];
        end
    endgenerate
    assign a1[7] = {{W - WIDTH{1'b0}}, a[WIDTH - 1 : WU * 7]};
    assign b1[7] = {{W - WIDTH{1'b0}}, b[WIDTH - 1 : WU * 7]};

    // multiply
    wire [W  - 1     : 0] t0;
    wire [WH - 1     : 0] t1 [1 : 0];
    wire [WU * 2 - 1 : 0] t2 [3 : 0],
                          t3 [7 : 0];

    // [255 : 0]
    mul_k2 #(.WIDTH(WH)) mul0 (
        .clk(clk),
        .a({a1[3], a1[2], a1[1], a1[0]}),
        .b({b1[3], b1[2], b1[1], b1[0]}),
        .c(t0)
    );

    // [255 : 128]
    mul_k3 #(.WIDTH(WU * 2)) mul1_0 (
        .clk(clk),
        .a({a1[1], a1[0]}),
        .b({b1[5], b1[4]}),
        .c(t1[0])
    );
    mul_k3 #(.WIDTH(WU * 2)) mul1_1 (
        .clk(clk),
        .a({a1[5], a1[4]}),
        .b({b1[1], b1[0]}),
        .c(t1[1])
    );

    // [255 : 192]
    generate
        for (i = 0; i < 4; i++) begin
            mul32_80 #(.WIDTH(WU)) mul2 (
                .clk(clk),
                .a(a1[i * 2]),
                .b(b1[6 - i * 2]),
                .c(t2[i])
            );
        end
    endgenerate

    // [287 : 224]
    generate
        for (i = 0; i < 8; i++) begin
            mul32_80 #(.WIDTH(WU)) mul3 (
                .clk(clk),
                .a(a1[i]),
                .b(b1[7 - i]),
                .c(t3[i])
            );
        end
    endgenerate

    // CSA: 12 -> 8
    wire  [WU * 2 - 1 : 0] res3     [8 : 1];    // 3 means the 3th cycle
    logic [WU * 2 - 1 : 0] res3_reg [8 : 1];

    add3to2 #(.WIDTH(WU * 2)) csa_3_1 (
        .i0(t2[0]),
        .i1(t2[1]),
        .i2(t2[2]),
        .o0(res3[1]),
        .o1(res3[5])
    );
    add3to2 #(.WIDTH(WU * 2)) csa_3_2 (
        .i0(t2[3]),
        .i1({t3[0][WU - 1 : 0], {WU{1'b0}}}),
        .i2({t3[1][WU - 1 : 0], {WU{1'b0}}}),
        .o0(res3[2]),
        .o1(res3[6])
    );
    add3to2 #(.WIDTH(WU * 2)) csa_3_3 (
        .i0({t3[2][WU - 1 : 0], {WU{1'b0}}}),
        .i1({t3[3][WU - 1 : 0], {WU{1'b0}}}),
        .i2({t3[4][WU - 1 : 0], {WU{1'b0}}}),
        .o0(res3[3]),
        .o1(res3[7])
    );
    add3to2 #(.WIDTH(WU * 2)) csa_3_4 (
        .i0({t3[5][WU - 1 : 0], {WU{1'b0}}}),
        .i1({t3[6][WU - 1 : 0], {WU{1'b0}}}),
        .i2({t3[7][WU - 1 : 0], {WU{1'b0}}}),
        .o0(res3[4]),
        .o1(res3[8])
    );

    generate
        for (i = 1; i <= 4; i++) begin
            always @(posedge clk) begin
                res3_reg[i] <= res3[i];
                res3_reg[i + 4] <= {res3[i + 4][WU * 2 - 2 : 0], 1'b0};
            end
        end
    endgenerate

    // CSA: 8 -> 6 -> 4
    wire  [WU * 2 - 1 : 0] res4     [8 : 1];
    logic [WU * 2 - 1 : 0] res4_reg [4 : 1];

    add3to2 #(.WIDTH(WU * 2)) csa_4_1 (
        .i0(res3_reg[1]),
        .i1(res3_reg[2]),
        .i2(res3_reg[3]),
        .o0(res4[5]),
        .o1(res4[6])
    );
    add3to2 #(.WIDTH(WU * 2)) csa_4_2 (
        .i0(res3_reg[4]),
        .i1(res3_reg[5]),
        .i2(res3_reg[6]),
        .o0(res4[7]),
        .o1(res4[8])
    );
    add3to2 #(.WIDTH(WU * 2)) csa_4_3 (
        .i0(res4[5]),
        .i1({res4[6][WU * 2 - 2 : 0], 1'b0}),
        .i2(res4[7]),
        .o0(res4[1]),
        .o1(res4[2])
    );
    add3to2 #(.WIDTH(WU * 2)) csa_4_4 (
        .i0({res4[8][WU * 2 - 2 : 0], 1'b0}),
        .i1(res3_reg[7]),
        .i2(res3_reg[8]),
        .o0(res4[3]),
        .o1(res4[4])
    );

    always @(posedge clk) begin
        res4_reg[1] <= res4[1];
        res4_reg[2] <= {res4[2][WU * 2 - 2 : 0], 1'b0};
        res4_reg[3] <= res4[3];
        res4_reg[4] <= {res4[4][WU * 2 - 2 : 0], 1'b0};
    end

    // CSA: 4 -> 3 -> 2
    wire  [WU * 2 - 1 : 0] res5     [4 : 1];
    logic [WU * 2 - 1 : 0] res5_reg [2 : 1];

    add3to2 #(.WIDTH(WU * 2)) csa_5_1 (
        .i0(res4_reg[1]),
        .i1(res4_reg[2]),
        .i2(res4_reg[3]),
        .o0(res5[3]),
        .o1(res5[4])
    );
    add3to2 #(.WIDTH(WU * 2)) csa_5_2 (
        .i0(res4_reg[4]),
        .i1(res5[3]),
        .i2({res5[4][WU * 2 - 2 : 0], 1'b0}),
        .o0(res5[1]),
        .o1(res5[2])
    );

    always @(posedge clk) begin
        res5_reg[1] <= res5[1];
        res5_reg[2] <= {res5[2][WU * 2 - 2 : 0], 1'b0};
    end

    // CSA: 4 -> 3 -> 2
    wire  [WH - 1 : 0] res6     [4 : 1], res7;
    logic [WH - 1 : 0] res6_reg [2 : 1], res7_reg, res8_reg;

    add3to2 #(.WIDTH(WH)) csa_6_1 (
        .i0({res5_reg[1], {WU * 2{1'b0}}}),
        .i1({res5_reg[2], {WU * 2{1'b0}}}),
        .i2(t1[0]),
        .o0(res6[3]),
        .o1(res6[4])
    );
    add3to2 #(.WIDTH(WH)) csa_6_2 (
        .i0(res6[3]),
        .i1({res6[4][WH - 2 : 0], 1'b0}),
        .i2(t1[1]),
        .o0(res6[1]),
        .o1(res6[2])
    );

    addcpred #(.WIDTH(WH), .THRES(80)) add1 (
        .a  (res6_reg[1]),
        .b  (res6_reg[2]),
        .cin(1'b0),
        .o  (res7),
        .cout()
    );

    always @(posedge clk) begin
        res6_reg[1] <= res6[1];
        res6_reg[2] <= {res6[2][WH - 2 : 0], 1'b0};
        res7_reg <= res7;
        res8_reg <= res7_reg;
    end

    // add
    wire [W - 1 : 0] res9;

    addcpred #(.WIDTH(W), .THRES(80)) add2 (
        .a  ({res8_reg, {WH{1'b0}}}),
        .b  (t0),
        .cin(1'b0),
        .o  (res9),
        .cout()
    );

    always @(posedge clk) begin
        c <= res9[WIDTH - 1 : 0];
    end

endmodule
