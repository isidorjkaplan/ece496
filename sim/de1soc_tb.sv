`timescale 1ns/1ns

module de1soc_tb();
    logic clk_reset;

    logic clock;
    logic reset;
    logic resend;

    logic [ 31 : 0 ] out_data;
    logic out_valid;
    logic downstream_stall;

    task automatic read_next_value();
    begin
        downstream_stall = 0;
        // Ready to read
        //downstream_stall = 0;
        #1;
        while (!out_valid) begin
            @(posedge clock);
            #1;
        end
        @(posedge clock);
    end
    endtask

    task automatic read_next_pixel(int i);
    begin
        int x, y, r, g, b;
        read_next_value();
        x = out_data;
        read_next_value();
        y = out_data;
        read_next_value();
        r = out_data;
        read_next_value();
        g = out_data;
        read_next_value();
        b = out_data;

        $display("%d: Read pixel (x,y)=(%d,%d) with rgb value (%d,%d,%d)", i, x, y, r, g, b);
    end
    endtask

    task automatic read_values(int N);
    begin
        for (int i = 0; i < N; i++) begin
            read_next_pixel(i);
        end
    end
    endtask

    assign #5 clock = ~clock & !clk_reset;

    de1soc_tb_syn tb(clock, reset, out_data, out_valid, downstream_stall, resend);
    
    initial begin 
        for (int i = 0; i < 40000; i++) begin
            @(posedge clock);
        end
        $display("Ran out of time. stopping sim");
        $stop();
    end
    
    initial begin
        resend = 0;
        clk_reset = 1;
        downstream_stall = 1;
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
        
        read_values(32*32*2);
        $stop();
    end
endmodule 