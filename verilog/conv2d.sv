module conv2d #(
    parameter WIDTH, 
    parameter KERNAL_SIZE = 3, 
    parameter VALUE_BITS = 32,
    parameter N = 16,
    parameter M = VALUE_BITS - N - 1,
    parameter OUTPUT_CHANNELS = 1,
    parameter INPUT_CHANNELS = 1,
    parameter RELU = 0
) (
    // general
    input   logic                               clk,                                    // Operating clock
    input   logic                               reset,                                  // Active-high reset signal (reset when set to 1)

    // Input Interface
    input   logic signed    [VALUE_BITS-1:0]    i_data[INPUT_CHANNELS],                 // Input pixel value (32-bit signed Q15.16)
    input   logic                               i_valid,                                // Set to 1 if input pixel is valid
    output  logic                               i_ready,                                // Set to 1 if consumer block is ready to receive a new pixel
    input   logic                               i_last,                                 // Set to 1 if input pixel is last of image
    input   logic signed    [VALUE_BITS-1:0]    i_weights[OUTPUT_CHANNELS][INPUT_CHANNELS][KERNAL_SIZE][KERNAL_SIZE],
    input   logic signed    [VALUE_BITS-1:0]    i_bias[OUTPUT_CHANNELS],

    // Output Interface
    output  logic signed    [VALUE_BITS-1:0]    o_data[OUTPUT_CHANNELS],                // Output pixel value (32-bit signed Q15.16)
    output  logic                               o_valid,                                // Set to 1 if output pixel is valid
    input   logic                               o_ready,                                // Set to 1 if this block is ready to receive a new pixel
    output  logic                               o_last                                  // Set to 1 if output pixel is last of image
);
    // shared signals
    logic                               i_readys[INPUT_CHANNELS];
    logic                               o_valids[INPUT_CHANNELS];
    logic                               o_lasts[INPUT_CHANNELS];
    logic signed    [VALUE_BITS-1:0]    o_data_per_in[INPUT_CHANNELS][OUTPUT_CHANNELS];
    logic signed    [VALUE_BITS-1:0]    i_weights_per_in[INPUT_CHANNELS][OUTPUT_CHANNELS][KERNAL_SIZE][KERNAL_SIZE];
    logic signed    [VALUE_BITS-1:0]    o_data_pre_relu[OUTPUT_CHANNELS];

    // connect weights
    always_comb begin
        for(int out_channel = 0; out_channel < OUTPUT_CHANNELS; out_channel++) begin
            for(int in_channel = 0; in_channel < INPUT_CHANNELS; in_channel++) begin
                i_weights_per_in[in_channel][out_channel] = i_weights[out_channel][in_channel];
            end
        end
    end

    // ASSUMING ALL COMPUTATION TAKES THE SAME TIME (which they should, they just use different weights)
    assign o_valid = o_valids[0];
    assign o_last = o_lasts[0];
    assign i_ready = i_readys[0];

    // calculate output, which is sum between channels and bias
    always_comb begin
        for(int out_channel = 0; out_channel < OUTPUT_CHANNELS; out_channel++) begin
            o_data_pre_relu[out_channel] = i_bias[out_channel];
            for(int in_channel = 0; in_channel < INPUT_CHANNELS; in_channel++) begin
                o_data_pre_relu[out_channel] += o_data_per_in[in_channel][out_channel];
            end
        end
    end

    // relu generate
    genvar o_channel;
    generate
        if(RELU) begin
            for (o_channel = 0; o_channel < OUTPUT_CHANNELS; o_channel++) begin : relu_per_channel
                // if negative then 0, else original value
                assign o_data[o_channel] = (o_data_pre_relu[o_channel][VALUE_BITS-1]) ? '0 : o_data_pre_relu[o_channel];
            end
        end
        else begin
            assign o_data = o_data_pre_relu;
        end
    endgenerate

    // Declare the conv2d_mult_out -- One for each input channel
    genvar i_channel;
    generate
        for (i_channel = 0; i_channel < INPUT_CHANNELS; i_channel++) begin : conv2d_top
            conv2d_mult_out #(
                .WIDTH(WIDTH),
                .KERNAL_SIZE(KERNAL_SIZE),
                .VALUE_BITS(VALUE_BITS),
                .N(N),
                .OUTPUT_CHANNELS(OUTPUT_CHANNELS)
            ) channel(
                .clk(clk),
                .reset(reset),
                .i_data(i_data[i_channel]),
                .i_valid(i_valid),
                .i_ready(i_readys[i_channel]),
                .i_last(i_last),
                .i_weights(i_weights_per_in[i_channel]),
                .o_data(o_data_per_in[i_channel]),
                .o_valid(o_valids[i_channel]),
                .o_ready(o_ready),
                .o_last(o_lasts[i_channel])
            );
        end
    endgenerate

