`timescale 1ns/1ns


module de1soc_tb();

    parameter VALUES_PER_WORD=1;
    parameter IMG_WIDTH = 28;
    parameter IMG_HEIGHT = IMG_WIDTH;

    logic clk_reset;

    logic clock;
    logic reset;

    logic [ 31 : 0 ] in_data;
    logic in_valid;

    logic [ 31 : 0 ] out_data;
    logic out_valid;

    logic downstream_stall;
    logic upstream_stall;

    int timed_out;
    int read_count;

    cnn_top #(.VALUES_PER_WORD(VALUES_PER_WORD)) dut(.clock(clock), .reset(reset), 
	// Inputs
	.in_data(in_data), .in_valid(in_valid),
	// Outputs
	.out_data(out_data), .out_valid(out_valid), 
	// Control Flow
	.downstream_stall(downstream_stall), .upstream_stall(upstream_stall));

    task automatic write_values(input [7:0] values[VALUES_PER_WORD]);
    begin
        in_data = 0;
        for (int i = 0; i < VALUES_PER_WORD; i++) begin
            in_data[ 8*i +: 8 ] = values[i];
        end
        in_valid = 1;
        #1
        while (upstream_stall) begin
            @(posedge clock);
            #1;
            //$display("Stalling while writing: %x", value);
        end
        //$assert(!upstream_stall && in_valid);
        if (upstream_stall) begin
            $display("FAILED");
            $stop();
        end
        @(posedge clock);
        in_valid = 0;
        @(posedge clock);
        @(posedge clock);
    end
    endtask

    task automatic write_row(int N);
    begin
        logic [7:0] values[VALUES_PER_WORD];
        for (int i = 0; i < IMG_WIDTH; i+=VALUES_PER_WORD) begin
            for (int j = 0; j < VALUES_PER_WORD; j++) begin
                values[j] = i+j+N*IMG_WIDTH;
            end
            write_values(values);
        end
    end
    endtask

    task automatic read_next_value(int timeout);
    begin
        int count = timeout;
        timed_out = 0;
        // Ready to read
        downstream_stall = 0;
        #1;
        while (!out_valid) begin
            if (timeout != 0) begin
                if (count == 0) begin
                    timed_out = 1;
                    return;
                end
                count = count - 1;
            end
            @(posedge clock);
            #1;
        end
        //$display("Reading 32'h%x", out_data);
        @(posedge clock);
        downstream_stall = 1;
        @(posedge clock);
        @(posedge clock);
    end
    endtask

    task automatic read_values(int N, int timeout);
    begin
        read_count = 0;
        for (int i = 0; i < N; i+=VALUES_PER_WORD) begin
            read_next_value(timeout);
            if (timed_out) return;
            read_count++;
        end
    end
    endtask

    task automatic wait_cycles(int N);
    begin
        for (int i = 0; i < N; i++) begin
            @(posedge clock);
        end
    end
    endtask

    assign #5 clock = ~clock & !clk_reset;
    
    initial begin
        wait_cycles(50000);
        $display("Ran out of time -- murdering simulator\n");
        $stop();
    end

    // Reader thread
    initial begin
        // Wait until writer thread reliably running
        wait_cycles(20);

        while (1) begin
            // blocking read until we get first value value
            read_values(10000000, 5);
            if (read_count > 0) begin
                $display("Read burst result of %d words", read_count);
            end
        end

        //$display("Reader thread finished -- Killing simulator\n");
        //$stop();
    end

    initial begin
        clk_reset = 1;
        downstream_stall = 1;
        reset = 1;
        in_valid = 0;
        #6
        clk_reset = 0;
        @(posedge clock);
        reset = 0;
        @(posedge clock);
        for (int img_num = 0; img_num < 3; img_num++) begin
            for (int i = 0; i < 28; i++) begin
                write_row(i);
                $display("Wrote row %d", i);
            end
            wait_cycles(1000);
        end
        $display("Writer thread finished");
        wait_cycles(1000);
        $display("Writer thread terminating sim");
        
    end
endmodule 

module layer_tb();
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


    logic  [ WEIGHT_BITS-1 : 0 ] kernal_weights_i[OUT_CHANNELS][IN_CHANNELS][KERNAL_SIZE][KERNAL_SIZE];

    logic [VALUE_BITS-1 : 0] in_row_i[WIDTH][IN_CHANNELS];
    logic in_row_valid_i, in_row_accept_o, in_row_last_i;

    logic [VALUE_BITS -1 : 0] out_row_o[WIDTH][OUT_CHANNELS];
    logic out_row_valid_o;
    logic out_row_accept_i;
    logic out_row_last_o;

    cnn_layer #(
        .KERNAL_SIZE(KERNAL_SIZE), .NUM_KERNALS(NUM_KERNALS), 
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