module tb();
    // sim local param
    localparam CLK_PERIOD = 20;                    // Clock period is 20ns
    localparam QSTEP = CLK_PERIOD/4;                // Time step of a quarter of a clock period
    localparam TIMESTEP = CLK_PERIOD/10;        // Time step of one tenth of a clock period
    localparam PROJECT_DIR = "";
    localparam TEST_IMAGE = {PROJECT_DIR, "mnist/hw_img_test.jpg"};

    logic clk;
    logic reset;
    //logic [7:0] data_byte;
    integer test_image;
    integer byte_write_count;

    // DUT signals
    logic        [31 : 0]  in_data;
    logic                  in_last;
    logic                  in_valid;
    logic                  in_ready;
    logic         [7 : 0] out_data[3];
    logic                 out_valid;
    logic                 out_last;
    logic                 out_ready;

    jpeg_decoder dut(.clk(clk), .reset(reset), 
        .in_data(in_data), .in_last(in_last), .in_valid(in_valid), .in_ready(in_ready),
        .out_data(out_data), .out_valid(out_valid), .out_last(out_last), .out_ready(out_ready)
    );

    // Generate a 50MHz clock
    initial clk = 1'b1;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // Producer Process
    initial begin
        byte_write_count = 0;
        in_valid = 0;
        in_data = 0;
        in_last = 0;
        //inport_strb_i = 4'b1111;
        reset = 1;
        @(posedge clk);
        @(posedge clk);
        reset = 0;
        //@(posedge clk);
    
        // test image 1
        test_image = $fopen(TEST_IMAGE, "rb");

        // Read the image PGM header
        while(!$feof(test_image)) begin
            in_valid = 1;
            in_data = 0;
            //inport_strb_i = 0;
            for (int i = 0; i < 4 && !$feof(test_image); i++) begin
                $fread(in_data[8*i +: 8], test_image);
                //inport_strb_i[i] = 1;
            end
            in_last = $feof(test_image);
            if (in_last) begin
                $display("Last Byte is %x", in_data);
            end
            #1;
            while (!in_ready) begin
                @(posedge clk);
                #1;
            end
            @(posedge clk);
            //inport_strb_i = 0;
            byte_write_count += 1;
        end
        in_last = 1;
        in_valid = 0;
        @(posedge clk);
        in_last = 0;
        in_valid = 0;
        $display("Done writer thread");
    end

    //logic[7:0] value[32][32];

    initial begin
        @(negedge reset);
        // for (int y = 0; y < 28; y++) begin
        //     for (int x = 0; x < 28; x++) begin
        //         seen[x][y] = 0;
        //     end
        // end
     
        out_ready = 1;
        for (int i = 0; i < 28*28; i++) begin
            while (!out_valid || !out_ready ) begin
                @(posedge clk);
            end
            $display("Recieved pixel %d (%d,%d,%d)", i, out_data[2], out_data[1], out_data[0]);
            //value[outport_pixel_x_o][outport_pixel_y_o] = outport_pixel_r_o;
         
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
        // for (int y = 0; y < 28; y++) begin
        //     for (int x = 0; x < 28; x++) begin
        //         $write("%d", value[x][y]>=128);
        //     end
        //     $display("");
        // end
        $stop();
    end
endmodule