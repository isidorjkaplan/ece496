`timescale 1ns/1ns



module de1soc_tb();
    logic clk_reset;

    logic clock; 
    logic reset; //+ve synchronous reset

    parameter VALUE_BITS=8;
    parameter KERNAL_SIZE=3;
    parameter LAYER0_WIDTH=28;
    parameter LAYER0_IN_CHANNELS=1;
    parameter LAYER0_OUT_CHANNELS=2;
    parameter LAYER0_NUM_KERNALS=1;
    parameter LAYER0_STRIDE=1;

    logic [VALUE_BITS-1 : 0] in_row_layer0[LAYER0_WIDTH][LAYER0_IN_CHANNELS];
    logic layer0_in_ready, in_row_layer0_valid, layer0_last_row;

    cnn_layer #(
        .KERNAL_SIZE(KERNAL_SIZE), .NUM_KERNALS(LAYER0_NUM_KERNALS), .STRIDE(LAYER0_STRIDE), 
        .WIDTH(LAYER0_WIDTH), .VALUE_BITS(VALUE_BITS), .IN_CHANNELS(LAYER0_IN_CHANNELS), .OUT_CHANNELS(LAYER0_OUT_CHANNELS)
    ) layer0(
        // General
        .clock_i(clock), .reset_i(reset),
        // INPUT INFO
        .in_row_i(in_row_layer0),
        .in_row_valid_i(in_row_layer0_valid),
        .in_row_accept_o(layer0_in_ready),
        .in_row_last_i(layer0_last_row)
        // Don't even bother hooking up output info right now
        // TODO
    );

    assign #5 clock = ~clock & !clk_reset;
    
    task automatic write_row(int row_num);
    begin
        for (int width = 0; width < LAYER0_WIDTH; width++) begin
            for (int in_ch = 0; in_ch < LAYER0_IN_CHANNELS; in_ch++) begin
                in_row_layer0[width][in_ch] = width + in_ch +  LAYER0_WIDTH*LAYER0_IN_CHANNELS*row_num;
            end
        end
        in_row_layer0_valid = 1;
        #1
        while (!layer0_in_ready) begin
            @(posedge clock);
        end
        @(posedge clock);
        in_row_layer0_valid = 0;
    end
    endtask
    //cnn_top tb(clock, reset, in_data, in_valid, out_data, out_valid, downstream_stall, upstream_stall);
    
    initial begin
        in_row_layer0_valid = 0;
        layer0_last_row = 0;
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
        layer0_last_row = 1;
        write_row(27);
        // turn off last signal
        layer0_last_row = 0;


        for (int i = 0; i < 1000; i++) begin
            @(posedge clock);
        end
        $stop();
    end
endmodule 