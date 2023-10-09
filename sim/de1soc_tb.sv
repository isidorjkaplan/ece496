`timescale 1ns/1ns



module de1soc_tb();
    logic clk_reset;

    logic clock; 
    logic reset; //+ve synchronous reset

    parameter VALUE_BITS=8;
    parameter KERNAL_SIZE=3;
    parameter WIDTH=28;
    parameter IN_CHANNELS=1;
    parameter OUT_CHANNELS=2;
    parameter NUM_KERNALS=1;
    parameter STRIDE=1;

    logic [VALUE_BITS-1 : 0] in_row_i[WIDTH][IN_CHANNELS];
    logic in_row_valid_i, in_row_accept_o, in_row_last_i;

    logic [VALUE_BITS -1 : 0] out_row_o[WIDTH/STRIDE][OUT_CHANNELS];
    logic out_row_valid_o;
    logic out_row_accept_i;

    cnn_layer #(
        .KERNAL_SIZE(KERNAL_SIZE), .NUM_KERNALS(NUM_KERNALS), .STRIDE(STRIDE), 
        .WIDTH(WIDTH), .VALUE_BITS(VALUE_BITS), .IN_CHANNELS(IN_CHANNELS), .OUT_CHANNELS(OUT_CHANNELS)
    ) layer0(
        // General
        .clock_i(clock), .reset_i(reset),
        // INPUT INFO
        .in_row_i(in_row_i),
        .in_row_valid_i(in_row_valid_i),
        .in_row_accept_o(in_row_accept_o),
        .in_row_last_i(in_row_last_i),
        // OUT INFO
        .out_row_o(out_row_o),
        .out_row_valid_o(out_row_valid_o),
        .out_row_accept_i(out_row_accept_i)
    );

    assign #5 clock = ~clock & !clk_reset;
    
    task automatic write_row(int row_num);
    begin
        for (int width = 0; width < WIDTH; width++) begin
            for (int in_ch = 0; in_ch < IN_CHANNELS; in_ch++) begin
                in_row_i[width][in_ch] = width + in_ch +  WIDTH*IN_CHANNELS*row_num;
            end
        end
        in_row_valid_i = 1;
        #1
        while (!in_row_accept_o) begin
            @(posedge clock);
        end
        @(posedge clock);
        in_row_valid_i = 0;
    end
    endtask
    //cnn_top tb(clock, reset, in_data, in_valid, out_data, out_valid, downstream_stall, upstream_stall);
    
    initial begin
        in_row_valid_i = 0;
        in_row_last_i = 0;
        clk_reset = 1;
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

        // Write the first 27 rows of the image
        for (int i = 0; i < 27; i++) begin
            write_row(i);
        end
        // Write the last row
        in_row_last_i = 1;
        write_row(27);
        // turn off last signal
        in_row_last_i = 0;
        // Just some stalling so we can watch nothing happening
        for (int i = 0; i < 100; i++) begin
            @(posedge clock);
        end
        $stop();
    end
endmodule 