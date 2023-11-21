module tb();
    // sim local param
    localparam CLK_PERIOD = 20;                    // Clock period is 20ns
    localparam QSTEP = CLK_PERIOD/4;                // Time step of a quarter of a clock period
    localparam TIMESTEP = CLK_PERIOD/10;        // Time step of one tenth of a clock period
    localparam PROJECT_DIR = "";
    localparam TEST_IMAGE = {PROJECT_DIR, "mnist/hw_img_test.jpg"};

    logic clk;
    logic reset;
    logic [31:0] data;
    integer test_image;
    integer byte_count;


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
    assign inport_data_i = {data[7:0], data[15:8], data[23:16], data[31:24]}; 

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
        byte_count = 0;
        outport_accept_i = 1;
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
        while(! $feof(test_image)) begin
            inport_valid_i = 1;
            $fread(data, test_image);
            @(posedge clk);
            while (!inport_accept_o) begin
                @(posedge clk);
            end
            byte_count += 1;
        end
        inport_last_i = 1;
        @(posedge clk);

        $stop();
    end

    // Consumer process
    initial begin
        for (int i = 0; i < 100; i++) begin
            @(posedge clk);
        end 
        // $stop();
    end
endmodule