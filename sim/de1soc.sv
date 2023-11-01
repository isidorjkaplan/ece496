module tb();
    // dut local param
    localparam VALUE_BITS = 18;
    localparam N = 8;
    localparam INPUT_WIDTH=28;
    localparam INPUT_CHANNELS=1;
    localparam OUTPUT_CHANNELS = 10;
    localparam POOL_SIZE = 2;
    // sim local param
    localparam CLK_PERIOD = 20;                    // Clock period is 20ns
    localparam QSTEP = CLK_PERIOD/4;                // Time step of a quarter of a clock period
    localparam TIMESTEP = CLK_PERIOD/10;        // Time step of one tenth of a clock period
    localparam FILTER_SIZE = 3;                    // Convolution filter size (3x3)
    localparam PADDING_SIZE = FILTER_SIZE/2;    // Image padding size 
    // You have to set the project directory for the testbench to operate correctly
    localparam PROJECT_DIR = "";
    localparam TEST_IMAGE_0 = {PROJECT_DIR, "mnist/file_0_5.pgm"};
    // localparam TEST_IMAGE_0 = {PROJECT_DIR, "mnist/test.pgm"};
    // localparam TEST_IMAGE_1 = {PROJECT_DIR, "mnist/test1.pgm"};

    // Declare signals for the DUT interface
    logic clk;
    logic reset;
    logic i_valid;
    logic i_ready;
    logic i_last;
    logic o_valid;
    logic o_ready;
    logic o_last;
    logic signed [31:0]  i_data;
    logic signed [31:0]  o_data;

    // Generate a 50MHz clock
    initial clk = 1'b1;
    always #(CLK_PERIOD/2) clk = ~clk;

    logic upstream_stall;
    assign i_ready = ~upstream_stall;

    // input wire clock, 
    // input wire reset, //+ve synchronous reset

    // input wire [ 31 : 0 ] in_data,
    // input wire in_valid,
    
    // output reg [ 31 : 0 ] out_data,
    // output reg out_valid, 

    // input wire downstream_stall, 
    // output wire upstream_stall
    // Instantiation of the DUT circuit
    de1soc_top dut (
        .clock(clk),
        .reset(reset),
        // in
        .in_data(0 | i_data | (i_last<<30)),
        .in_valid(i_valid),
        .upstream_stall(upstream_stall),

        // out
        .out_data(o_data),
        .out_valid(o_valid),
        .downstream_stall(!o_ready)
        //.out_last(o_last)
    );
    //assign o_last = o_data[30];

    // Declare more signals used for testing
    integer test_image, result_image[OUTPUT_CHANNELS];
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

        // SOFT RESET TESTING
        i_valid = 1'b1;
        i_data = (1<<31);
        for (int i = 0; i < 10; i++) begin
            #(CLK_PERIOD);
        end
        i_valid = 1'b0;
        i_data = 0;

        // Stream in the values of the image pixels
        for(pixel_id = 0; pixel_id < (image_width*image_height); pixel_id = pixel_id + 1) begin		
            // Start at positive edge. Advance quarter cycle
            #(QSTEP);
            
            // Prepare an input value (if it is first or last pixel of the row, insert zero for padding in case of a 3x3 filte. Otherwise, insert pixel)
            temp = $fscanf(test_image, "%d ", pixel_val); 

            i_data = pixel_val << (N-8); // div by 256, model does div by 255
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

        /*
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
        i_data[0] = 0;
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

            i_data[0] = pixel_val << N;
            saved_i_x = i_data[0];
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
                i_data[0] = saved_i_x;
                i_valid = 1'b1;
            end
            
            // Test that DUT stalls properly if we don't give it a valid input
            if (pixel_id == image_width/4 && !valid_stall_tested) begin
                i_valid = 1'b0;
                i_data[0] = 23; // Strange input to make sure it is ignored.
                #(3*CLK_PERIOD);
                
                // DUT may not be ready at this point, so wait until it is
                while(!i_ready) begin
                    #(CLK_PERIOD);
                end

                i_data[0] = saved_i_x;
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
        */
    end

    // Consumer process
    initial begin
        // test only one image for now, o_ready always low
	    o_ready = 1'b1;
        #(CLK_PERIOD)
        // wait until o_valid is high

        for (int i = 0; i < 10; i++) begin
            while (!o_valid) begin
                #(CLK_PERIOD);
            end
            $display("Read %d", o_data[17:0]);
            #(CLK_PERIOD);
        end
        #100;
        $display("Current Timestep: %0t", $time);
	    $stop(0);
    end
endmodule