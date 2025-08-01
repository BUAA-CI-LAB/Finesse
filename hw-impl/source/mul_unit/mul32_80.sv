`timescale 1ns / 1ps

/*
    parameterized multiplier, the minimum module for karatsuba
    WIDTH must in [32, 80]
    2 cycle
*/

module mul32_80
#(parameter integer WIDTH = 32)
(
    input clk,
    input [WIDTH - 1 : 0] a,
    input [WIDTH - 1 : 0] b,
    output logic [WIDTH * 2 - 1 : 0] c
);

    localparam integer MUL_UNIT_WIDTH = 16;
    localparam integer MUL_UNIT_NUM = WIDTH % MUL_UNIT_WIDTH == 0 ? WIDTH / MUL_UNIT_WIDTH : WIDTH / MUL_UNIT_WIDTH + 1;    // [2 : 5]
    localparam integer WIDTH_FULL = MUL_UNIT_NUM * MUL_UNIT_WIDTH;

    genvar i, j, k;

    /********************************** cycle 1 **********************************/
    // split a, b to a1[], b1[]
    wire [MUL_UNIT_WIDTH - 1 : 0] a1 [MUL_UNIT_NUM - 1 : 0];
    wire [MUL_UNIT_WIDTH - 1 : 0] b1 [MUL_UNIT_NUM - 1 : 0];

    generate
        for (i = 0; i < MUL_UNIT_NUM; i++) begin
            if (i == MUL_UNIT_NUM - 1) begin
                assign a1[i] = a[WIDTH - 1 : MUL_UNIT_WIDTH * i];
                assign b1[i] = b[WIDTH - 1 : MUL_UNIT_WIDTH * i];
            end
            else begin
                assign a1[i] = a[MUL_UNIT_WIDTH * i +: MUL_UNIT_WIDTH];
                assign b1[i] = b[MUL_UNIT_WIDTH * i +: MUL_UNIT_WIDTH];
            end
        end
    endgenerate

    // mult a1, b1
    wire [MUL_UNIT_WIDTH * 2 - 1 : 0] res [MUL_UNIT_NUM - 1 : 0][MUL_UNIT_NUM - 1 : 0];

    generate
        for (i = 0; i < MUL_UNIT_NUM; i++) begin
            for (j = 0; j < MUL_UNIT_NUM; j++) begin
                mul16 blk (.clk(clk), .a(a1[i]), .b(b1[j]), .c(res[i][j]));
            end
        end
    endgenerate

    /********************************** cycle 2 **********************************/
    // abstract each diagonal block as t0
    localparam integer T0_NUM = MUL_UNIT_NUM * 2 - 1;

    wire [WIDTH_FULL * 2 - 1 : 0] t0 [T0_NUM : 1];     

    // central diagonal
    generate
        for (i = 0; i < MUL_UNIT_NUM; i++) begin
            assign t0[1][MUL_UNIT_WIDTH * 2 * i +: MUL_UNIT_WIDTH * 2] = res[i][i];
        end
    endgenerate

    // upper triangular
    generate
        for (k = 1; k < MUL_UNIT_NUM; k++) begin
            localparam integer t0_cnt = k + 1;
            assign t0[t0_cnt][0 +: MUL_UNIT_WIDTH * k] = 0;   // low bit = 0
            for (i = k; i < MUL_UNIT_NUM; i++) begin   // column   
                localparam integer j = i - k;       // row
                assign t0[t0_cnt][MUL_UNIT_WIDTH * k + MUL_UNIT_WIDTH * 2 * j +: MUL_UNIT_WIDTH * 2] = res[j][i];
            end
            assign t0[t0_cnt][WIDTH_FULL * 2 - 1 -: MUL_UNIT_WIDTH * k] = 0;   // high bit = 0
        end
    endgenerate

    // lower triangular
    generate
        for (k = 1; k < MUL_UNIT_NUM; k++) begin
            localparam integer t0_cnt = k + 1 + MUL_UNIT_NUM - 1;
            assign t0[t0_cnt][0 +: MUL_UNIT_WIDTH * k] = 0;   // low bit = 0
            for (i = k; i < MUL_UNIT_NUM; i++) begin   // row 
                localparam integer j = i - k;       // column
                assign t0[t0_cnt][MUL_UNIT_WIDTH * k + MUL_UNIT_WIDTH * 2 * j +: MUL_UNIT_WIDTH * 2] = res[i][j];
            end
            assign t0[t0_cnt][WIDTH_FULL * 2 - 1 -: MUL_UNIT_WIDTH * k] = 0;   // high bit = 0
        end
    endgenerate

    // how many add3to2 are needed each cycle
    localparam integer ADD3TO2_TOTAL_NUM = MUL_UNIT_NUM == 2 ? 1 :
                                           MUL_UNIT_NUM == 3 ? 3 : 4;
    localparam integer cycle2_num = ADD3TO2_TOTAL_NUM;

    localparam integer T1_WIRE_NUM[5] = MUL_UNIT_NUM == 2 ? {3, 2, 0, 0, 0} :
                                        MUL_UNIT_NUM == 3 ? {5, 4, 3, 2, 0} :
                                        MUL_UNIT_NUM == 4 ? {7, 5, 4, 3, 2} :
                                                            {9, 6, 4, 3, 2} ;

    wire  [WIDTH * 2 - 1 : 0] t1 [cycle2_num : 0][T1_WIRE_NUM[0] : 1];   // t1 [layer][num]

    generate
        // initial t1[0]
        for (i = 1; i <= T1_WIRE_NUM[0]; i++) begin
            assign t1[0][i] = t0[i];
        end

        // calculate t1[1 ~ cycle2_num]   e.g. 7 -> 5 -> 4 -> 3 -> 2
        for (k = 1; k <= cycle2_num; k++) begin  // the k-th layer of add3to2
            localparam integer add3to2_num = T1_WIRE_NUM[k - 1] / 3;    // e.g. 2

            // use add3to2 module   e.g. [6:1] -> [4:1]
            for (i = 0; i < add3to2_num; i++) begin     // e.g. [0, 1]
                wire [WIDTH * 2 - 1 : 0] tmp;
                assign t1[k][i * 2 + 2] = {tmp[WIDTH * 2 - 2 : 0], 1'b0};

                add3to2 #(.WIDTH(WIDTH * 2)) 
                adder (
                    .i0(t1[k - 1][i * 3 + 1]),
                    .i1(t1[k - 1][i * 3 + 2]),
                    .i2(t1[k - 1][i * 3 + 3]),
                    .o0(t1[k][i * 2 + 1]),
                    .o1(tmp)
                );
            end

            // remaining wire   e.g. [7] -> [5]
            for (i = 0; i < T1_WIRE_NUM[k - 1] - add3to2_num * 3; i++) begin
                assign t1[k][T1_WIRE_NUM[k] - i] = t1[k - 1][T1_WIRE_NUM[k - 1] - i];
            end
        end
    endgenerate

    wire [WIDTH * 2 - 1 : 0] ans;

    // 64 ~ 160 bit add
    addcpred #(.WIDTH(WIDTH * 2), .THRES(80)) cpa (
        .a(t1[cycle2_num][1]),
        .b(t1[cycle2_num][2]),
        .cin(1'b0),
        .o(ans),
        .cout()
    );

    always @(posedge clk) begin
        c <= ans;
    end

endmodule
