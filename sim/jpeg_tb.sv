module tb();
    // sim local param
    localparam CLK_PERIOD = 20;                    // Clock period is 20ns
    localparam QSTEP = CLK_PERIOD/4;                // Time step of a quarter of a clock period
    localparam TIMESTEP = CLK_PERIOD/10;        // Time step of one tenth of a clock period
    localparam PROJECT_DIR = "";
    localparam TEST_IMAGE = {PROJECT_DIR, "mnist/file_0_5.jpg"};

    logic clk;
    integer test_image;


    // Generate a 50MHz clock
    initial clk = 1'b1;
    always #(CLK_PERIOD/2) clk = ~clk;

    
    // Producer Process
    initial begin
        // test image 1
        test_image = $fopen(TEST_IMAGE, "r");

        // Read the image PGM header

    end

    // Consumer process
    initial begin
        for (int i = 0; i < 100; i++) begin
            @(posedge clk);
        end 
        $stop();
    end
endmodule