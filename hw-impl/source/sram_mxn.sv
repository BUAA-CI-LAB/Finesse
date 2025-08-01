`timescale 1ns/1ps
`include "../define/params.svh"
`include "../define/param_pre.svh"

/* 3 cycle r/d without reset

            ---- --- ----
           |    | m |   |
  wdata -->|    | a |   |
  waddr -->|    | r |   |--> rdata
  raddr -->|    | s |   |
           |    |   |   |
            ---- --- ----

    2 MODE - ASIC/FPGA
    The sram size - 1024x36 : 512x64
*/
module sram_mxn (
    input clk,
    
    // read
    input ren,
    input [`RFSZLOG2-1:0]raddr,
    output[`WORDSZ-1:0]rdata,

    // write
    input wen,
    input [`RFSZLOG2-1:0]waddr,
    input [`WORDSZ-1:0]wdata
);

localparam integer WORDSZ_NUM = `WORDSZ%`DMSLICEW == 0? (`WORDSZ/`DMSLICEW) : (`WORDSZ/`DMSLICEW + 1);
localparam integer WORDSZ_FIXED = WORDSZ_NUM * `DMSLICEW;
localparam integer WORDSZ_DIF = WORDSZ_FIXED - `WORDSZ;

logic[`RFSZLOG2-1:0]wa_r;
logic[`WORDSZ-1:0]wd_r;
logic[`RFSZLOG2-1:0]ra_r;
logic[`WORDSZ-1:0]rd_r;

// write stage 1
always@(posedge clk)begin
    if(wen)begin
        wd_r <= wdata;
        wa_r <= waddr;
    end
    else begin
        wd_r <= 0;
        wa_r <= 0;
    end
end

// read stage 1
always@(posedge clk)begin
    if(ren)begin
        ra_r <= raddr;
    end
    else begin
        ra_r <= 0;
    end
end

localparam integer DMSLSZ1 = `DMSLICESZ == 1024;
// read/write stage 2 3
genvar j;
generate
    if(`ASIC_MODE == 1)begin
        wire [WORDSZ_FIXED-1:0]rd_t_fixed;
        wire [`WORDSZ-1:0]rd_t;
        wire [`WORDSZ-1:0]dmem_out;

        wire [WORDSZ_FIXED-1:0]wd_t_fixed;
        assign wd_t_fixed = {{WORDSZ_DIF{1'b0}},wd_r};
        if(DMSLSZ1)begin // 1024x36
            for(j = 0; j < WORDSZ_NUM; j= j + 1)begin
                sram_1024x36 u_1024x36(
                    .clk(clk),
                    .raddr(ra_r),
                    .waddr(wa_r),
                    .wdata(wd_t_fixed[j*`DMSLICEW +: `DMSLICEW]),
                    .rdata(rd_t_fixed[j*`DMSLICEW +: `DMSLICEW])
                );
            end
        end
        else begin // 512x64
            for(j = 0; j < WORDSZ_NUM; j= j + 1)begin
                sram_512x64 u_512x64(
                    .clk(clk),
                    .raddr(ra_r),
                    .waddr(wa_r),
                    .wdata(wd_t_fixed[j*`DMSLICEW +: `DMSLICEW]),
                    .rdata(rd_t_fixed[j*`DMSLICEW +: `DMSLICEW])
                );
            end
        end
            
        assign rd_t = rd_t_fixed[`WORDSZ-1:0];

        always @(posedge clk) begin
            rd_r <= rd_t;
        end
    end
    else begin // FPGA MODE
        (*ram_style = "block"*)logic[`WORDSZ-1:0]dmem[`RFSZ-1:0];
        logic[`WORDSZ-1:0]rd_t;

        always @(posedge clk) begin
            dmem[wa_r] <= wd_r;
        end

        always @(posedge clk) begin
            rd_t <= dmem[ra_r];
        end

        always @(posedge clk) begin
            rd_r <= rd_t;
        end
    end
endgenerate

assign rdata = rd_r;
    
endmodule