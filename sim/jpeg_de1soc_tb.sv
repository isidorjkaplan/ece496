module tb();
    // sim local param
    localparam CLK_PERIOD = 20;                    // Clock period is 20ns
    localparam QSTEP = CLK_PERIOD/4;                // Time step of a quarter of a clock period
    localparam TIMESTEP = CLK_PERIOD/10;        // Time step of one tenth of a clock period
    localparam PROJECT_DIR = "";
    // localparam TEST_IMAGE0 = {PROJECT_DIR, "/homes/k/kaplani2/ece496/software/client/test_files/file_4_9.jpg"}
    localparam TEST_IMAGE0 = {PROJECT_DIR, "/homes/k/kaplani2/ece496/sim/work/16352_0.jpg"};
    localparam TEST_IMAGE1 = {PROJECT_DIR, "/homes/k/kaplani2/ece496/sim/work/09074_3.jpg"};

    logic clk;
    logic reset;
    //logic [7:0] data_byte;
    integer test_image;
    integer byte_write_count;
    integer num_bytes;

    // DUT signals
    logic        [31 : 0]  in_data;
    logic                  in_valid;
    logic                  in_ready;
    logic        [31 : 0] out_data;
    logic                 out_valid;
    logic                 out_ready;

    system_top dut(.clock(clk), .reset(reset), 
        .in_data(in_data), .in_valid(in_valid), .in_ready(in_ready),
        .out_data(out_data), .out_valid(out_valid), .out_ready(out_ready)
    );

    // Generate a 50MHz clock
    initial clk = 1'b1;
    always #(CLK_PERIOD/2) clk = ~clk;

    integer cycle_num;
    initial begin
        cycle_num = 1;
        while(1) begin
            @(posedge clk);
            cycle_num += 1;
        end
    end

    
    // Producer Process
    initial begin
        out_ready = 1;
        in_valid = 0;
        in_data = 0;
        //in_last = 0;
        //inport_strb_i = 4'b1111;
        reset = 1;
        @(posedge clk);
        @(posedge clk);
        reset = 0;

        for (int img_num = 0; img_num < 10; img_num++) begin
            test_image = $fopen(img_num%2==0?TEST_IMAGE0:TEST_IMAGE1, "rb");
            num_bytes= 0;
            while(!$feof(test_image)) begin
                $fread(in_data, test_image);
                num_bytes+=1;
            end
            if (in_data == 0) begin
                num_bytes -= 1;
            end
            //$display("Writing image of size %d words", byte_write_count);
            in_data = num_bytes;
            in_valid = 1;
            #1;
            while (!in_ready) begin
                @(posedge clk);
                #1;
            end
            @(posedge clk);
            in_valid = 0;
            test_image = $fopen(img_num%2==0?TEST_IMAGE0:TEST_IMAGE1, "rb");
            byte_write_count = 0;
            // Read the image PGM header
            while(!$feof(test_image) && byte_write_count < num_bytes) begin
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

                //in_last = 0;//$feof(test_image);

                //$display("Writing word = %x", in_data);
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
            in_valid = 0;
            @(posedge clk);
            #1;
        end
        @(posedge clk);

    end

    // Timer to stop infinite error
    initial begin
        for (int timer_i = 0; timer_i < 2*50*1000; timer_i++) begin
            @(posedge clk);
        end 
        $display("Ran out of time -- killing process");
        $stop();
    end
endmodule