endmodule

module conv2d_mult_out #(
    parameter WIDTH, 
    parameter KERNAL_SIZE = 3, 
    parameter VALUE_BITS = 32,
    parameter N = 16,
    parameter M = VALUE_BITS - N - 1,
    parameter OUTPUT_CHANNELS
) (
    // general
    input   logic                               clk,                                    // Operating clock
    input   logic                               reset,                                  // Active-high reset signal (reset when set to 1)

    // Input Interface
    input   logic signed    [VALUE_BITS-1:0]    i_data,                                 // Input pixel value (32-bit signed Q15.16)
    input   logic                               i_valid,                                // Set to 1 if input pixel is valid
    output  logic                               i_ready,                                // Set to 1 if consumer block is ready to receive a new pixel
    input   logic                               i_last,                                 // Set to 1 if input pixel is last of image
    input   logic signed    [VALUE_BITS-1:0]    i_weights [OUTPUT_CHANNELS][KERNAL_SIZE][KERNAL_SIZE],

    // Output Interface
    output  logic signed    [VALUE_BITS-1:0]    o_data[OUTPUT_CHANNELS],                // Output pixel value (32-bit signed Q15.16)
    output  logic                               o_valid,                                // Set to 1 if output pixel is valid
    input   logic                               o_ready,                                // Set to 1 if this block is ready to receive a new pixel
    output  logic                               o_last                                  // Set to 1 if output pixel is last of image
);
    // shared signals
    logic   o_valids[OUTPUT_CHANNELS];
    logic   o_lasts[OUTPUT_CHANNELS];

    // ASSUMING ALL COMPUTATION TAKES THE SAME TIME (which they should, they just use different weights)
    assign o_valid = o_valids[0];
    assign o_last = o_lasts[0];

    // Declare the conv2d_single_out -- One for each output channel
    genvar o_channel;
    generate
        for (o_channel = 0; o_channel < OUTPUT_CHANNELS; o_channel++) begin : conv2d_mult_out
            conv2d_single_out #(
                .WIDTH(WIDTH),
                .KERNAL_SIZE(KERNAL_SIZE),
                .VALUE_BITS(VALUE_BITS),
                .N(N) 
            ) channel(
                .clk(clk),
                .reset(reset),
                .i_data(i_data),
                .i_valid(i_valid),
                .i_ready(i_ready),
                .i_last(i_last),
                .i_weights(i_weights[o_channel]),
                .o_data(o_data[o_channel]),
                .o_valid(o_valids[o_channel]),
                .o_ready(o_ready),
                .o_last(o_lasts[o_channel])
            );
        end
    endgenerate

endmodule

