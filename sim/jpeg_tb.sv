module tb();
    // sim local param
    localparam CLK_PERIOD = 20;                    // Clock period is 20ns
    localparam QSTEP = CLK_PERIOD/4;                // Time step of a quarter of a clock period
    localparam TIMESTEP = CLK_PERIOD/10;        // Time step of one tenth of a clock period
    localparam PROJECT_DIR = "";
    localparam TEST_IMAGE = {PROJECT_DIR, "../software/client/test_files/file_5_2.jpg"};

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
        in_valid = 0;
        in_data = 0;
        in_last = 0;
        //inport_strb_i = 4'b1111;
        reset = 1;
        @(posedge clk);
        @(posedge clk);
        reset = 0;

        for (int img_num = 0; img_num < 3; img_num++) begin
            test_image = $fopen(TEST_IMAGE, "rb");
            byte_write_count = 0;
            in_last = 0;
            // Read the image PGM header
            while(!$feof(test_image)) begin
                in_valid = 0;
                in_data = 0;
                //inport_strb_i = 0;
                for (int i = 0; i < 4 && !$feof(test_image); i++) begin
                    $fread(in_data[8*i +: 8], test_image);
                    //inport_strb_i[i] = 1;
                end
                // Insert arbitrary delays just to show we can
                for (int i = 0; i < byte_write_count%4 && byte_write_count < 100; i++) begin
                    @(posedge clk);
                end

                in_last = $feof(test_image);
                in_valid = 1;
                #1;
                while (!in_ready) begin
                    @(posedge clk);
                    #1;
                end
                @(posedge clk);
                //inport_strb_i = 0;
                byte_write_count += 1;
            end
            // for (int i = 0; i < 1500; i++) begin
            //     @(posedge clk);
            // end
        end
        @(posedge clk);

    end

    // Consumer Thread
    initial begin
        @(negedge reset);   
            for (int img_num = 0; img_num >= 0; img_num++) begin  

            for (int y = 0; y < 28 && !out_last; y++) begin
                $write("y=%d: \t", y);
                for (int x = 0; x < 28 && !out_last; x++) begin
                    out_ready = 0;
                    // Arbitrary delay where not ready to read
                    for (int i = 0; i < x+y*4 % 8; i++) begin
                        @(posedge clk);
                    end
                    // Read
                    out_ready = 1;
                    #1
                    while (!out_valid || !out_ready ) begin
                        @(posedge clk);
                        #1;
                    end
                    // $display("Recieved pixel %d (%d,%d,%d)", i, out_data[2], out_data[1], out_data[0]);

                    //$write("%4d", out_data[0]);
                    $write("%d", out_data[0]>128);

                    @(posedge clk);
                    out_ready = 0;
                end
                $write("\n");
            end
            $display("Completed entire img=%d, last=%d", img_num, out_last);
            @(posedge clk);
        end
   

        $display("Consumer thread finished");
    end



    // Timer to stop infinite error
    initial begin
        for (int timer_i = 0; timer_i < 50*1000; timer_i++) begin
            @(posedge clk);
        end 
        $display("Ran out of time -- killing process");
        $stop();
    end
endmodule