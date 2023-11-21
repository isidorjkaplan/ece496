module tb();
    // sim local param
    localparam CLK_PERIOD = 20;                    // Clock period is 20ns
    localparam QSTEP = CLK_PERIOD/4;                // Time step of a quarter of a clock period
    localparam TIMESTEP = CLK_PERIOD/10;        // Time step of one tenth of a clock period
    localparam PROJECT_DIR = "";
    localparam TEST_IMAGE = {PROJECT_DIR, "/homes/k/kaplani2/ece496/software/client/test_files/file_5_2.jpg"};

    logic clk;
    logic reset;
    logic [7:0] data_byte;
    integer test_image;
    integer byte_write_count;


    // DUT signals

    logic          inport_valid_i;
    logic [ 31:0]  inport_data_i;
    logic [  3:0]  inport_strb_i;
    logic          inport_last_i;
    logic          outport_accept_i;
    logic          inport_accept_o;
    logic          outport_valid_o;
    logic [ 15:0]  outport_width_o;
    logic [ 15:0]  outport_height_o;
    logic [ 15:0]  outport_pixel_x_o;
    logic [ 15:0]  outport_pixel_y_o;
    logic [  7:0]  outport_pixel_r_o;
    logic [  7:0]  outport_pixel_g_o;
    logic [  7:0]  outport_pixel_b_o;
    logic          idle_o;

    // reverse endianess
    //assign inport_data_i = {data[7:0], data[15:8], data[23:16], data[31:24]}; 


    // DUT
    jpeg_core dut(
        //Inputs
        .clk_i(clk),
        .rst_i(reset),
        .inport_valid_i(inport_valid_i),
        .inport_data_i(inport_data_i),
        .inport_strb_i(inport_strb_i),
        .inport_last_i(inport_last_i),
        .outport_accept_i(outport_accept_i),
        // Outputs
        .inport_accept_o(inport_accept_o),
        .outport_valid_o(outport_valid_o),
        .outport_width_o(outport_width_o),
        .outport_height_o(outport_height_o),
        .outport_pixel_x_o(outport_pixel_x_o),
        .outport_pixel_y_o(outport_pixel_y_o),
        .outport_pixel_r_o(outport_pixel_r_o),
        .outport_pixel_g_o(outport_pixel_g_o),
        .outport_pixel_b_o(outport_pixel_b_o),
        .idle_o(idle_o)
    );
    


    // Generate a 50MHz clock
    initial clk = 1'b1;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // Producer Process
    initial begin
        byte_write_count = 0;
        inport_valid_i = 0;
        inport_last_i = 0;
        inport_strb_i = 4'b1111;
        reset = 1;
        @(posedge clk);
        @(posedge clk);
        reset = 0;
        //@(posedge clk);
    
        // test image 1
        test_image = $fopen(TEST_IMAGE, "rb");

        // Read the image PGM header
        while(!$feof(test_image)) begin
            inport_valid_i = 1;
            inport_data_i = 0;
            //inport_strb_i = 0;
            for (int i = 0; i < 4 && !$feof(test_image); i++) begin
                $fread(inport_data_i[8*i +: 8], test_image);
                //inport_strb_i[i] = 1;
            end
            inport_last_i = $feof(test_image);
            #1;
            while (!inport_accept_o) begin
                @(posedge clk);
                #1;
            end
            @(posedge clk);
            //inport_strb_i = 0;
            byte_write_count += 1;
        end
        inport_last_i = 1;
        inport_valid_i = 0;
        @(posedge clk);
        inport_last_i = 0;
        inport_valid_i = 0;
        $display("Done writer thread");
    end

    logic[7:0] value[32][32];

    initial begin
        @(negedge reset);
        // for (int y = 0; y < 28; y++) begin
        //     for (int x = 0; x < 28; x++) begin
        //         seen[x][y] = 0;
        //     end
        // end
        
        outport_accept_i = 1;
        for (int i = 0; i < 28*28; i++) begin
            while (!outport_valid_o || !outport_accept_i || outport_pixel_x_o >= 28 || outport_pixel_y_o >= 28) begin
                @(posedge clk);
            end
            $display("Recieved pixel %d at (%d,%d) = (%d,%d,%d)", i, outport_pixel_x_o, outport_pixel_y_o, outport_pixel_r_o, outport_pixel_g_o, outport_pixel_b_o);
            value[outport_pixel_x_o][outport_pixel_y_o] = outport_pixel_r_o;
            
            @(posedge clk);
        end
        for (int i = 0; i < 10; i++) begin
            @(posedge clk);
        end
        $display("Consumer thread finished");
        //$stop();
    end

    // Timer to stop infinite error
    initial begin
        for (int i = 0; i < 5000; i++) begin
            @(posedge clk);
        end 
        $display("Ran out of time -- killing process");
        for (int y = 0; y < 28; y++) begin
            for (int x = 0; x < 28; x++) begin
                $write("%d", value[x][y]>=128);
            end
            $display("");
        end
        $stop();
    end
endmodule