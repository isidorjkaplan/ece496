module tb();
    // Define some local parameters useful for simulation
    localparam VALUE_BITS = 22;
    localparam N = 12;
    localparam CLK_PERIOD = 20;                    // Clock period is 20ns
    localparam QSTEP = CLK_PERIOD/4;                // Time step of a quarter of a clock period
    localparam TIMESTEP = CLK_PERIOD/10;        // Time step of one tenth of a clock period
    localparam POOL_SIZE = 1;                    // Convolution filter size (3x3)
    localparam CHANNELS = 4;
    // You have to set the project directory for the testbench to operate correctly
    localparam PROJECT_DIR = "";
    // localparam TEST_IMAGE = {PROJECT_DIR, "mnist/file_0_5.pgm"};
    localparam TEST_IMAGE_0 = {PROJECT_DIR, "mnist/test.pgm"};
    localparam TEST_IMAGE_1 = {PROJECT_DIR, "mnist/test1.pgm"};

    // Declare signals for the DUT interface
    logic clk;
    logic reset;
    logic i_valid;
    logic i_ready;
    logic i_last;
    logic o_valid;
    logic o_ready;
    logic o_last;
    logic signed [VALUE_BITS-1:0]  i_data;
    logic signed [VALUE_BITS-1:0]  o_data;

    logic signed [VALUE_BITS-1:0]  i_data_int;
    logic signed [VALUE_BITS-1:0]  o_data_int;

    assign i_data_int = i_data >> N;
    assign o_data_int = o_data >> N;

    // Generate a 50MHz clock
    initial clk = 1'b1;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Instantiation of the DUT circuit
    max_pooling_layer_single_channel #(
        .WIDTH(28), 
        .POOL_SIZE(POOL_SIZE), 
        .VALUE_BITS(VALUE_BITS),
        .RELU(1)
    ) dut (
        .clk(clk),
        .reset(reset),
        .i_data(i_data),
        .i_valid(i_valid),
        .i_ready(i_ready),
        .i_last(i_last),
        .o_data(o_data),
        .o_valid(o_valid),
        .o_ready(o_ready),
        .o_last(o_last)
    );

    // Declare more signals used for testing
    integer test_image, result_image;
    integer image_width, image_height;
    integer temp, pixel_id, pixel_val;
    logic [8000:0] line;
    logic valid_stall_tested = 0;
    logic [31:0] saved_i_x;
    integer out_id;
    integer out_channel;
    integer current_time = 0;
    logic ready_stall_tested = 0;
    integer repeatCount;
    logic got_last;

    // Producer Process
    initial begin
        // test image 1
        test_image = $fopen(TEST_IMAGE_0, "r");

        // Read the image PGM header
        temp = $fgets(line, test_image);
        temp = $fgets(line, test_image);
        temp = $fscanf(test_image, "%d %d\n", image_width, image_height);
        $display("Image width = %d, Image height = %d\n", image_width, image_height);
        temp = $fgets(line, test_image);

        // i_valid starts low
        i_valid = 1'b0;
        i_data = 0;
        i_last = 0;

        // Hold the reset high for 3.5 cycles
        // Doing this to ensure the design is fully reset if someone uses a multi-cycle 
        // reset strategy, and that the reset goes low away from any clock edges to 
        // avoid any subtle timing issues when doing gate-level (timing) simulation.
        reset = 1'b1;
        #(3*CLK_PERIOD);
        #(2*QSTEP);
        reset = 1'b0;
        #(2*QSTEP);

        // Stream in the values of the image pixels
        for(pixel_id = 0; pixel_id < (image_width*image_height); pixel_id = pixel_id + 1) begin		
            // Start at positive edge. Advance quarter cycle
            #(QSTEP);
            
            // Prepare an input value (if it is first or last pixel of the row, insert zero for padding in case of a 3x3 filte. Otherwise, insert pixel)
            temp = $fscanf(test_image, "%d ", pixel_val); 

            i_data = (pixel_val << N);
            saved_i_x = i_data;
            if(pixel_id == (image_width*image_height)-1) begin
                i_last = 1;
            end
            
            // Advance half a cycle
            #(2*QSTEP);
            
            // Check i_ready and set i_valid
            i_valid = 1'b1;
            while(!i_ready) begin
                // If DUT claims to not be ready, then it shouldn't be an issue if we 
                // give it an erroneous value.
                i_data = 128;
                i_valid = 1'b0;
                
                // Wait for a clock period before checking i_ready again
                #(CLK_PERIOD);
                
                // Restore the correct value of i_x if we're going to go out of this while loop
                i_data = saved_i_x;
                i_valid = 1'b1;
            end
            
            // Test that DUT stalls properly if we don't give it a valid input
            if (pixel_id == image_width/4 && !valid_stall_tested) begin
                i_valid = 1'b0;
                i_data = 23; // Strange input to make sure it is ignored.
                #(3*CLK_PERIOD);
                
                // DUT may not be ready at this point, so wait until it is
                while(!i_ready) begin
                    #(CLK_PERIOD);
                end

                i_data = saved_i_x;
                i_valid = 1'b1;
                valid_stall_tested = 1;
            end
            
            // Advance another quarter cycle to next positive edge
            #(QSTEP);
        end
        // Advance another quarter cycle to next positive edge
        #(QSTEP);
        i_last = 0;
        i_valid = 0;
        $fclose(test_image);
        // Advance another 3 quarter cycles to next positive edge
        #(3*QSTEP);

        // test image 2
        test_image = $fopen(TEST_IMAGE_1, "r");

        // Read the image PGM header
        temp = $fgets(line, test_image);
        temp = $fgets(line, test_image);
        temp = $fscanf(test_image, "%d %d\n", image_width, image_height);
        $display("Image width = %d, Image height = %d\n", image_width, image_height);
        temp = $fgets(line, test_image);

        // i_valid starts low
        i_valid = 1'b0;
        i_data = 0;
        i_last = 0;

        // // Hold the reset high for 3.5 cycles
        // // Doing this to ensure the design is fully reset if someone uses a multi-cycle 
        // // reset strategy, and that the reset goes low away from any clock edges to 
        // // avoid any subtle timing issues when doing gate-level (timing) simulation.
        // reset = 1'b1;
        // #(3*CLK_PERIOD);
        // #(2*QSTEP);
        // reset = 1'b0;
        // #(2*QSTEP);

        // Stream in the values of the image pixels
        for(pixel_id = 0; pixel_id < (image_width*image_height); pixel_id = pixel_id + 1) begin		
            // Start at positive edge. Advance quarter cycle
            #(QSTEP);
            
            // Prepare an input value (if it is first or last pixel of the row, insert zero for padding in case of a 3x3 filte. Otherwise, insert pixel)
            temp = $fscanf(test_image, "%d ", pixel_val); 

            i_data = pixel_val << N;
            saved_i_x = i_data;
            if(pixel_id == (image_width*image_height)-1) begin
                i_last = 1;
            end
            
            // Advance half a cycle
            #(2*QSTEP);
            
            // Check i_ready and set i_valid
            i_valid = 1'b1;
            while(!i_ready) begin
                // If DUT claims to not be ready, then it shouldn't be an issue if we 
                // give it an erroneous value.
                // i_data[0] = 128;
                // i_valid = 1'b0;
                
                // Wait for a clock period before checking i_ready again
                #(CLK_PERIOD);
                
                // Restore the correct value of i_x if we're going to go out of this while loop
                i_data = saved_i_x;
                i_valid = 1'b1;
            end
            
            // Test that DUT stalls properly if we don't give it a valid input
            if (pixel_id == image_width/4 && !valid_stall_tested) begin
                i_valid = 1'b0;
                i_data = 23; // Strange input to make sure it is ignored.
                #(3*CLK_PERIOD);
                
                // DUT may not be ready at this point, so wait until it is
                while(!i_ready) begin
                    #(CLK_PERIOD);
                end

                i_data = saved_i_x;
                i_valid = 1'b1;
                valid_stall_tested = 1;
            end
            
            // Advance another quarter cycle to next positive edge
            #(QSTEP);
        end
        // Advance another quarter cycle to next positive edge
        #(QSTEP);
        i_last = 0;
        i_valid = 0;
        $fclose(test_image);
    end

    // Consumer process
    initial begin
        // Downstream consumer device is initially ready to receive data
	    o_ready = 1'b1;

        // Delay until just before the first posedge
        #(CLK_PERIOD - TIMESTEP);
        current_time = current_time + (CLK_PERIOD - TIMESTEP);

        for(repeatCount = 0; repeatCount < 2; repeatCount = repeatCount+1)begin
            got_last = 0;
            // Open files to write the result image, difference image and simulation log
            result_image = $fopen({PROJECT_DIR, $sformatf("mnist/pool_out_%0d.pgm", repeatCount)}, "w");
            // Write result image PGM header
            $fwrite(result_image, "P2\n");
            $fwrite(result_image, "# Generated by ECE496 Verilog testbench\n");
            $fwrite(result_image, "%d %d\n", image_width/POOL_SIZE, image_height/POOL_SIZE);
            $fwrite(result_image, "255\n");

            for (out_id = 0; out_id < (image_width/POOL_SIZE) * (image_height/POOL_SIZE); out_id = out_id) begin
                // We are now at the point just before the posedge. Check o_valid and compare results.
                if (o_valid) begin                    
                    if(out_id % (image_width/POOL_SIZE) == 0 && out_id!=0) begin
                        $fwrite(result_image, "\n");
                    end            
                    // Write the output pixel and difference between output and golden result
                    $fwrite(result_image, "%d ", o_data[N+:(VALUE_BITS-N)]);
                    // Increment our loop counter
                    out_id = out_id + 1;
                    // if o_last is asserted
                    if(o_last) begin
                        if(out_id < ((image_width/POOL_SIZE) * (image_height/POOL_SIZE))) begin
                            $display("got o_last earlier than expected\n");
                        end
                        else if(out_id == ((image_width/POOL_SIZE) * (image_height/POOL_SIZE))) begin
                            $display("got o_last with last pixel\n");
                        end
                        got_last = 1;
                    end
                end
                
                // Advance to positive edge
                #(TIMESTEP);
                current_time = current_time + (TIMESTEP);

                // Then advance another quarter cycle
                #(QSTEP);
                current_time = current_time + (QSTEP);

                // Set o_ready
                o_ready = 1'b1;
                
                // Test that DUT stalls properly if receiver isn't ready
                if (out_id == image_height/4 && !ready_stall_tested) begin
                    o_ready = 1'b0;
                    // Wait for 6 clock periods
                    #(6*CLK_PERIOD);
                    current_time = current_time + (6*CLK_PERIOD);
                    // Then restore o_ready
                    o_ready = 1'b1;
                    ready_stall_tested = 1;
                end
                
                // Then advance to just before the next posedge
                #(3*QSTEP - TIMESTEP);
                current_time = current_time + (3*QSTEP - TIMESTEP);
            end

            $fclose(result_image);
            if(got_last == 0) begin
                while(!o_last) begin
                    #(CLK_PERIOD);
                end
                got_last = 1;
                #(CLK_PERIOD);
            end
            
        end
        #100;
        $display("Current Timestep: %0t", $time);
	    $stop(0);
    end

endmodule