`timescale 1ns / 1ps
`include "../define/params.svh"
`include "../define/param_pre.svh"
/*
    Time : WORDSIZE * 2 + 1(check) + 1(input) + 3(read im) + 1(write res) cycle *not pipeline*
*/
module modinv #(
    parameter thres = 160
)(
        input clk,
        input rst_n,
        input en,
        input [`WORDSZ-1:0] a0,
        input [`RFSZLOG2-1:0] rn0,
        output [`RFSZLOG2-1:0] rn,
        output [`WORDSZ-1:0] res,
        output done
    );
    logic [`WORDSZ:0] u, v, r, s;
    wire [`WORDSZ:0] r2 = {r[`WORDSZ-1:0], 1'b0};
    logic [$clog2(`WORDSZ*2):0] cnt;
    logic [`RFSZLOG2-1:0] rnr;
    logic dd, run, check;
    assign done = dd;
    assign rn = dd ? rnr : '0;
    assign res = dd ? r[`WORDSZ-1:0] : '0;

    wire [`WORDSZ-1:0]mod_p = `P;
    wire [`WORDSZ:0]t1, t2, t3, t4, t5;

    // t1 = u - v
    addcpred #(.WIDTH(`WORDSZ+1), .THRES(thres))
        add1(.a(u), .b({1'b1,~v[`WORDSZ-1:0]} + 1), .cin(1'b0), .o(t1), .cout());

    // t2 = r + s
    addcpred #(.WIDTH(`WORDSZ+1), .THRES(thres))
        add2(.a(r), .b(s), .cin(1'b0), .o(t2), .cout());

    // t3 = v - u
    addcpred #(.WIDTH(`WORDSZ+1), .THRES(thres))
        add3(.a(v), .b({1'b1,~u[`WORDSZ-1:0]} + 1), .cin(1'b0), .o(t3), .cout());

    // t4 = r - mod_p
    addcpred #(.WIDTH(`WORDSZ+1), .THRES(thres))
        add4(.a(r), .b({1'b1,~mod_p} + 1), .cin(1'b0), .o(t4), .cout());

    // t5 = r*2 - mod_p
    addcpred #(.WIDTH(`WORDSZ+1), .THRES(thres))
        add5(.a(r2), .b({1'b1,~mod_p} + 1), .cin(1'b0), .o(t5), .cout());

    always @(posedge clk,negedge rst_n) begin
        if (!rst_n) begin
            {u, v, r, s, cnt, rnr, dd, run, check} <= '0;
        end else begin
            // if (en) $stop();
            if (!run && en) begin
                rnr <= rn0;
                u <= {1'b0, a0};
                v <= {1'b0, mod_p};
                r <= 1;
                s <= 0;
                cnt <= 0;
                dd <= 0;
                run <= 1;
                check <= 1;
            end else if (run) begin
                if (|v) begin
                    if (u[0] == 1'b0) begin
                        u <= {1'b0, u[`WORDSZ:1]};
                        s <= {s[`WORDSZ-1:0], 1'b0};
                        cnt <= cnt + 1;
                    end else if (v[0] == 1'b0) begin
                        v <= {1'b0, v[`WORDSZ:1]};
                        r <= {r[`WORDSZ-1:0], 1'b0};
                        cnt <= cnt + 1;
                    end else if (u > v) begin
                        u <= {1'b0,t1[`WORDSZ:1]};  // u = (u-v)/2
                        r <= t2;                    // r = (r+s)
                        s <= {s[`WORDSZ-1:0], 1'b0};// s = 2s
                        cnt <= cnt + 1;
                    end else begin
                        v <= {1'b0,t3[`WORDSZ:1]};  // v = (v-u)/2
                        s <= t2;                    // s = (r+s)
                        r <= {r[`WORDSZ-1:0], 1'b0};// r = 2r
                        cnt <= cnt + 1;
                    end
                end else if (check) begin
                    check <= 0;
                    r <= (r >= mod_p) ? (t4) : r;   // t4 = r - p
                end else if (cnt < `WORDSZ * 2) begin
                    cnt <= cnt + 1;
                    r <= (r2 >= mod_p) ? t5 : r2;   // t5 = r2 - p
                    if (cnt == `WORDSZ * 2 - 1) begin
                        dd <= 1'b1;
                        run <= 1'b0;
                    end
                end
            end else if (dd) begin
                {u, v, r, s, cnt, rnr, dd, run, check} <= '0;
            end
        end
    end


endmodule
