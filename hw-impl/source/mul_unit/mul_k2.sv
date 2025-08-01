`timescale 1ns / 1ps

/*
    128 ~ 320 bit karatsuba multiplier
    8 cycle
*/

module mul_k2
#(parameter integer WIDTH = 128)
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

    // ----------------------------------------cycle 2
    // precompute a,b
    localparam integer PIPE_CYCLE = 5;

    wire [WH - 1 : 0] x1_64, x0_64, y1_64, y0_64, a_64, b_64;
    wire          s1, s2, sign;
    logic  [WH - 1 : 0] x1_64_reg, x0_64_reg, y1_64_reg, y0_64_reg, a_64_reg, b_64_reg;
    logic           sign_reg, sign_pipe [PIPE_CYCLE : 1];

    assign {x1_64, x0_64} = a;
	assign {y1_64, y0_64} = b;

    assign s1 = x0_64 > x1_64;
    assign s2 = y1_64 > y0_64;
    assign sign = s1 ^ s2;	// 0+ 1-

    wire [WH - 1 : 0] ux, vx, uy, vy;
    assign ux = s1 ? x0_64 : x1_64;
    assign vx = s1 ? x1_64 : x0_64;
    assign uy = s2 ? y1_64 : y0_64;
    assign vy = s2 ? y0_64 : y1_64;
    `SUB(ux, vx, a_64, WH, 80, sub64_1);
    `SUB(uy, vy, b_64, WH, 80, sub64_2);

    always @(posedge clk) begin
        x1_64_reg <= x1_64;
        x0_64_reg <= x0_64;
        y1_64_reg <= y1_64;
        y0_64_reg <= y0_64;
        a_64_reg  <= a_64;
        b_64_reg  <= b_64;

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
	
    // ----------------------------------------cycle 3
	// multiply
    wire [WIDTH - 1 : 0] z0_128, z2_128, m_128;

    mul_k3 #(.WIDTH(WH)) mul_k3_1 (
        .clk(clk),
        .a(x0_64_reg),
        .b(y0_64_reg),
        .c(z0_128)
    );
    mul_k3 #(.WIDTH(WH)) mul_k3_2 (
        .clk(clk),
        .a(x1_64_reg),
        .b(y1_64_reg),
        .c(z2_128)
    );
    mul_k3 #(.WIDTH(WH)) mul_k3_3 (
        .clk(clk),
        .a(a_64_reg),
        .b(b_64_reg),
        .c(m_128)
    );

    // ----------------------------------------cycle 8
    // accumulate
    wire  [WIDTH * 2 - 1 : 0] z0_t, z2_t, m_t0, m_t, v0, v1, res0, res1, res2;
    assign z0_t = {{WIDTH * 2 - WH * 3{1'b0}}, z0_128, {WH{1'b0}}};
    assign z2_t = {{WIDTH * 2 - WH * 3{1'b0}}, z2_128, {WH{1'b0}}};
    assign m_t0 = {{WIDTH * 2 - WH * 3{1'b0}}, m_128,  {WH{1'b0}}};
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
        .i2({z2_128, z0_128}),
        .o0(res0),
        .o1(res1)
    );

    // ----------------------------------------cycle 9
    logic [WIDTH * 2 - 1 : 0] res0_reg, res1_reg, ans_256_reg;

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
        ans_256_reg <= res2;
    end
    
    assign c = ans_256_reg;

endmodule
