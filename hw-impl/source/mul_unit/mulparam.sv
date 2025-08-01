`timescale 1ns / 1ps

/*
    parameterized multiplier
    WIDTH must in [256, 640]
    11 cycle
*/

module mulparam
#(parameter integer WIDTH = 256)
(
    input clk,
    input [WIDTH - 1 : 0] a,
    input [WIDTH - 1 : 0] b,
    output logic [WIDTH * 2 - 1: 0] c
);

    // WIDTH must be divided by 8
    localparam integer W = WIDTH % 8 == 0 ? WIDTH : (WIDTH / 8 + 1) * 8;
    localparam integer WH = W / 2;

    wire [W - 1 : 0] x_256, y_256;

    assign x_256 = {{(W - WIDTH){1'b0}}, a};
    assign y_256 = {{(W - WIDTH){1'b0}}, b};

    `define SUB(x, y, z, w, t, u) addcpred #(.WIDTH(w), .THRES(t)) u (\
        .a(x),\
        .b(~y),\
        .cin(1'b1),\
        .o(z),\
        .cout()\
    );

    // ----------------------------------------cycle 1
    // precompute a,b
    localparam integer PIPE_CYCLE = 8;

    wire [WH - 1 : 0] x1_128, x0_128, y1_128, y0_128, a_128, b_128;
    wire          s1, s2, sign;
    logic  [WH - 1 : 0] x1_128_reg, x0_128_reg, y1_128_reg, y0_128_reg, a_128_reg, b_128_reg;
    logic           sign_reg, sign_pipe [PIPE_CYCLE : 1];

    assign {x1_128, x0_128} = x_256;
	assign {y1_128, y0_128} = y_256;

    assign s1 = x0_128 > x1_128;
    assign s2 = y1_128 > y0_128;
    assign sign = s1 ^ s2;	// 0+ 1-

    wire [WH - 1 : 0] ux, vx, uy, vy;
    assign ux = s1 ? x0_128 : x1_128;
    assign vx = s1 ? x1_128 : x0_128;
    assign uy = s2 ? y1_128 : y0_128;
    assign vy = s2 ? y0_128 : y1_128;
    `SUB(ux, vx, a_128, WH, 80, sub128_1);
    `SUB(uy, vy, b_128, WH, 80, sub128_2);

    always @(posedge clk) begin
        x1_128_reg <= x1_128;
        x0_128_reg <= x0_128;
        y1_128_reg <= y1_128;
        y0_128_reg <= y0_128;
        a_128_reg  <= a_128;
        b_128_reg  <= b_128;

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
	
    // ----------------------------------------cycle 2
	// multiply
    wire [W - 1 : 0] z0_256, z2_256, m_256;

    mul_k2 #(.WIDTH(WH)) mul_k2_1 (
        .clk(clk),
        .a(x0_128_reg),
        .b(y0_128_reg),
        .c(z0_256)
    );
    mul_k2 #(.WIDTH(WH)) mul_k2_2 (
        .clk(clk),
        .a(x1_128_reg),
        .b(y1_128_reg),
        .c(z2_256)
    );
    mul_k2 #(.WIDTH(WH)) mul_k2_3 (
        .clk(clk),
        .a(a_128_reg),
        .b(b_128_reg),
        .c(m_256)
    );

    // ----------------------------------------cycle 10
    // accumulate
    wire  [WIDTH * 2 - 1 : 0] z0_t, z2_t, m_t0, m_t, v0, v1, res0, res1, res2;

    assign z0_t = {{WIDTH * 2 - WH * 3{1'b0}}, z0_256, {WH{1'b0}}};
    assign z2_t = {{WIDTH * 2 - WH * 3{1'b0}}, z2_256, {WH{1'b0}}};
    assign m_t0 = {{WIDTH * 2 - WH * 3{1'b0}}, m_256,  {WH{1'b0}}};
    assign m_t = sign_pipe[PIPE_CYCLE] ? ~m_t0 : m_t0;
    
    add3to2 #(.WIDTH(WIDTH * 2)) acc1 (
        .i0(z0_t),
        .i1(z2_t),
        .i2(m_t),
        .o0(v0),
        .o1(v1)
    );
    wire [W*2-1:0]z_t = {z2_256, z0_256};
    add3to2 #(.WIDTH(WIDTH * 2)) acc2 (
        .i0(v0),
        .i1({v1[WIDTH * 2 - 2 : 0], sign_pipe[PIPE_CYCLE]}),
        .i2(z_t[WIDTH*2-1:0]),
        .o0(res0),
        .o1(res1)
    );

    // ----------------------------------------cycle 11
    logic [WIDTH * 2 - 1 : 0] res0_reg, res1_reg;
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
        c <= res2;
    end

endmodule
