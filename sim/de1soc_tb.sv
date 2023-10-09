`timescale 1ns/1ns

module de1soc_tb();
    logic clk_reset;

    logic clock; 
    logic reset; //+ve synchronous reset

    parameter VALUE_BITS=8;
    parameter WEIGHT_BITS=16;
    parameter WEIGHT_Q_SHIFT=8;
    parameter KERNAL_SIZE=3;
    parameter WIDTH=28;
    parameter IN_CHANNELS=1;
    parameter OUT_CHANNELS=2;
    parameter NUM_KERNALS=1;
    parameter STRIDE=1;

    logic  [ WEIGHT_BITS-1 : 0 ] kernal_weights_i[OUT_CHANNELS][IN_CHANNELS][KERNAL_SIZE][KERNAL_SIZE];

    logic [VALUE_BITS-1 : 0] in_row_i[WIDTH][IN_CHANNELS];
    logic in_row_valid_i, in_row_accept_o, in_row_last_i;

    logic [VALUE_BITS -1 : 0] out_row_o[WIDTH/STRIDE][OUT_CHANNELS];
    logic out_row_valid_o;
    logic out_row_accept_i;
    logic out_row_last_o;

    cnn_layer #(
        .KERNAL_SIZE(KERNAL_SIZE), .NUM_KERNALS(NUM_KERNALS), .STRIDE(STRIDE), 
        .WIDTH(WIDTH), .VALUE_BITS(VALUE_BITS), .WEIGHT_BITS(WEIGHT_BITS), .WEIGHT_Q_SHIFT(WEIGHT_Q_SHIFT), .IN_CHANNELS(IN_CHANNELS), .OUT_CHANNELS(OUT_CHANNELS)
    ) layer0(
        // General
        .clock_i(clock), .reset_i(reset),
        .kernal_weights_i(kernal_weights_i),
        // INPUT INFO
        .in_row_i(in_row_i),
        .in_row_valid_i(in_row_valid_i),
        .in_row_accept_o(in_row_accept_o),
        .in_row_last_i(in_row_last_i),
        // OUT INFO
        .out_row_o(out_row_o),
        .out_row_valid_o(out_row_valid_o),
        .out_row_accept_i(out_row_accept_i),
        .out_row_last_o(out_row_last_o)
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
        #1;
        while (!in_row_accept_o) begin
            @(posedge clock);
        end
        @(posedge clock);
        in_row_valid_i = 0;
        // If we have written at least three rows we must wait for valid output and read it
        if (row_num >= 2) begin
            // Wait for it to compute output row and put it on the output port
            out_row_accept_i = 1;
            #1
            while (!out_row_valid_o) begin
                @(posedge clock);
            end
            // Output row is now on the port; read it 
            $display("Read result for row=%d", row_num);
            if (out_row_last_o) begin
                $display("Have read the last row");
            end
            @(posedge clock);
            out_row_accept_i = 0;
        end
    end
    endtask
    //cnn_top tb(clock, reset, in_data, in_valid, out_data, out_valid, downstream_stall, upstream_stall);
    
    initial begin
        for (int i = 0; i < 10000; i++) begin
            @(posedge clock);
        end
        $display("Ran out of time -- terminating!");
        $stop();
    end

    initial begin
        // Initilize kernal weights
        //[OUT_CHANNELS][IN_CHANNELS][KERNAL_SIZE][KERNAL_SIZE]
        for (int out_ch = 0; out_ch < OUT_CHANNELS; out_ch++) begin
            for (int in_ch = 0; in_ch < IN_CHANNELS; in_ch++) begin
                for (int x = 0; x < KERNAL_SIZE; x++) begin
                    for (int y = 0; y < KERNAL_SIZE; y++) begin
                        kernal_weights_i[out_ch][in_ch][x][y] 
                        = x + y*KERNAL_SIZE + in_ch*KERNAL_SIZE*KERNAL_SIZE 
                        + out_ch*KERNAL_SIZE*KERNAL_SIZE*IN_CHANNELS;
                    end
                end
            end
        end
        // Initilize clocks
        in_row_valid_i = 0;
        out_row_accept_i = 0;
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