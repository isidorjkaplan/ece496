module conv2d #(
    parameter WIDTH, 
    parameter KERNAL_SIZE, 
    parameter VALUE_BITS,
    parameter VALUE_Q_FORMAT_N,
    parameter WEIGHTS_Q_FORMAT_N,
    parameter OUTPUT_CHANNELS,
    parameter INPUT_CHANNELS,
    parameter STRIDE,
    parameter RELU,
    parameter OUT_CHANNELS_PER_CYCLE = 1
) (
    // general
    input   logic                               clk,                                    // Operating clock
    input   logic                               reset,                                  // Active-high reset signal (reset when set to 1)

    // Input Interface
    input   logic signed    [VALUE_BITS-1:0]    i_data[INPUT_CHANNELS],                 // Input pixel value (32-bit signed Q15.16)
    input   logic                               i_valid,                                // Set to 1 if input pixel is valid
    output  logic                               i_ready,                                // Set to 1 if consumer block is ready to receive a new pixel
    input   logic                               i_last,                                 // Set to 1 if input pixel is last of image
    input   logic signed    [31:0]              i_weights[OUTPUT_CHANNELS][INPUT_CHANNELS][KERNAL_SIZE][KERNAL_SIZE],
    input   logic signed    [31:0]              i_bias[OUTPUT_CHANNELS],

    // Output Interface
    output  logic signed    [VALUE_BITS-1:0]    o_data[OUTPUT_CHANNELS],                // Output pixel value (32-bit signed Q15.16)
    output  logic                               o_valid,                                // Set to 1 if output pixel is valid
    input   logic                               o_ready,                                // Set to 1 if this block is ready to receive a new pixel
    output  logic                               o_last                                  // Set to 1 if output pixel is last of image
);
    localparam OUT_WIDTH = WIDTH - KERNAL_SIZE + 1;

    // shared signals
    logic                               i_readys[INPUT_CHANNELS];
    logic                               next_o_valids[INPUT_CHANNELS];
    logic                               next_o_valid;
    logic                               o_valid_q;
    logic                               next_o_lasts[INPUT_CHANNELS];
    logic                               next_o_last;
    logic                               o_last_q;
    logic signed    [VALUE_BITS-1:0]    i_weights_per_in[INPUT_CHANNELS][OUTPUT_CHANNELS][KERNAL_SIZE][KERNAL_SIZE];
    logic signed    [VALUE_BITS-1:0]    i_bias_per_out[OUTPUT_CHANNELS];
    logic signed    [VALUE_BITS-1:0]    o_data_per_in[INPUT_CHANNELS][OUTPUT_CHANNELS];
    logic signed    [VALUE_BITS-1:0]    next_o_data_pre_relu[OUTPUT_CHANNELS];
    logic signed    [VALUE_BITS-1:0]    next_o_data[OUTPUT_CHANNELS];
    logic signed    [VALUE_BITS-1:0]    o_data_q[OUTPUT_CHANNELS];
    

    // connect weights and conform them from Q15.16 to the QM.N format we are using
    always_comb begin
        for(int out_channel = 0; out_channel < OUTPUT_CHANNELS; out_channel++) begin
            for(int in_channel = 0; in_channel < INPUT_CHANNELS; in_channel++) begin
                for(int row = 0; row < KERNAL_SIZE; row++) begin
                    for(int col = 0; col < KERNAL_SIZE; col++) begin
                        i_weights_per_in[in_channel][out_channel][row][col] = i_weights[out_channel][in_channel][row][col][(WEIGHTS_Q_FORMAT_N-VALUE_Q_FORMAT_N)+:VALUE_BITS];
                    end
                end                
            end
            i_bias_per_out[out_channel] = i_bias[out_channel][(WEIGHTS_Q_FORMAT_N-VALUE_Q_FORMAT_N)+:VALUE_BITS];
        end
    end

    // ASSUMING ALL COMPUTATION TAKES THE SAME TIME (which they should, they just use different weights)
    assign next_o_valid = next_o_valids[0];
    assign next_o_last = next_o_lasts[0];
    assign i_ready = i_readys[0];

    // output with ff stuff
    assign o_data = o_data_q;
    assign o_last = o_last_q;

    // stride masking of output
    logic [$clog2(STRIDE-1):0] stride_row_mod_counter;
    logic [$clog2(STRIDE-1):0] stride_col_mod_counter;
    logic [$clog2(OUT_WIDTH-1):0] stride_col_counter;

    always_ff@(posedge clk) begin
        if (reset || (o_last && o_ready)) begin
            stride_row_mod_counter <= 0;
            stride_col_mod_counter <= 0;
            stride_col_counter <= 0;
        end else if (o_valid_q && o_ready) begin // if the result would actually be latched otherwise don't do anything
            // Always increment column mod STRIDE, resetting whenever we count STRIDE pixels
            stride_col_mod_counter <= (stride_col_mod_counter==(STRIDE-1))?0:(stride_col_mod_counter+1);
            // Always increment column, resetting when we get a full row
            stride_col_counter <= stride_col_counter + 1;
            // If we are about to reset the column we increment the row
            if (stride_col_counter == (OUT_WIDTH-1)) begin
                // Increment row mod counter, resetting when we hit STRIDE rows
                stride_row_mod_counter <= (stride_row_mod_counter == (STRIDE-1)) ? 0 : (stride_row_mod_counter+1);
                // The column resets when the row increments
                stride_col_counter <= 0;
                stride_col_mod_counter <= 0;
            end
        end
    end
    // Mask for stride purposes
    assign o_valid = o_valid_q && (stride_row_mod_counter == (STRIDE-1) && stride_col_mod_counter == (STRIDE-1));
  

    // calculate output, which is sum between channels and bias
    always_comb begin
        for(int out_channel = 0; out_channel < OUTPUT_CHANNELS; out_channel++) begin
            next_o_data_pre_relu[out_channel] = i_bias_per_out[out_channel];
            for(int in_channel = 0; in_channel < INPUT_CHANNELS; in_channel++) begin
                next_o_data_pre_relu[out_channel] += o_data_per_in[in_channel][out_channel];
            end
        end
    end

    // relu generate
    genvar o_channel;
    generate
        if(RELU) begin
            for (o_channel = 0; o_channel < OUTPUT_CHANNELS; o_channel++) begin : relu_per_channel
                // if negative then 0, else original value
                assign next_o_data[o_channel] = (next_o_data_pre_relu[o_channel][VALUE_BITS-1]) ? '0 : next_o_data_pre_relu[o_channel];
            end
        end
        else begin
            assign next_o_data = next_o_data_pre_relu;
        end
    endgenerate

    // output ff
    always_ff@(posedge clk) begin
        if(reset) begin
            o_valid_q <= 0;
            o_last_q <= 0;
            for(int o_ch = 0; o_ch < OUTPUT_CHANNELS; o_ch++)begin
                o_data_q[o_ch] <= '0;
            end
        end else if(o_ready) begin
            o_valid_q <= next_o_valid;
            o_last_q <= next_o_last;
            o_data_q <= next_o_data;
        end
    end

    // Declare the conv2d_mult_out -- One for each input channel
    genvar i_channel;
    generate
        for (i_channel = 0; i_channel < INPUT_CHANNELS; i_channel++) begin : conv2d_top
            conv2d_single_in_mult_out #(
                .WIDTH(WIDTH),
                .KERNAL_SIZE(KERNAL_SIZE),
                .VALUE_BITS(VALUE_BITS),
                .VALUE_Q_FORMAT_N(VALUE_Q_FORMAT_N),
                .OUTPUT_CHANNELS(OUTPUT_CHANNELS),
                .OUT_CHANNELS_PER_CYCLE(OUT_CHANNELS_PER_CYCLE)
            ) channel(
                .clk(clk),
                .reset(reset),
                .i_data(i_data[i_channel]),
                .i_valid(i_valid),
                .i_ready(i_readys[i_channel]),
                .i_last(i_last),
                .i_weights(i_weights_per_in[i_channel]),
                .o_data(o_data_per_in[i_channel]),
                .o_valid(next_o_valids[i_channel]),
                .o_ready(o_ready),
                .o_last(next_o_lasts[i_channel])
            );
        end
    endgenerate

