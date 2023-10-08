`timescale 1ns/1ns

module de1soc_tb();
    logic clk_reset;

    logic clock; 
    logic reset; //+ve synchronous reset

    logic [ 31 : 0 ] in_data;
    logic in_valid;

    reg [ 31 : 0 ] out_data;
    reg out_valid;

    logic downstream_stall;
    logic upstream_stall;

    assign #5 clock = ~clock & !clk_reset;

    cnn_top tb(clock, reset, in_data, in_valid, out_data, out_valid, downstream_stall, upstream_stall);
    
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

        for (int i = 0; i < 1000; i++) begin
            @(posedge clock);
        end
        $stop();
    end
endmodule 