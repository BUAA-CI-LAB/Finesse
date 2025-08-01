`timescale 1ns/1ps
`include "../define/params.svh"
`include "../define/param_pre.svh"

module data_ex(
    input clk,
    input rst_n,

    // instr
    input ins_valid,
    input [`INSTRW-1:0]instr_if,
    input run_if,
    output halt_if,

    // io
    input wen_io,
    input [`RFSZLOG2-1:0]waddr_io,
    input [`WORDSZ-1:0]wdata_io,
    input ren_io,
    input [`RFSZLOG2-1:0]raddr_io,
    output [`WORDSZ-1:0]rdata_io,

    input busy,
    output run_ex
);

wire ren_dm_0;
wire [`RFSZLOG2-1:0]raddr_dm_0;
wire [`WORDSZ-1:0]op_dm_0;
wire ren_dm_1;
wire [`RFSZLOG2-1:0]raddr_dm_1;
wire [`WORDSZ-1:0]op_dm_1;

wire halt_ex;
wire [`INS_FUNC-1:0]func_op;
wire ex_valid;
wire [`WORDSZ-1:0]op_ex_0;
wire [`WORDSZ-1:0]op_ex_1;
wire [`RFSZLOG2-1:0]rn_ex_0;

wire wen_alu;
wire [`RFSZLOG2-1:0]waddr_alu;
wire [`WORDSZ-1:0]res_alu;
 

data_mem u_dm(
    .clk(clk),
    
    // begin from ifetch, end with execute unit
    // indicate the micro is runing
    .busy(busy),

    // to data fetch
    .ren_df_0(ren_dm_0),
    .raddr_df_0(raddr_dm_0),
    .op_df_0(op_dm_0),
    .ren_df_1(ren_dm_1),
    .raddr_df_1(raddr_dm_1),
    .op_df_1(op_dm_1),

    // from alu ex res
    .wen_alu(wen_alu),
    .waddr_alu(waddr_alu),
    .res_alu(res_alu),

    // from interface
    .wen_io(wen_io),
    .waddr_io(waddr_io),
    .data_in(wdata_io),
    .ren_io(ren_io),
    .raddr_io(raddr_io),
    .data_out(rdata_io)
);

data_fetch u_df(
    .clk(clk),
    .rst_n(rst_n),
    // from/to ifetch
    .ins_valid(ins_valid),
    .instr(instr_if),
    .halt_if(halt_if),
    // to/from datamem
    .ren_dm_0(ren_dm_0),
    .raddr_dm_0(raddr_dm_0),
    .op_dm_0(op_dm_0),
    .ren_dm_1(ren_dm_1),
    .raddr_dm_1(raddr_dm_1),
    .op_dm_1(op_dm_1),
    // to execute unit
    .halt_ex(halt_ex), // delay 3 cycles halt to execute unit
    .func_op(func_op),
    .ex_valid(ex_valid),
    .op_ex_0(op_ex_0),
    .op_ex_1(op_ex_1),
    .rn_ex_0(rn_ex_0)
);

execute_unit u_ex(
    .clk(clk),
    .rst_n(rst_n),
    .run_if(run_if),
    .halt_ex(halt_ex),
    .func_op(func_op),
    .ex_valid(ex_valid),
    .op_0(op_ex_0),
    .op_1(op_ex_1),
    .rn_df(rn_ex_0),
    .wen_ex(wen_alu),
    .waddr_ex(waddr_alu),
    .res_ex(res_alu),

    .run_ex(run_ex)
);
// localparam integer test_mod = `test_mode;
// test the data
generate
    if(`TEST_MODE)begin
        integer file_handle = $fopen("data_out.txt","w");
        integer i = 0;
        always @(posedge clk) begin
            if(wen_alu == 1)begin
                $fwrite(file_handle,"%6d %3d <= %64h\n",i,waddr_alu,res_alu);
                i = i + 1;
                if(run_ex == 1 && wen_alu == 0)
                    i = i + 1;
            end
        end
    end
endgenerate
endmodule