module conv2d_single_out #(
    parameter WIDTH, 
    parameter KERNAL_SIZE = 3, 
    parameter VALUE_BITS = 32,
    parameter N = 16,
    parameter M = VALUE_BITS - N - 1
) (
    // general
    input   logic                               clk,                                    // Operating clock
    input   logic                               reset,                                  // Active-high reset signal (reset when set to 1)

    // Input Interface
    input   logic signed    [VALUE_BITS-1:0]    i_data,                                 // Input pixel value (32-bit signed Q15.16)
    input   logic                               i_valid,                                // Set to 1 if input pixel is valid
    output  logic                               i_ready,                                // Set to 1 if consumer block is ready to receive a new pixel
    input   logic                               i_last,                                 // Set to 1 if input pixel is last of image
    input   logic signed    [VALUE_BITS-1:0]    i_weights [KERNAL_SIZE][KERNAL_SIZE],

    // Output Interface
    output  logic signed    [VALUE_BITS-1:0]    o_data,                                 // Output pixel value (32-bit signed Q15.16)
    output  logic                               o_valid,                                // Set to 1 if output pixel is valid
    input   logic                               o_ready,                                // Set to 1 if this block is ready to receive a new pixel
    output  logic                               o_last                                  // Set to 1 if output pixel is last of image

);
    logic signed [VALUE_BITS - 1 : 0] taps[KERNAL_SIZE][KERNAL_SIZE];

    shift_buffer_array_conv #(
        .WIDTH(WIDTH), 
        .TAP_WIDTH(KERNAL_SIZE), 
        .TAP_HEIGHT(KERNAL_SIZE), 
        .VALUE_BITS(VALUE_BITS)
    ) buffer(
        .clk(clk), 
        .reset(reset),
        // input interface 
        .i_data(i_data),
        .i_valid(i_valid), 
        .i_ready(i_ready), 
        .i_last(i_last),
        
        // output interface
        .o_taps(taps), 
        .o_valid(o_valid), 
        .o_ready(o_ready),
        .o_last(o_last)
    );

    // KERNAL LOGIC -- SIMPLE NON-PIPELINED VERSION
    logic signed    [2*VALUE_BITS-1:0]  tmp;
    always_comb begin
        tmp = 0;
        if (o_valid) begin
            for (int row = 0; row < KERNAL_SIZE; row++) begin
                for (int col = 0; col < KERNAL_SIZE; col++) begin
                    tmp += i_weights[row][col] * taps[row][col];
                end
            end
            // maybe add logic to check for overflow here?
            // if (tmp > 255) o_y_comb = 255;
            // else if (tmp < 0) o_y_comb = 0;
            // else o_y_comb = tmp;
        end
    end
    
    assign o_data = tmp[N+:VALUE_BITS];

endmodule 

