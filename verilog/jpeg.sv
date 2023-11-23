// Input is streamed as a jpeg file 
// Output is streamed in row-major order 
module jpeg_decoder #(
    parameter WIDTH = 28,   // For MNIST
    parameter HEIGHT = 28,  // HACK: for some reason last 4 rows are just not working properly
    parameter MAX_JPEG_WORDS = 1024
)(
    // General signals
    input clk, 
    input reset,
    // next row logic
    input   logic        [31 : 0]  in_data,
    input   logic                  in_last, // MUST ARRIVE WITH DATA
    input   logic                  in_valid,
    output  logic                  in_ready,
    // output row valid 
    output  logic         [7 : 0] out_data[3], // RGBA 7-bit
    output  logic                 out_valid,
    output  logic                 out_last,
    input   logic                 out_ready
);    
    localparam VALUE_BITS = 8;
    localparam WORD_SIZE = 32;

    logic [$clog2(MAX_JPEG_WORDS-1)-1:0] write_byte_idx_q;
    logic [$clog2(MAX_JPEG_WORDS-1)-1:0] next_read_byte_idx;

    logic [WORD_SIZE-1:0] read_word;

    ram_1d #(.VALUE_BITS(WORD_SIZE), .WIDTH(MAX_JPEG_WORDS)) img_buffer(
        .clk(clk), 
        .w_data(in_data), 
        .w_addr(write_byte_idx_q),
        .w_valid(in_valid && in_ready),
        .r_addr(next_read_byte_idx),
        .r_data(read_word)
    );

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

    // This specifies if the JPEG unit is busy. When busy it cannot accept another image
    logic busy_q;


    // GLUE 

    // sequential
    logic [$clog2(MAX_JPEG_WORDS-1)-1:0] max_byte_idx_q;
    logic [$clog2(MAX_JPEG_WORDS-1)-1:0] read_byte_idx_q;

    // combinational
    logic [$clog2(MAX_JPEG_WORDS-1)-1:0] next_max_byte_idx;
    logic [$clog2(MAX_JPEG_WORDS-1)-1:0] next_write_byte_idx;

    always_comb begin
        next_max_byte_idx = max_byte_idx_q;
        next_write_byte_idx = write_byte_idx_q;
        next_read_byte_idx = read_byte_idx_q;

        // INPUT -> BUFFER

        // Either we are not reading anything out of the ram
        // Or we are reading, but already read the value we will overwrite
        // For now we don't allow reading in next image if previous image is still in the pipeline
        in_ready = (max_byte_idx_q==0);// || (read_byte_idx_q > write_byte_idx_q); 
        // We latch teh value
        if (in_valid && in_ready) begin
            next_write_byte_idx = write_byte_idx_q + 1;
            if (in_last) begin 
                next_max_byte_idx = write_byte_idx_q;
                next_write_byte_idx = 0;
                next_read_byte_idx = 0;
            end
        end

        // BUFFER -> JPEG

        inport_valid_i = (max_byte_idx_q != 0) && !busy_q;// && (idle_o || (read_byte_idx_q!=0));
        inport_strb_i = 4'b1111;
        inport_last_i = (read_byte_idx_q == max_byte_idx_q) && inport_valid_i;
        inport_data_i = read_word; 
        // If we are in readout mode and the jpeg decoder accepts the current value
        if (inport_valid_i && inport_accept_o) begin
            next_read_byte_idx = read_byte_idx_q + 1;

            if (read_byte_idx_q == max_byte_idx_q) begin
                next_max_byte_idx = 0;
                next_read_byte_idx = 0;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            write_byte_idx_q <= 0;
            read_byte_idx_q <= 0;
            max_byte_idx_q <= 0;
        end else begin
            // if (in_last && in_valid && in_ready)
            //     $display("Read last byte from input as %x into %d at t=%d", in_data, write_byte_idx_q, $time());
            // if (inport_valid_i)
            //     $display("Read into JPEG last=%d byte as %x from %d at t=%d", inport_last_i, inport_data_i, read_byte_idx_q, $time()); 

            write_byte_idx_q <= next_write_byte_idx;
            read_byte_idx_q <= next_read_byte_idx;
            max_byte_idx_q <= next_max_byte_idx;
        end
    end


    // DUT
    jpeg_core jpeg(
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

    // JPEG -> OUT_BUFFER
    logic [$clog2(WIDTH)-1:0] next_result_x;
    logic [$clog2(HEIGHT)-1:0] next_result_y;

    ram_3d #(.VALUE_BITS(8), .WIDTH(WIDTH), .HEIGHT(HEIGHT), .CHANNELS(3)) out_buffer(
        .clk(clk), 
        .w_data('{outport_pixel_r_o, outport_pixel_g_o, outport_pixel_b_o}), 
        .w_addr_x(outport_pixel_x_o[$clog2(WIDTH)-1:0]),
        .w_addr_y(outport_pixel_y_o[$clog2(HEIGHT)-1:0]),
        .w_valid(outport_valid_o),
        .r_addr_x(next_result_x),
        .r_addr_y(next_result_y),
        .r_data(out_data)
    );

    logic [$clog2(WIDTH+1)-1:0] row_result_count_q[HEIGHT-1:0]; 

    // TODO write logic that streams outputs in row order using ram3d instead of in output order

    logic [$clog2(WIDTH)-1:0] result_x_q;
    logic [$clog2(HEIGHT)-1:0] result_y_q;

    logic incr_result_x;
    logic incr_result_y;
    logic reset_result_x;
    logic reset_result_y;

    always_comb begin
        //outport_accept_i = out_ready;
        //out_data = {outport_pixel_r_o, outport_pixel_g_o, outport_pixel_b_o};
        //out_valid = outport_valid_o && outport_pixel_x_o < WIDTH && outport_pixel_y_o < HEIGHT;

        outport_accept_i = out_ready;

        // Increment counters
        incr_result_x = 0;
        incr_result_y = 0;
        // Reset counters -- priority over increment counters
        reset_result_x = 0;
        reset_result_y = 0;

        out_last = 0;

        out_valid = row_result_count_q[result_y_q] == WIDTH;
        if (out_valid && out_ready) begin
            // Increment or reset X
            if (result_x_q == WIDTH-1) begin
                reset_result_x = 1;
                // Increment or reset Y
                if (result_y_q == HEIGHT-1) begin
                    reset_result_y = 1;
                    out_last = 1;
                end else begin
                    incr_result_y = 1;
                end
            
            end else begin
                incr_result_x = 1;
            end
        end


        // Handle x
        if (reset_result_x) next_result_x = 0;
        else if (incr_result_x) next_result_x = (result_x_q + 1);
        else next_result_x = result_x_q;
        
        // Handle y
        if (reset_result_y) next_result_y = 0;
        else if (incr_result_y) next_result_y = (result_y_q + 1);
        else next_result_y = result_y_q;

            
    end

    always_ff@(posedge clk) begin
        if (reset) begin
            for (int y = 0; y < HEIGHT; y++) begin
                row_result_count_q[y] <= 0;
            end
            result_x_q <= 0;
            result_y_q <= 0;
        end else begin // Not in reset
            // Increment row counter when we get a pixel result
            if (outport_valid_o && outport_accept_i && outport_pixel_x_o < WIDTH && outport_pixel_y_o < HEIGHT) begin
                row_result_count_q[outport_pixel_y_o] <= row_result_count_q[outport_pixel_y_o]+1;
            end

            result_x_q <= next_result_x;
            result_y_q <= next_result_y;

            // When leaving a row reset its counter
            if (incr_result_y || reset_result_y) begin
                row_result_count_q[result_y_q] <= 0;
            end
        end
    end
    
    // Logic that is used to keep track of if the module is "busy"
    // Jpeg decoder is NOT pipelined, must wait until fully done before next image can start
    always_ff@(posedge clk) begin
        if (reset) busy_q <= 0;
        else if (inport_valid_i && inport_last_i && inport_accept_o) busy_q <= 1; 
        else if (reset_result_y) busy_q <= 0;
    end

endmodule

module ram_3d #(
    parameter VALUE_BITS, 
    parameter WIDTH,
    parameter HEIGHT,
    parameter CHANNELS
)(
    input   logic                           clk,
    
    // write interface
    input   logic [VALUE_BITS-1:0]          w_data[CHANNELS],    
    input   logic [$clog2(WIDTH)-1:0]     w_addr_x,
    input   logic [$clog2(HEIGHT)-1:0]    w_addr_y,
    input   logic                           w_valid,

    // read interface
    input   logic [$clog2(WIDTH)-1: 0]    r_addr_x,
    input   logic [$clog2(HEIGHT)-1: 0]   r_addr_y,
    output  logic [VALUE_BITS-1:0]          r_data[CHANNELS]
);
    genvar ch;
    generate
        for (ch = 0; ch < CHANNELS; ch++) begin : rams
            ram_1d #(.VALUE_BITS(VALUE_BITS), .WIDTH((1<<$clog2(WIDTH))*(1<<$clog2(HEIGHT)))) ram(
                .clk(clk), 
                .w_data(w_data[ch]),
                .w_addr({w_addr_y, w_addr_x}), 
                .w_valid(w_valid),

                .r_addr({r_addr_y, r_addr_x}),
                .r_data(r_data[ch])  
            );
        end
    endgenerate
endmodule 


// A dual-port ram with word-size of VALUE_BITS, and WIDTH elements
module ram_1d #(
    parameter VALUE_BITS, 
    parameter WIDTH
)(
    input   logic                           clk,
    
    // write interface
    input   logic [VALUE_BITS-1:0]          w_data,    
    input   logic [$clog2(WIDTH)-1:0]       w_addr,
    input   logic                           w_valid,

    // read interface
    input   logic [$clog2(WIDTH)-1: 0]      r_addr,
    output  logic [VALUE_BITS-1:0]          r_data
);
    // The actual ram
    logic [VALUE_BITS-1:0] ram[WIDTH];
    // All operations are synchronous
    always_ff@(posedge clk) begin
        // read
        r_data <= ram[r_addr];
        // write
        if (w_valid) begin
            ram[w_addr] <= w_data;
        end
    end
endmodule