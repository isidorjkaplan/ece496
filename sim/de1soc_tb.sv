`timescale 1ns/1ns


module de1soc_tb();
    
    parameter VALUES_PER_WORD=1;
    parameter IMG_WIDTH = 28;
    parameter IMG_HEIGHT = IMG_WIDTH;

    // 50 MHz clock
    localparam CLK_PERIOD = 20; 

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

    int last_read_tag = -1;

    de1soc_top dut(.clock(clock), .reset(reset), 
	// Inputs
	.in_data(in_data), .in_valid(in_valid),
	// Outputs
	.out_data(out_data), .out_valid(out_valid), 
	// Control Flow
	.downstream_stall(downstream_stall), .upstream_stall(upstream_stall));

    task automatic send_word(logic [31:0] word);
    begin
        in_data = word;
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

    task automatic write_values(input [7:0] values[VALUES_PER_WORD], logic [7:0] cntrl_byte);
    begin
        logic [31:0] word;
        word = 0;
        for (int i = 0; i < VALUES_PER_WORD; i++) begin
            word[ 8*i +: 8 ] = values[i];
        end
        word[31:24] = cntrl_byte;
        send_word(word);
    end
    endtask

    task automatic write_row(int N, logic [5:0] tag);
    begin
        logic [7:0] values[VALUES_PER_WORD];
        logic [7:0] cntrl_byte;
        cntrl_byte = 0;
        // in_row_last_i is the second last bit of cntrl byte
        cntrl_byte[5:0] = tag;
        for (int i = 0; i < IMG_WIDTH; i+=VALUES_PER_WORD) begin
            for (int j = 0; j < VALUES_PER_WORD; j++) begin
                values[j] = i+j+N*IMG_WIDTH;
            end
            if (i+VALUES_PER_WORD >= IMG_WIDTH) begin
                cntrl_byte[6] = N==IMG_WIDTH-1;
            end
            write_values(values, cntrl_byte);
        end
    end
    endtask

    task automatic read_next_value(int timeout);
    begin
        int tag_value;
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
        tag_value =  out_data[29:24];
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

    assign #(CLK_PERIOD/2) clock = ~clock & !clk_reset;
    
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
            read_values(10000000, 2);
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
        #((CLK_PERIOD/2) + 1)
        clk_reset = 0;
        @(posedge clock);
        reset = 0;
        @(posedge clock);
        // Send reset signal encoded in the input data (this is how proc signals to flush the CNN pipeline) 
        send_word({1'b1, 31'b0});
        for (int img_num = 0; img_num < 3; img_num++) begin
            for (int i = 0; i < 28; i++) begin
                write_row(i, img_num);
                $display("Wrote row %d", i);
                wait_cycles(100);
            end
            wait_cycles(1000);
            
        end
        $display("Writer thread finished");
        wait_cycles(1000); // give reader thread time to get any potential values
        $display("Writer thread terminating sim");
        $stop();
    end
endmodule 
