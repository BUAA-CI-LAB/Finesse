`timescale 1ns / 1ps
`include "../define/params.svh"
`include "../define/param_pre.svh"
/*

*/
// parameterized modular multiplication
// 34 cycle with output register

module modmul #(
    thres = 160
)(
    input clk,
    input rst_n,
    input en,
    input [`WORDSZ-1:0] a0,
    input [`WORDSZ-1:0] b0,
    input [`RFSZLOG2-1:0] rn0,
    output[`RFSZLOG2-1:0] rn,
    output logic [`WORDSZ-1:0] res
);

/*
pipeline stage: (lo(x) = x[`WORDSZ:0]; hi(x) = x[`WORDSZ*2-1:`WORDSZ];)
C_mid = a0 * b0
U = lo(C_mid) * P'
T = C_mid + lo(U) * P  : Note: The [`WORDSZ-1:0] bits of T must be 0
R = hi(T)  is *NOT* (hi(C_mid) + hi(lo(U)*P)) because there may be a carry in the lower bits!!
--
if R > P then res = (R - P) else res = R
*/
    logic[`WORDSZ-1:0]a_reg,b_reg;
    // stage - 1 
    always @(posedge clk, negedge rst_n) begin
        if(!rst_n)begin
            a_reg <= 0;
            b_reg <= 0;
        end
        else begin
            if(en)begin
                a_reg <= a0;
                b_reg <= b0;
            end
            else begin
                a_reg <= 0;
                b_reg <= 0;
            end
        end
    end

    wire [`WORDSZ*2-1:0] C_mid_t;
    //  - pipe - mulplication
    mulparam #(`WORDSZ)
        mul1(.clk(clk),.a(a_reg),.b(b_reg),.c(C_mid_t));
    
    wire [`WORDSZ-1:0] Chi, Clo;
    assign {Chi, Clo} = C_mid_t;
    
    // 9 cycle
    wire [`WORDSZ-1:0] Ulo;
    mulparamlo #(.WIDTH(`WORDSZ)) 
        mul2(.clk(clk), .a(Clo), .b(`P_NEGINV_R), .c(Ulo));

    // lo(U)*P = W
    wire [`WORDSZ*2-1:0] W;
    
    mulparam #(`WORDSZ)
        mul3(.clk(clk),.a(Ulo[`WORDSZ-1:0]),.b(`P),.c(W));

    localparam PIPE_CYCLE_NUM = 9 + 11;
    logic [`WORDSZ:0] C_pipe[PIPE_CYCLE_NUM : 1];
    
    genvar i;
    generate;
        always @(posedge clk) begin
            C_pipe[1] <= {Chi, {|{Clo}}};
        end
        for (i = 2; i <= PIPE_CYCLE_NUM; i++) begin
            always @(posedge clk) begin
                C_pipe[i] <= C_pipe[i - 1];
            end
        end
    endgenerate

    // T = Chi + Whi + carry(Clo + Wlo)
    wire [`WORDSZ:0] V2_w;
    wire [`WORDSZ+1:0] V2_reduced;
    logic [`WORDSZ:0] V2;
    addcpred #(.WIDTH(`WORDSZ), .THRES(thres)) cpa (
        .a(C_pipe[PIPE_CYCLE_NUM][`WORDSZ:1]),
        .b(W[`WORDSZ*2-1:`WORDSZ]),
        .cin(C_pipe[PIPE_CYCLE_NUM][0]),
        .o(V2_w[`WORDSZ-1:0]),
        .cout(V2_w[`WORDSZ])
    );

    // stage - `MODMUL - 1
    // T - P = T + (2^256 - P)
     addcpred #(.WIDTH(`WORDSZ+1), .THRES(thres))
        cpae(.a(V2), .b({1'b0, `P_COMP}), .cin(1'b0),
        .o(V2_reduced[`WORDSZ:0]), .cout(V2_reduced[`WORDSZ+1]));

    // stage - `MODMUL
    always @(posedge clk, negedge rst_n) begin
        if(!rst_n)begin
            res <= 0;
            V2 <= 0;
        end
        else begin
            V2 <= V2_w;
            res <= ((V2 < `P) ? V2[`WORDSZ-1:0] : V2_reduced[`WORDSZ-1:0]);
        end
    end

/*
pipe object addr `MODMUL cycle
*/
logic [`RFSZLOG2-1:0]rn_t[`MODMUL-1:0];
genvar j;
generate
    always@(posedge clk, negedge rst_n)begin
        if(!rst_n)
                rn_t[0] <= 0;
        else
            if(en)
                rn_t[0] <= rn0;
            else
                rn_t[0] <= 0;
    end
                
    for(j=1;j<`MODMUL;j=j+1)begin
        always@(posedge clk, negedge rst_n)begin
            if(!rst_n)
                rn_t[j] <= 0;
            else
                rn_t[j] <= rn_t[j-1];
        end
    end
endgenerate
assign rn = rn_t[`MODMUL-1];
endmodule