// Core data organizational structure for my CNN implementation
// FMax: Module can run at 420-430 MHz
// INPUTS: Stream in pixels one at a time in row-major order serially
// OUTPUTS: A paralell rectangular output slice, called a tap, which marches across the image in row-major order (to be fed to kernal)
// IMPLEMENTATION: Implemented as TAP_HEIGHT independant rams with SIMD reading and individual-control writing
//        One row (which rotates around) is used as writing scratchpad, while all rows are simoultaniously read
//        When reading we perform arbitrary rotiation on data so that the output view apears as a FIFO sliding 
//        window vertically even though the implementation is actually a rotating buffer
module shift_buffer_array_conv #(
    parameter WIDTH, 
    parameter TAP_WIDTH, 
    parameter TAP_HEIGHT, 
    parameter VALUE_BITS
)(
    // General
    input   logic                           clk,                            // Operating clock
    input   logic                           reset,                          // Active-high reset signal (reset when set to 1)
    // input interface
    input   logic signed [VALUE_BITS-1:0]   i_data,                         // Input data (for now signed Q15.16)
    input   logic                           i_valid,                        // Set to 1 if input is valid
    output  logic                           i_ready,                        // Set to 1 if ready to receive data
    input   logic                           i_last,                         // Set to 1 if i_data is the last pixel
    
    // output interface
    output  logic signed [VALUE_BITS-1:0]   o_taps[TAP_HEIGHT][TAP_WIDTH],  // row-major output to be tapped by the kernal
    output  logic                           o_valid,                        // Set to 1 if taps valid
    input   logic                           o_ready,                        // Set to 1 if taps ready to be consumed
    output  logic                           o_last                          // Set to 1 if o_taps is the last tap
    
);
    // SEQUENTIAL LOGIC ELEMENTS
    
    // Output State
    logic signed [VALUE_BITS-1:0]   taps_q[TAP_HEIGHT][TAP_WIDTH]; // This is what gets fed into the kerneal
    logic                           taps_last_q;
    assign o_taps = taps_q;
    assign o_last = taps_last_q;

    // If our output is 3 rows tall, we only buffer 2 rows since last row can be read directly from input
    // and than overwrite one of the rows whoes contents we just read out meaning only need 2 buffers
    parameter BUFFER_HEIGHT = TAP_HEIGHT-1; 

    // Read state
    logic [VALUE_BITS-1:0]              ram_r_data_q[BUFFER_HEIGHT];    // synchronous result from the ram access
    // Write synchronous state
    logic [$clog2(BUFFER_HEIGHT)-1:0]   ram_w_row_select_q;             // this denotes the row we are currently writing to
    logic [$clog2(WIDTH)-1:0]           ram_w_addr_q;                   // if we are going to write, this is the address we write to 
    logic [$clog2(WIDTH)-1:0]           prev_ram_r_addr_q; 
    // Book-keeping state
    logic                               input_done_row_q;
    logic                               output_done_row_q;
    logic                               buffer_contents_valid_q;        // on reset or new image, buffer contents are invalid initially

    // Combinational Logic Elements
    logic [$clog2(WIDTH)-1:0]           ram_r_addr;                     // this is address for reading the ram
    logic [$clog2(WIDTH)-1:0]           next_ram_w_addr;                // specify the next value for write address
    logic [$clog2(BUFFER_HEIGHT)-1:0]   next_ram_w_row_select;          // the ram write head value
    logic signed [VALUE_BITS-1:0]       next_taps[TAP_HEIGHT][TAP_WIDTH];
    logic                               write_en;                       // should we write to the ram this cycle
    logic                               next_input_done_row; 
    logic                               next_output_done_row;
    logic                               next_buffer_contents_valid;
    logic                               next_taps_last;

    // Declare the row buffer rams -- One for each of the rows
    genvar ram_num;
    generate
        for (ram_num = 0; ram_num < BUFFER_HEIGHT; ram_num++) begin : buffer_rams
            // Declare duel-port ram with SIMD controls 
            duel_port_ram #(.VALUE_BITS(VALUE_BITS), .WIDTH(WIDTH)) line_ram(
                .clk(clk), .w_data(i_data), .w_addr(ram_w_addr_q), 
                // Ram read outputs are stored to a vector, one read address loads one value per row
                .r_addr(ram_r_addr), .r_data(ram_r_data_q[ram_num]),
                // Write only occurs if the currently writing row matches current row
                .w_valid(write_en && (ram_w_row_select_q==ram_num))
            );
        end
    endgenerate

    always_comb begin
        // Persistant outputsignals
        ram_r_addr = prev_ram_r_addr_q;
        next_ram_w_addr = ram_w_addr_q;
        next_ram_w_row_select = ram_w_row_select_q;
        next_buffer_contents_valid = buffer_contents_valid_q;
        next_input_done_row = input_done_row_q;
        next_output_done_row = output_done_row_q;
        // Output signals
        next_taps = taps_q;
        write_en = 0;
        o_valid = 0;
        next_taps_last = 0;
        i_ready = (!input_done_row_q && o_ready && !taps_last_q); // ready to receive input when input is not done with its row, and downstream is accepting data, and we are not waiting for last tap to be consumed

        // Input and output march in lockstep so both must be ready to march
        // Input must be valid, or we are done with the input row
        // Output must be ready to accept 
        // Don't do anything if last tap is on display
        if ((i_valid || input_done_row_q) && o_ready && !taps_last_q) begin
            
            // Input logic -- Latch as long as we are not done with the input row
            if (!input_done_row_q) begin
                write_en = 1; // latch this value into our ram
                next_input_done_row = ram_w_addr_q == WIDTH-1; // Check if we are done
                next_ram_w_addr = ram_w_addr_q + 1; // Increment read position
            end

            // Output Logic
            // Display if we are not done with output, and we have enough buffered rows, and writer thread has already started / is ahead of us
            // output_done_row_q won't change until buffer_contents_valid_q was high when we have enough data
            if (!output_done_row_q && buffer_contents_valid_q) begin 
                // This tells if the current value on the taps is the last valid one, 
                // if so the next_taps value from this cycle is garbage but who cares
                // That is beacuse while we load gargbage into next_taps, current value taps are being read
                // Experimented with a number of ways but this was most performant
                next_output_done_row = (prev_ram_r_addr_q == WIDTH); 
                ram_r_addr = prev_ram_r_addr_q + 1;//increment 
                // Latch next output values 
                // For each of the output rows 
                for (int out_row = 0; out_row < TAP_HEIGHT; out_row++) begin
                    // For each of the output columns perform the shift register 
                    for (int out_col = 1; out_col < TAP_WIDTH; out_col++) begin
                        next_taps[out_row][out_col-1] = taps_q[out_row][out_col]; 
                    end
                    // Shift in the new values we read from ram
                    // Note this is the value that was read from ram last cycle, at prev_ram_r_addr_q
                    if (out_row != BUFFER_HEIGHT) begin
                        next_taps[out_row][TAP_WIDTH-1] = ram_r_data_q[ ((out_row+ram_w_row_select_q)<BUFFER_HEIGHT)?
                                    (out_row+ram_w_row_select_q)
                                :    (out_row+ram_w_row_select_q-BUFFER_HEIGHT) ]; 
                    // We shift in i_data for the top row as the current value, also mark the tap as last if it is the last data
                    end else begin
                        next_taps_last = i_last;
                        next_taps[out_row][TAP_WIDTH-1] = i_data;
                    end
                end
                // This condition ensures that we don't start outputting until we shifted in enough columns to be fully valid output
                o_valid = prev_ram_r_addr_q >= TAP_WIDTH; 
            end
        end

        // Logic to change which row is currently the buffer row and which rows are the output rows being read
        if (input_done_row_q && (output_done_row_q || !buffer_contents_valid_q)) begin
            // Reset the flags so they can both start again
            next_input_done_row = 0;
            next_output_done_row = 0;
            // We are incrementing rows so go back to start of row
            next_ram_w_addr = 0;
            ram_r_addr = 0;
            // Increment the write row pointer by one
            next_ram_w_row_select = ram_w_row_select_q + 1;
            // If the write row is the last row than rotate back around to zero
            if (ram_w_row_select_q == BUFFER_HEIGHT-1) begin
                // Reset write row head back to zero for wrap around
                next_ram_w_row_select = 0;
            end
            // Once first TAP_HEIGHT rows have been written than buffer contents valid
            // This is only used at start-up to ensure we don't start outputting until on third row
            if (ram_w_row_select_q == BUFFER_HEIGHT-1) begin
                next_buffer_contents_valid = 1;
            end
        end

        // if advertising last tap available then have o_valid high
        if(taps_last_q) o_valid = 1;
    end

    // Synchronous logic. We update the state on the positive edge of the clock
    always_ff@(posedge clk) begin
        // Reset all values to zero
        if (reset) begin
            ram_w_row_select_q <= 0;
            ram_w_addr_q <= 0;
            prev_ram_r_addr_q <= 0;
            input_done_row_q <= 0;
            output_done_row_q <= 0;
            buffer_contents_valid_q <= 0;
            taps_last_q <= 0;
        end 
        // if last tap will be consumed, then reset relevant signal and get ready for accepting new input
        else if (taps_last_q && o_ready) begin
            ram_w_row_select_q <= 0;
            ram_w_addr_q <= 0;
            prev_ram_r_addr_q <= 0;
            input_done_row_q <= 0;
            output_done_row_q <= 0;
            buffer_contents_valid_q <= 0;
            taps_last_q <= 0;
        end
        // Latch from combinational signals into the state variables
        else begin
            ram_w_row_select_q <= next_ram_w_row_select;
            ram_w_addr_q <= next_ram_w_addr;
            prev_ram_r_addr_q <= ram_r_addr;
            taps_q <= next_taps;
            input_done_row_q <= next_input_done_row;
            output_done_row_q <= next_output_done_row;
            buffer_contents_valid_q <= next_buffer_contents_valid;
            taps_last_q <= next_taps_last;
        end
    end
endmodule 

// A duel-port ram with word-size of VALUE_BITS, and WIDTH elements
module duel_port_ram #(
    parameter VALUE_BITS, 
    parameter WIDTH
)(
    input   logic                           clk,
    
    // write interface
    input   logic signed [VALUE_BITS-1:0]   w_data,    
    input   logic [$clog2(WIDTH)-1:0]       w_addr,
    input   logic                           w_valid,

    // read interface
    input   logic [$clog2(WIDTH)-1: 0]      r_addr,
    output  logic signed [VALUE_BITS-1:0]   r_data
);
    // The actual ram
    logic signed [VALUE_BITS-1:0] ram[WIDTH];
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