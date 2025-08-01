`timescale 1ns / 1ps
`include "../define/params.svh"
`include "../define/param_pre.svh"

module micro_top_tb();
    logic clk, rst_n;
    logic [`FUNCIDW-1:0] funcid;
    logic start;
    logic [`CORELOG2-1:0]chip_sel;
    logic wen, ren;
    logic [`PORTAW-1:0] waddr;
    logic [`PORTW-1:0] wdata;
    logic [`PORTAW-1:0] raddr;
    wire [`PORTW-1:0] rdata;
    
    wire busy;
    wire rdata_valid;

    micro_top u_micro_top(
        .clk(clk),
        .rst_n(rst_n),
        .chip_sel(chip_sel),
        .funcid(funcid),
        .start(start),
        .wen(wen),
        .waddr(waddr),
        .wdata(wdata),
        .ren(ren),
        .raddr(raddr),
        .rdata(rdata),
        .rdata_valid(rdata_valid),
        .busy(busy)
    );

always #5 clk = ~clk;

parameter SERSZ = `WORDSZ % `PORTW == 0 ? `WORDSZ / `PORTW : `WORDSZ / `PORTW + 1; 

initial begin
    clk = 0;
    rst_n = 1;
    chip_sel = 0;
    funcid = 0;
    start = 0;
    wen = 0;
    ren = 0;
    waddr = 0;
    wdata = 0;
    raddr = 0;
end

    task write_to_uut(input [`RFSZLOG2-1:0] addr, input [`WORDSZ-1:0] data);
        integer i;
        for (i = 0; i < SERSZ; ++i) begin
            @(posedge clk) #1;
            wen = 1'b1;
            waddr = (addr << (5)) + i;
            wdata = data[i*`PORTW +: `PORTW];
        end
        @(posedge clk) #1;
        wen = 1'b0;
    endtask
    parameter maxs = (SERSZ-1)*`PORTW;
    logic [`WORDSZ-1:0] read_tmp, start_time, end_time;
    initial read_tmp <= '0;
     task read_from_uut(input [`RFSZLOG2-1:0] addr, output [`WORDSZ-1:0] data);
        integer i,j;
        j = 0;
        for (i = 0; i < SERSZ; ++i) begin
            @(posedge clk) #1;
            ren = 1'b1;
            raddr = (addr << (5)) + i;
            if (rdata_valid == 1)begin
                data[j*`PORTW +: `PORTW] = rdata;
                j = j + 1;
            end 
        end
        @(posedge clk) #1;
        ren <= 1'b0;
        raddr <= '0;
        if (rdata_valid == 1)begin
            if(j*`PORTW > `WORDSZ - `PORTW)begin
                data[`WORDSZ-1 : maxs] = rdata;
                j = j + 1;
            end
            else begin
                data[j*`PORTW +: `PORTW] = rdata;
                j = j + 1;
            end
        end 
        @(posedge clk) #1;
        if (rdata_valid == 1)begin
            if(j*`PORTW > `WORDSZ - `PORTW)begin
                data[`WORDSZ-1 : maxs] = rdata;
                j = j + 1;
            end
            else begin
                data[j*`PORTW +: `PORTW] = rdata;
                j = j + 1;
            end
        end 
        @(posedge clk) #1;
        if (rdata_valid == 1)begin
            if(j*`PORTW > `WORDSZ - `PORTW)begin
                data[`WORDSZ-1 : maxs] = rdata;
                j = j + 1;
            end
            else begin
                data[j*`PORTW +: `PORTW] = rdata;
                j = j + 1;
            end
        end 
        @(posedge clk) #1;
        if (rdata_valid == 1)begin
            if(j*`PORTW > `WORDSZ - `PORTW)begin
                data[`WORDSZ-1 : maxs] = rdata;
                j = j + 1;
            end
            else begin
                data[j*`PORTW +: `PORTW] = rdata;
                j = j + 1;
            end
        end 
    endtask


    task expect_output(input [`WORDSZ-1:0] expected);
       $display("[%s]\t%h", read_tmp == expected ? "  Accepted  " : "Wrong Answer", read_tmp); 
    endtask
integer begin_time = 0;
initial begin
    #(10) $display("----begin simulation----");
    @(posedge busy);
    repeat (`IMSZ/10000 + 5) #(10000 * 10) $display("now approximate rate of progress is %3d%%",($time - start_time)*10/`IMSZ);
    #(20000 * 10) $display("----time out----");
    $stop;
end

initial begin
    @(posedge clk) #1;
    rst_n = 1'b0;
    #300;
    @(posedge clk) #1;
    rst_n = 1'b1;
    funcid = 0;
    start = 0;
    @(posedge clk) #1;


    @(posedge clk);
    repeat(`CORE_NUM) begin
        // const
        for(integer i=0;i < `CONST_NUM;i = i + 1)begin
            write_to_uut(i, const_datas[i]);
        end

        // input
        for(integer i=`CONST_NUM;i < `CONST_NUM + `TEST_INPUTS_NUM;i = i + 1)begin
            write_to_uut(i, test_inputs[i-`CONST_NUM]);
        end
        #1 chip_sel = chip_sel + 1;
    end
    @(posedge clk) #1;
    wen <= 1'b0;
    waddr <= '0;
    wdata <= '0;
    @(posedge clk) #1;
    @(posedge clk) #1;
    funcid <= 6'd1;
    start <= 1;
    @(posedge busy);
    start_time <= $time;
    @(posedge clk) #1;
    funcid <= 0;
    start <= 0;
    @(negedge busy);
    end_time = $time;
    chip_sel = 0;
    // output
    $display("------- %2d Pairing Done and time is [%10d]cycles -------",`CORE_NUM,(end_time - start_time)/10);
    repeat(`CORE_NUM)begin
        $display("-------- the %2d core result --------",chip_sel);
        for(integer i=`CONST_NUM;i < `CONST_NUM + `TEST_OUTPUTS_NUM;i = i + 1)begin
            read_from_uut(i, read_tmp);expect_output(test_outputs[i-`CONST_NUM]);
        end
        #1 chip_sel = chip_sel + 1;
    end
    #100 $finish();
end

endmodule
