`timescale 1ns/1ps
`include "../define/params.svh"
`include "../define/param_pre.svh"
// 3 cycle delay pipe out
// its a rom
module instr_mem(
    input clk,
    input rst_n,
    input halt,

    input [`IMSZLOG2-1:0]addr_i,
    input ren,
    output [`INSTRW-1:0]im_o,
    output ins_valid
);

localparam integer IMSISZ1 = `IMSLICESZ == 8192;

generate 
    if(`ASIC_MODE == 0)begin
        (*ram_style = "block"*)logic [`INSTRW-1:0]imem[`IMSZ-1:0];
        logic [`INSTRW-1:0]im_t;
        logic [`INSTRW-1:0]im_tt;
        logic [`IMSZLOG2-1:0]addr_t;
        logic [2:0]ins_valid_r;

        initial $readmemh(`HEX_FILE, imem, 0);

        //addr_t
        always @(posedge clk,negedge rst_n) begin
            if(!rst_n)
                addr_t <= 0;
            else
                if(ren)
                    addr_t <= addr_i;
                else
                    addr_t <= 0;
        end

        //im_t
        always @(posedge clk) begin
            im_t <= imem[addr_t];
        end
        
        assign im_o = im_tt;
        //im_o
        always @(posedge clk, negedge rst_n) begin
            if(!rst_n)
                im_tt <= 0;
            else
                im_tt <= im_t;
        end
    end
    else begin
        localparam integer SLICE_NUM = (`IMSZ % `IMSLICESZ == 0) ? `IMSZ/`IMSLICESZ : `IMSZ/`IMSLICESZ + 1;
        wire  [$clog2(`IMSLICESZ) - 1:0]addr_t[SLICE_NUM];
        wire  [SLICE_NUM - 1:0]ce_t;
        logic [SLICE_NUM - 1:0]ce_r;
        logic [SLICE_NUM - 1:0]ce_r1;
        logic [$clog2(`IMSLICESZ) - 1:0]addr_r[SLICE_NUM];
        wire  [`INSTRW - 1:0]i_out[SLICE_NUM];
        wire  [`INSTRW - 1:0]im_t;
        logic [`INSTRW - 1:0]im_r;
        genvar i;
        // pipeline - 1 : addr_r
        for(i = 0; i < SLICE_NUM; i = i + 1)begin
            assign addr_t[i] = (addr_i[`IMSZLOG2-1:$clog2(`IMSLICESZ)] == i)? addr_i[$clog2(`IMSLICESZ) - 1:0] : {$clog2(`IMSLICESZ){1'b0}};
            assign ce_t[i] = (addr_i[`IMSZLOG2-1:$clog2(`IMSLICESZ)] == i)? 1'b1:1'b0;
            always @(posedge clk, negedge rst_n) begin
                if(!rst_n) begin
                    addr_r[i] <= 0;
                    ce_r[i] <= 0;
                end
                else
                    if(ren) begin
                        addr_r[i] <= addr_t[i];
                        ce_r[i] <= ce_t[i];
                    end
                    else begin
                        addr_r[i] <= 0;
                        ce_r[i] <= 0;
                    end
            end
        end
        // pipeline - 2 : read rom
        if(IMSISZ1)begin
            for(i = 0; i < SLICE_NUM; i = i + 1)begin
                sram_8192x36 #(
                    .hexfile_init(i*`IMSLICESZ)
                ) u_rom(
                    .clk(clk),
                    .ce(1'b1),
                    .addr(addr_r[i]),
                    .i_out(i_out[i])
                );
            end
        end
        else begin
            for(i = 0; i < SLICE_NUM; i = i + 1)begin
                sram_4096x32 #(
                    .hexfile_init(i*`IMSLICESZ)
                ) u_rom(
                    .clk(clk),
                    .ce(1'b1),
                    .addr(addr_r[i]),
                    .i_out(i_out[i])
                );
            end
        end

        always @(posedge clk) begin
            ce_r1 <= ce_r;
        end

        // pipeline - 3 : or all
        wire [`INSTRW-1:0]im_w[SLICE_NUM];
        assign im_w[0] = {`INSTRW{ce_r1[ 0]}} & i_out[ 0];
        for(i = 1; i < SLICE_NUM; i = i + 1)begin
            assign im_w[i] = im_w[i-1] | {`INSTRW{ce_r1[i]}} & i_out[i];
        end
        assign im_t = im_w[SLICE_NUM-1];

        always @(posedge clk, negedge rst_n) begin
            if(!rst_n)
                im_r <= 0;
            else
                im_r <= im_t;
        end
        assign im_o = im_r;
    end
endgenerate

//ins_valid_r
logic [2:0]ins_valid_r;
always@(posedge clk,negedge rst_n)begin
    if(!rst_n)
        ins_valid_r <= 0;
    else
        if(halt)
            ins_valid_r <= 0;
        else if(ren)
            ins_valid_r <= {ins_valid_r[1:0],1'b1};
        else
            ins_valid_r <= {ins_valid_r[1:0],1'b0};
end
assign ins_valid = ins_valid_r[2];

endmodule
