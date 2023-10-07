`timescale 1ns/1ns

module de1soc_tb();
    logic clk_reset;

    logic clock;
    logic reset;
    logic resend;

    logic [ 31 : 0 ] out_data;
    logic out_valid;
    logic downstream_stall;

    task automatic read_next_value(int i);
    begin
        // Ready to read
        downstream_stall = 0;
        #1;
        while (!out_valid) begin
            @(posedge clock);
            #1;
        end
        // It is okay if it goes up to 32 even though image is 28*28, since we report up until power of two
        $display("%d: x=%d, y=%d @ time=%0t", i, out_data[31:16], out_data[15:0], $time);
        if (out_data[31:16] >= 32 || out_data[15:0] >= 32) begin
            $display("ERROR: Got an invalid output pixel");
            $stop();
        end
        @(posedge clock);
        downstream_stall = 1;
        @(posedge clock);
        @(posedge clock);
    end
    endtask

    task automatic read_values(int N);
    begin
        for (int i = 0; i < N; i++) begin
            read_next_value(i);
        end
    end
    endtask

    assign #5 clock = ~clock & !clk_reset;

    de1soc_tb_syn tb(clock, reset, out_data, out_valid, downstream_stall, resend);
    
    initial begin
        resend = 0;
        for (int j = 0; j < 1; j++) begin
            for (int i = 0; i < 4000; i++) begin
                @(posedge clock);
            end
            resend = 1;
            @(posedge clock);
            resend = 0;
        end
        resend = 0;      
        
        $stop();
    end

    initial begin
        clk_reset = 1;
        downstream_stall = 0;
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
        
        read_values(28*28*10);
        $stop();
    end
endmodule 