`timescale 1ns / 1ps

/*
    64 ~ 160 bit karatsuba multiplier
    5 cycle
*/

module mul_k3
#(parameter integer WIDTH = 64)
(
    input clk,
    input [WIDTH - 1 : 0] a,
    input [WIDTH - 1 : 0] b,
    output [WIDTH * 2 - 1 : 0] c
);

    localparam integer WH = WIDTH / 2;

    `define SUB(x, y, z, w, t, u) addcpred #(.WIDTH(w), .THRES(t)) u (\
        .a(x),\
        .b(~y),\
        .cin(1'b1),\
        .o(z),\
        .cout()\
    );

    // ----------------------------------------cycle 3
    // precompute a,b
    localparam integer PIPE_CYCLE = 2;

    wire [WH - 1 : 0] x1_32, x0_32, y1_32, y0_32, a_32, b_32;
    wire          s1, s2, sign;
    logic [WH - 1 : 0] x1_32_reg, x0_32_reg, y1_32_reg, y0_32_reg, a_32_reg, b_32_reg;
    logic               sign_reg, sign_pipe [PIPE_CYCLE : 1];

    assign {x1_32, x0_32} = a;
	assign {y1_32, y0_32} = b;
	
    assign s1 = x0_32 > x1_32;
    assign s2 = y1_32 > y0_32;
    assign sign = s1 ^ s2;	// 0+ 1-

    wire [WH - 1 : 0] ux, vx, uy, vy;
    assign ux = s1 ? x0_32 : x1_32;
    assign vx = s1 ? x1_32 : x0_32;
    assign uy = s2 ? y1_32 : y0_32;
    assign vy = s2 ? y0_32 : y1_32;
    `SUB(ux, vx, a_32, WH, 80, sub32_1);
    `SUB(uy, vy, b_32, WH, 80, sub32_2);

    always @(posedge clk) begin
        x1_32_reg <= x1_32;
        x0_32_reg <= x0_32;
        y1_32_reg <= y1_32;
        y0_32_reg <= y0_32;
        a_32_reg  <= a_32;
        b_32_reg  <= b_32;

        sign_reg <= sign;
        sign_pipe[1] <= sign_reg;
    end

    genvar i;
    generate
        for(i = 2; i <= PIPE_CYCLE; i = i + 1) begin
            always @(posedge clk) begin
                sign_pipe[i] <= sign_pipe[i - 1];
            end
        end
    endgenerate

    // ----------------------------------------cycle 4
	// multiply
    wire [WIDTH - 1 : 0] z0_64, z2_64, m_64;

    mul32_80 #(.WIDTH(WH)) mul_32_80_1 (
        .clk(clk),
        .a(x0_32_reg),
        .b(y0_32_reg),
        .c(z0_64)
    );
    mul32_80 #(.WIDTH(WH)) mul_32_80_2 (
        .clk(clk),
        .a(x1_32_reg),
        .b(y1_32_reg),
        .c(z2_64)
    );
    mul32_80 #(.WIDTH(WH)) mul_32_80_3 (
        .clk(clk),
        .a(a_32_reg),
        .b(b_32_reg),
        .c(m_64)
    );

    // ----------------------------------------cycle 6
	// accumulate
    wire  [WIDTH * 2 - 1 : 0] z0_t, z2_t, m_t0, m_t, v0, v1, res0, res1, res2;

    assign z0_t = {{WIDTH * 2 - WH * 3{1'b0}}, z0_64, {WH{1'b0}}};
    assign z2_t = {{WIDTH * 2 - WH * 3{1'b0}}, z2_64, {WH{1'b0}}};
    assign m_t0 = {{WIDTH * 2 - WH * 3{1'b0}}, m_64,  {WH{1'b0}}};
    assign m_t = sign_pipe[PIPE_CYCLE] ? ~m_t0 : m_t0;
    
    add3to2 #(.WIDTH(WIDTH * 2)) acc1 (
        .i0(z0_t),
        .i1(z2_t),
        .i2(m_t),
        .o0(v0),
        .o1(v1)
    );

    add3to2 #(.WIDTH(WIDTH * 2)) acc2 (
        .i0(v0),
        .i1({v1[WIDTH * 2 - 2 : 0], sign_pipe[PIPE_CYCLE]}),
        .i2({z2_64, z0_64}),
        .o0(res0),
        .o1(res1)
    );

    // ----------------------------------------cycle 7
    logic [WIDTH * 2 - 1 : 0] res0_reg, res1_reg, ans_128_reg;
    addcpred #(.WIDTH(WIDTH * 2), .THRES(80)) add2 (
        .a  (res0_reg),
        .b  (res1_reg),
        .cin(1'b0),
        .o  (res2),
        .cout()
    );

    always @(posedge clk) begin
        res0_reg <= res0;
        res1_reg <= {res1[WIDTH * 2 - 2 : 0], 1'b0};
        ans_128_reg <= res2;
    end

    assign c = ans_128_reg;
    
endmodule
