`timescale 1ns/1ns

module de1soc_tb();
    logic clk_reset;

    logic clock;
    logic reset;

    logic [ 31 : 0 ] out_data;
    logic out_valid;
    logic downstream_stall;

    task automatic read_next_value(int i);
    begin
        // Ready to read
        downstream_stall = 0;
        #1;
        while (!out_valid) begin
            @(posedge clock);
            #1;
        end
        $display("%d: Reading 32'h%x", i, out_data);
        @(posedge clock);
        downstream_stall = 1;
        @(posedge clock);
        @(posedge clock);
    end
    endtask

    task automatic read_values(int N);
    begin
        for (int i = 0; i < N; i++) begin
            read_next_value(i);
        end
    end
    endtask

    assign #5 clock = ~clock & !clk_reset;

    de1soc_tb_syn tb(clock, reset, out_data, out_valid, downstream_stall);
    
    initial begin
        for (int i = 0; i < 10000; i++) begin
            @(posedge clock);
        end
        $stop();
    end

    initial begin
        clk_reset = 1;
        downstream_stall = 1;
        reset = 1;
        #6
        clk_reset = 0;
        @(posedge clock);
        @(posedge clock);
        @(posedge clock);
        @(posedge clock);
        @(posedge clock);
        reset = 0;
        @(posedge clock);
        
        read_values(28*28);
        read_values(1000);
        $stop();
    end
endmodule 