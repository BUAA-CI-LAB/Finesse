
`include "../define/params.svh"
`include "../define/param_pre.svh"
/* instruction fetch
    start high means: start work and need the "func" is ready
*/

module instr_fetch (
    input clk,
    input rst_n,
    input start,
    input [`FUNCIDW-1:0]funcid,

    // to/from instr mem
    output [`IMSZLOG2-1:0]pc_o,
    output iren,
    input [`INSTRW-1:0]instr_i,
    input ins_valid,

    // to/from data fetch
    output [`INSTRW-1:0]instr_o, // delay 2 cycle to update
    input halt,

    // to top
    output run_if   // Indicates that an instruction fetch is running
);

logic [`IMSZLOG2-1:0]pc_reg;
logic run_if_r;
logic start_las;
logic ren_r1,ren_r2;

wire start_up = start & ~start_las;

// start_up: rising of start
always@(posedge clk, negedge rst_n)begin
    if(!rst_n)begin
        start_las <= 0;
    end
    else begin
        start_las <= start;
    end
end

// run_if_r
always@(posedge clk, negedge rst_n)begin
    if(!rst_n)begin
        run_if_r <= 0;
    end
    else begin
        if(halt)begin          // halt instr means end
            run_if_r <= 0;
        end
        else if(start_up)begin   // detect the rise edge delay 3 cycle
            run_if_r <= 1;
        end 
        else begin
            run_if_r <= run_if_r;
        end
    end
end
assign run_if = run_if_r;

// ren_r
always @(posedge clk,negedge rst_n) begin
    if(!rst_n)
        ren_r1 <= 0;
    else
        if(halt)
            ren_r1 <= 0;
        else if(ins_valid && run_if)
            ren_r1 <= 1;
        else
            ren_r1 <= ren_r1;
end
always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        ren_r2 <= 0;
    else
        if(start_up && !run_if)
            ren_r2 <= 1;
        else
            ren_r2 <= 0;
end
assign iren = ren_r1 | ren_r2;

// pc_reg
always @(posedge clk, negedge rst_n) begin
    if(!rst_n)
        pc_reg <= `INITADDR;
    else if(start_up && !run_if)
        pc_reg <= {{(`IMSZLOG2-`FUNCIDW){1'b0}},funcid};
    else if(ins_valid && !iren && run_if) // "!iren" ensure the pc only read im once 
        pc_reg <= instr_i;
    else if((ins_valid || iren) && !halt)
        pc_reg <= pc_reg + 1;   // word(32 bit) addressing not byte addressing
    else if(halt)
        pc_reg <= `INITADDR;
    else
        pc_reg <= pc_reg;
end
assign pc_o = pc_reg;

assign instr_o = instr_i;

endmodule