endmodule

// time multiplex with output channels
// computes one output channel per cycle
// output valid once everything is generated
module conv2d_single_in_mult_out #(
    parameter WIDTH, 
    parameter KERNAL_SIZE, 
    parameter VALUE_BITS,
    parameter VALUE_Q_FORMAT_N,
    parameter OUTPUT_CHANNELS,
    parameter OUT_CHANNELS_PER_CYCLE
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
    
    logic signed [VALUE_BITS - 1 : 0]   buffer_taps[KERNAL_SIZE][KERNAL_SIZE];
    logic                               buffer_ready;
    logic                               buffer_valid;
    logic                               buffer_last;

    // registered value for processing
    logic signed [VALUE_BITS - 1 : 0]   taps_q[KERNAL_SIZE][KERNAL_SIZE];
    logic                               taps_valid_q;
    logic                               taps_last_q;

    // generate output data
    logic [$clog2(OUTPUT_CHANNELS+OUT_CHANNELS_PER_CYCLE):0]   counter;
    logic signed [VALUE_BITS-1:0]       o_data_q[OUTPUT_CHANNELS];
    logic                               o_valid_q;
    logic signed [VALUE_BITS-1:0]       weights[KERNAL_SIZE][KERNAL_SIZE];
    // use dsp counter so counter value increment every three cycle
    // first cycle correct weights loaded into register from i_weight
    // second cycle correct data into dsp_out_q
    // third cycle o_data_q loaded from dsp_out_q and counter increment
    logic                               dsp_counter;

    assign o_valid = o_valid_q;
    // if we do have a valid tap to send, then don't show last until its completed
    // or else propogate the last signal
    assign o_last = taps_valid_q ? (taps_last_q && o_valid_q) : (taps_last_q);
    assign o_data = o_data_q;

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
        .o_taps(buffer_taps), 
        .o_valid(buffer_valid), 
        .o_ready(buffer_ready),
        .o_last(buffer_last)
    );

    // logging taps value
    always_ff@(posedge clk) begin
        // Reset values
        // taps last and taps valid to 0 since we dont have a valid tap value
        // buffer_ready because we are ready to log the taps value
        if (reset) begin
            taps_valid_q <= 0;
            taps_last_q <= 0;
            buffer_ready <= 1;
        end 
        // log taps value if we are ready and valid taps value is presented
        // also set buffer_ready low and start compute o_data
        else if (buffer_ready && buffer_valid) begin
            taps_q <= buffer_taps;
            taps_valid_q <= 1;
            buffer_ready <= 0;
            taps_last_q <= buffer_last;
        end
        // if consumed then reset signal and tell buffer we can get next tap
        else if (o_valid_q && o_ready) begin
            taps_valid_q <= 0;
            taps_last_q <= 0;
            buffer_ready <= 1;
        end 
        // last can propogate even if not valid
        else if (buffer_ready) begin 
            taps_last_q <= buffer_last;
        end
    end

    // control signal for computing and gating output
    always_ff@(posedge clk) begin
        if(reset) begin
            counter <= '0;
            o_valid_q <= 0;

        end
        // if true it means that we computed the last o_data signal last cycle so we are done
        // written this way for now due to easier logic, wastes one cycle here
        else if(counter >= OUTPUT_CHANNELS) begin
            counter <= '0;

            o_valid_q <= 1;
        end
        // if taps is valid and we haven't generated output yet then increment counter every cycle
        // increment to work with different channel's weight and log them in correct position when computed
        // we will stay in each counter for two cycles due to timing limitation
        else if(taps_valid_q && !o_valid_q) begin

            counter <= counter + OUT_CHANNELS_PER_CYCLE;

        end
        // if data is computed and output is ready to consume, then next posedge it will be consumed
        // then lower o_valid_q
        else if(o_valid_q && o_ready) begin
            o_valid_q <= 0;
        end
    end

    // KERNAL LOGIC -- computation split in two parts
    // log values onto o_data_q as long as counter in range and not o_valid_q
    // fine without reset since when o_valid_q is low, garbage in o_data_q shouldn't matter
    // once o_valid high stop changing its output until o_valid is low again
    // which means its consumed
    // 
    // takes 2 cycle to compute and have it loaded in o_data_q
    // 1st cycle: weighted average of 9 pixels calculated
    // 2nd cycle: sum of the 9 weighted average loaded to o_data_q
    //wire [$clog2(OUT_CHANNELS_PER_CYCLE):0] out_idx;
    logic signed [VALUE_BITS-1:0]       next_o_data[OUT_CHANNELS_PER_CYCLE];
    logic signed [VALUE_BITS*2-1:0]     mult_out[OUT_CHANNELS_PER_CYCLE][KERNAL_SIZE*KERNAL_SIZE];

    always_ff@(posedge clk) begin
        // sum into o_data_q
        for (integer out_idx = 0; out_idx < OUT_CHANNELS_PER_CYCLE; out_idx++) begin
            if(counter+out_idx < OUTPUT_CHANNELS && !o_valid_q) begin
                o_data_q[counter+out_idx] <= next_o_data[out_idx];  
            end     
        end
    end

    always_comb begin
        for (integer out_idx = 0; out_idx < OUT_CHANNELS_PER_CYCLE; out_idx++) begin
            // multiply into intermediate register for timing
            for (int row = 0; row < KERNAL_SIZE; row++) begin
                for (int col = 0; col < KERNAL_SIZE; col++) begin
                    mult_out[out_idx][row*KERNAL_SIZE + col] = i_weights[counter+out_idx][row][col] * taps_q[row][col];
                end
            end  

            next_o_data[out_idx] = '0;
            for(int idx = 0; idx < (KERNAL_SIZE*KERNAL_SIZE); idx++) begin
                next_o_data[out_idx] += mult_out[out_idx][idx][VALUE_Q_FORMAT_N+:VALUE_BITS];
            end
        end
    end

endmodule

// Core data organizational structure for my CNN implementation
// FMax: Module can run at 420-430 MHz
// INPUTS: Stream in pixels one at a time in row-major order serially
// OUTPUTS: A paralell rectangular output slice, called a tap, which marches across the image in row-major order (to be fed to kernal)
// IMPLEMENTATION: Implemented as TAP_HEIGHT independant rams with SIMD reading and individual-control writing
//        One row (which rotates around) is used as writing scratchpad, while all rows are simultaniously read
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
            // Declare dual-port ram with SIMD controls 
            dual_port_ram #(.VALUE_BITS(VALUE_BITS), .WIDTH(WIDTH)) line_ram(
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
        next_taps_last = taps_last_q;
        i_ready = (!input_done_row_q && o_ready && !taps_last_q); // ready to receive input when input is not done with its row, and downstream is accepting data, and we are not waiting for last tap to be consumed

        // Input and output march in lockstep so both must be ready to march
        // Input must be valid, or we are done with the input row
        // Output must be ready to accept 
        // Don't do anything if last tap is on display
        if ((i_valid || input_done_row_q) && o_ready) begin
            
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

        // Passing next last asynchronously
        if (i_last && i_ready) begin
            next_taps_last = 1;
        end

        // if advertising last tap available then have o_valid high
        //if(taps_last_q) o_valid = 1;
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

// A dual-port ram with word-size of VALUE_BITS, and WIDTH elements
module dual_port_ram #(
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