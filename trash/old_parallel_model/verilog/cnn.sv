module max_pooling_layer #(parameter KERNAL_SIZE, NUM_KERNALS, WIDTH, VALUE_BITS, CHANNELS, TAG_WIDTH) (
    // General signals
    input clock_i, input reset_i,
    // next row logic
    input logic [VALUE_BITS - 1 : 0] in_row_i[WIDTH][CHANNELS], 
    input logic in_row_valid_i, 
    output logic in_row_accept_o, // must be high before in_row_i moves to next value
    input logic in_row_last_i,  // if raised we are done
    input logic [TAG_WIDTH-1:0] in_row_tag_i,
    // output row valid 
    output logic [VALUE_BITS - 1 : 0] out_row_o[WIDTH/KERNAL_SIZE][CHANNELS],
    output logic out_row_valid_o,
    output logic out_row_last_o,
    output logic [TAG_WIDTH-1:0] out_row_tag_o,
    input logic out_row_accept_i
);
    // The state transitions for this layer
    typedef enum {
        S_GET_NEXT_ROW, 
        S_CALC_ROW, 
        S_WAIT_ROW_READ
    } e_state;

    localparam OUT_WIDTH = WIDTH/KERNAL_SIZE;

    // Buffer with output row
    logic [VALUE_BITS - 1 : 0] in_row_q[WIDTH][CHANNELS];
    logic [VALUE_BITS - 1 : 0] out_row_q[OUT_WIDTH][CHANNELS];
    logic [ $clog2(OUT_WIDTH)-1 : 0 ] pos_idx_q; // in output, not in input
    logic [ $clog2(KERNAL_SIZE) - 1 : 0 ] offset_idx_q;
    logic [ $clog2(KERNAL_SIZE) : 0 ] row_count_q;
    e_state state_q; 
    logic in_row_last_q;

    // Output logic
    assign out_row_o = out_row_q;
    assign out_row_last_o = in_row_last_q; //qualified by out_valid so can just set this here now

    // Combinational signals
    logic latch_in_row;
    logic reset_output_row;
    logic [VALUE_BITS - 1 : 0] next_out_row[OUT_WIDTH][CHANNELS];
    logic [ $clog2(OUT_WIDTH)-1 : 0 ] next_pos_idx;
    logic [ $clog2(KERNAL_SIZE) - 1 : 0 ] next_offset_idx;
    logic [ $clog2(KERNAL_SIZE) : 0 ] next_row_count;
    e_state next_state;

    // Temp signals to use as local vriables inside of always_comb but who have no meaningful output value
    logic [ $clog2(WIDTH)-1 : 0 ] tmp_input_idx;
    logic [ $clog2(OUT_WIDTH) : 0] tmp_out_idx;

    always_comb begin
        // Default values
        latch_in_row = 0;
        reset_output_row = 0;
        in_row_accept_o = 0;
        out_row_valid_o = 0;
        
        next_out_row = out_row_q;
        next_pos_idx = pos_idx_q;
        next_state = state_q;
        next_row_count = row_count_q;
        next_offset_idx = offset_idx_q;
        // FSM logic
        case (state_q)
        S_GET_NEXT_ROW: begin
            if (in_row_valid_i) begin
                latch_in_row = 1;
                in_row_accept_o = 1;
                next_pos_idx = 0;
                next_state = S_CALC_ROW;
            end
        end
        S_CALC_ROW: begin
            // Increment offset unless that goes out of bounds
            // In which case increment the output pixel we are computing and reset offset
            if (offset_idx_q == (KERNAL_SIZE-1)) begin
                next_pos_idx = pos_idx_q + 1;
                next_offset_idx = 0;
            end else begin
                next_offset_idx = offset_idx_q + 1;
            end
            
            // Actual computing of kernal
            for (int kernal_num = 0; kernal_num < NUM_KERNALS; kernal_num++) begin
                // Each kernal computes one instance of kernal_width 
                // Compute location in input and make sure no roundoff errors (it must be in bounds)
                tmp_input_idx = pos_idx_q*KERNAL_SIZE + kernal_num*WIDTH/NUM_KERNALS + offset_idx_q;
                if (tmp_input_idx < WIDTH) begin
                    // For all channels we do this operation
                    for (int ch_num = 0; ch_num < CHANNELS; ch_num++) begin
                        // Update value we will write if it is greater than current values for row
                        // TODO -- Need to use twos-compliment signed version of compare instead of unsigned
                        // Actually probably need to check that I do that everywhere, everything is unsigned rn
                        tmp_out_idx = pos_idx_q + kernal_num*OUT_WIDTH/NUM_KERNALS;
                        if (next_out_row[ tmp_out_idx ][ch_num] < in_row_q[ tmp_input_idx ][ch_num] ) begin
                            next_out_row[ tmp_out_idx ][ch_num] = in_row_q[ tmp_input_idx ][ch_num];
                        end
                    end
                end
            end
            // Check if overflow, that is, if position we get for first kernal is within second kernals range of pixels
            if ( pos_idx_q*KERNAL_SIZE  >= WIDTH/NUM_KERNALS) begin
                next_row_count = row_count_q + 1;
                // If we have done the y-dimension component of the max-pool, or this is last row
                if (next_row_count == KERNAL_SIZE || in_row_last_q) begin
                    next_state = S_WAIT_ROW_READ;
                end else begin
                    next_state = S_GET_NEXT_ROW;
                end
            end

        end
        S_WAIT_ROW_READ: begin
            // When in this state the output row is valid
            out_row_valid_o = 1;
            if (out_row_accept_i) begin
                next_state = S_GET_NEXT_ROW;
                reset_output_row = 1;
                next_row_count = 0;
            end
        end
        endcase
        tmp_input_idx = 0 ; //don't actually store a value here when exiting the always block
        tmp_out_idx = 0;
    end


    always_ff@(posedge clock_i) begin
        if (reset_i) begin
            state_q <= S_GET_NEXT_ROW;
            pos_idx_q <= 0;
            in_row_last_q <= 0;
            row_count_q <= 0;
            offset_idx_q <= 0;
        end else begin
            if (latch_in_row) begin
                in_row_q <= in_row_i;
                in_row_last_q <= in_row_last_i;
                out_row_tag_o <= in_row_tag_i;
            end
            offset_idx_q <= next_offset_idx;
            row_count_q <= next_row_count;
            out_row_q <= next_out_row;
            pos_idx_q <= next_pos_idx;
            state_q <= next_state;
        end
        
        // Logic to reset all the output latched values to 0 when we get the signal to
        if (reset_i || reset_output_row) begin
            for (int x = 0; x < OUT_WIDTH; x++) begin
                for (int ch_num = 0; ch_num < CHANNELS; ch_num++) begin
                    out_row_q[x][ch_num] <= 0;
                end
            end
        end
    end


endmodule 



module cnn_layer #(
    parameter KERNAL_SIZE, NUM_KERNALS, WIDTH, VALUE_BITS, WEIGHT_BITS, WEIGHT_Q_SHIFT, IN_CHANNELS, OUT_CHANNELS, TAG_WIDTH,
    // DO NOT CHANGE BELOW VALUES
    OUT_WIDTH = WIDTH - KERNAL_SIZE + 1
    ) (
    // General signals
    input clock_i, input reset_i,
    // Constant but dynamic layer config
    input logic [ WEIGHT_BITS-1 : 0 ] kernal_weights_i[OUT_CHANNELS][IN_CHANNELS][KERNAL_SIZE][KERNAL_SIZE],
    // next row logic
    input logic [VALUE_BITS - 1 : 0] in_row_i[WIDTH][IN_CHANNELS], 
    input logic in_row_valid_i, 
    output logic in_row_accept_o, // must be high before in_row_i moves to next value
    input logic in_row_last_i,  // if raised we are done
    input logic [TAG_WIDTH-1:0] in_row_tag_i,
    // output row valid 
    output logic [VALUE_BITS -1 : 0] out_row_o[OUT_WIDTH][OUT_CHANNELS],
    output logic out_row_valid_o,
    output logic out_row_last_o,
    output logic [TAG_WIDTH-1:0] out_row_tag_o,
    input logic out_row_accept_i
);

    // BUFFER CONTROL FSM
    typedef enum {
        S_GET_NEXT_ROW, 
        S_KERNAL_COMPUTE, 
        S_WAIT_ROW_READ
    } e_state;

    // CNN PERSISTANT STATE
    e_state state_q; // for what mode we are in
    logic [7 : 0] row_idx_q; // pointer to the next index we load a row into
    logic [ $clog2(WIDTH)-1 : 0] col_idx_q; // represents an offset of the kernal over the input image 
    logic [VALUE_BITS -1 : 0] out_row_q[OUT_WIDTH][OUT_CHANNELS];
    logic out_row_valid_q;
    logic out_row_last_q;
    logic [ $clog2(OUT_CHANNELS)-1 : 0 ] out_ch_idx_q; 
    logic [TAG_WIDTH-1:0] out_row_tag_q;

    // OUTPUT SIGNALS -- For simple output ports that are based on persistant state
    assign out_row_o = out_row_q;
    assign out_row_valid_o = out_row_valid_q;
    assign out_row_last_o = out_row_last_q;
    assign out_row_tag_o = out_row_tag_q;

    // COMBINATIONAL SIGNALS -- buffer signals, combinational
    e_state next_state;
    logic [7 : 0] next_row_idx;
    logic [ $clog2(WIDTH)-1 : 0] next_col_idx;
    logic [VALUE_BITS -1 : 0] next_out_row[OUT_WIDTH][OUT_CHANNELS];
    logic next_out_row_valid;
    logic next_out_row_last;
    logic [ $clog2(OUT_CHANNELS)-1 : 0 ] next_out_ch_idx; 
    logic [TAG_WIDTH-1:0] next_out_tag; 
    logic [ 7 : 0 ] tmp_idx;

    // BUFFER LOGIC -- Recieves rows shifted in vertically, and can also horizontally shift the "output taps" which is what the kernal will read
    
    logic buffer_shift_horiz, buffer_shift_vert;
    logic [ VALUE_BITS-1 : 0 ] buffer_taps[NUM_KERNALS][IN_CHANNELS][KERNAL_SIZE][KERNAL_SIZE];

    shift_buffer_array #(.WIDTH(WIDTH), .HEIGHT(KERNAL_SIZE), .TAP_WIDTH(KERNAL_SIZE), .NUM_TAPS(NUM_KERNALS), .VALUE_BITS(VALUE_BITS), .NUM_CHANNELS(IN_CHANNELS)) buffer(
        .clock_i(clock_i), .reset_i(reset_i), 
        .next_row_i(in_row_i),
        .shift_horiz_i(buffer_shift_horiz), .shift_vert_i(buffer_shift_vert), 
        .taps_o(buffer_taps)
    );

    // KERNAL LOGIC

    logic [ VALUE_BITS-1 : 0 ] kernal_arr_output [NUM_KERNALS]; // Output for each instance of the kernal stamped

    // instance of an array of kernals, each computing one output channel per cycle stamped at various locations
    kernal_array #(
        .KERNAL_SIZE(KERNAL_SIZE), .NUM_KERNALS(NUM_KERNALS),
        .WEIGHT_BITS(WEIGHT_BITS), .WEIGHT_Q_SHIFT(WEIGHT_Q_SHIFT),
        .VALUE_BITS(VALUE_BITS),
        .IN_CHANNELS(IN_CHANNELS)
    ) kernals(
        .clock_i(clock_i), .reset_i(reset_i), 
        .kernal_weights_i(kernal_weights_i[out_ch_idx_q]), .image_values_i(buffer_taps), 
        .output_values_o(kernal_arr_output)
    );

    // Buffer combinational FSM logic
    always_comb begin
        next_state = state_q;
        next_row_idx = row_idx_q;
        next_col_idx = col_idx_q;
        next_out_row = out_row_q;
        next_out_tag = out_row_tag_o;
        next_out_row_valid = out_row_valid_q;
        next_out_row_last = out_row_last_q;
        next_out_ch_idx = out_ch_idx_q;
        buffer_shift_horiz = 0;
        buffer_shift_vert = 0;
        in_row_accept_o = 0;

        case (state_q) 
        S_GET_NEXT_ROW: begin
            if (in_row_valid_i) begin
                // Get the next row
                buffer_shift_vert = 1;
                next_row_idx = row_idx_q + 1;
                in_row_accept_o = 1;
                //if this is the last row so after we are starting next image
                next_out_row_last = in_row_last_i;
                next_out_tag = in_row_tag_i;
                // Change state to be calculating over that row
                if (row_idx_q >= KERNAL_SIZE-1) begin
                    next_state = S_KERNAL_COMPUTE;
                    next_out_ch_idx = 0; //for kernal computatins
                    next_col_idx = 0;
                end
            end
        end
        S_KERNAL_COMPUTE: begin
            // Latch the output of the current output_channel / current pixel
            for (int kernal_num = 0; kernal_num < NUM_KERNALS; kernal_num++) begin
                tmp_idx = (kernal_num*WIDTH/NUM_KERNALS) +  col_idx_q;
                 // Bounds check before writing to output (for fringing effects around the edges)
                 // Since we must do WIDTH rotations but have OUT_WIDTH output ports, the last KERNAL_SIZE-1 outputs
                 // are invalid but must be marched over anyways to restore buffer for vertical shift
                 // so we just ignore their outputs and not latch them (the kernal is over the image boundry here)
                if (tmp_idx < OUT_WIDTH) begin
                    next_out_row[ tmp_idx ][out_ch_idx_q] = kernal_arr_output[kernal_num];
                end
            end
            // Move onto computing next output channel
            next_out_ch_idx = out_ch_idx_q + 1;

            // If this was the last value in this channel than we must move to the next pixel and reset channel
            if (out_ch_idx_q == OUT_CHANNELS-1) begin
                // Channel is back to channel 0
                next_out_ch_idx = 0;
                // Shift so that we get next pixel
                buffer_shift_horiz = 1;
                // Increment column to record that we are on next pixel
                next_col_idx = col_idx_q + 1;                
                // If this was the last pixel than we must go and read the next row
                if (next_col_idx*NUM_KERNALS >= WIDTH) begin
                    // Mark the output row as valid and wait for it to be read before we can proceed
                    next_state = S_WAIT_ROW_READ;
                    next_out_row_valid = 1;
                    // If this was the last row, reset row index (i.e no valid rows in buffer)
                    if (out_row_last_o) begin
                        next_row_idx = 0;
                    end
                end
            end
        end
        // Wait for our computed result to be read 
        S_WAIT_ROW_READ: begin
            // If the next stage accepts our result
            if (out_row_accept_i) begin
                // Transition to reading in the next row, mark output as no longer valid
                next_state = S_GET_NEXT_ROW;
                next_out_row_valid = 0;
                next_out_row_last = 0;
            end
        end
        endcase
        // Don't actually infer a signal for this
        tmp_idx = 0;
    end

    // Buffer sequential logic
    always_ff@(posedge clock_i) begin
        if (reset_i) begin
            state_q <= S_GET_NEXT_ROW;
            row_idx_q <= 0;
            col_idx_q <= 0;
            out_row_valid_q <= 0;
            out_row_last_q <= 0;
            out_ch_idx_q <= 0;
            out_row_tag_q <= 0;
        end else begin
            state_q <= next_state;
            row_idx_q <= next_row_idx;
            col_idx_q <= next_col_idx;
            out_row_q <= next_out_row;
            out_row_valid_q <= next_out_row_valid;
            out_row_last_q <= next_out_row_last;
            out_ch_idx_q <= next_out_ch_idx;
            out_row_tag_q <= next_out_tag;
        end
    end

endmodule 

module shift_buffer_array #(parameter WIDTH, HEIGHT, TAP_WIDTH, NUM_TAPS, VALUE_BITS, NUM_CHANNELS) 
(
    input clock_i, input reset_i,
    // next row logic
    input logic [VALUE_BITS - 1 : 0] next_row_i[WIDTH][NUM_CHANNELS], 
    // controls
    input logic shift_horiz_i, // shift over left
    input logic shift_vert_i, // shift entire row up
    // outputs
    output logic [VALUE_BITS - 1 : 0] taps_o[NUM_TAPS][NUM_CHANNELS][TAP_WIDTH][HEIGHT]
);
    // Note vertically it is a rotating buffer in order to avoid having to shift all the rows each time we write a new row in
    // Each write is done to buffer_row_head_idx_q and we interpret the sliding window by unrotating with muxing before outputting result
    logic [VALUE_BITS - 1 : 0] buffer_q[HEIGHT][WIDTH][NUM_CHANNELS];

    // Output taps
    always_comb begin
        for (int num_tap = 0; num_tap < NUM_TAPS; num_tap++) begin
            for (int ch_num = 0; ch_num < NUM_CHANNELS; ch_num++) begin
                for (int tap_width = 0; tap_width < TAP_WIDTH; tap_width++) begin
                    for (int tap_height = 0; tap_height < HEIGHT; tap_height++) begin
                        // Perform the tap
                        taps_o[ num_tap ][ ch_num ][ tap_width ][ tap_height ] = 
                            buffer_q[ tap_height ][ num_tap*WIDTH/NUM_TAPS + tap_width ][ ch_num ];
                    end
                end
            end
        end
    end

    // State update to the buffer
    always_ff@(posedge clock_i) begin
        // Perform a row-shift with our new row at the top and the old row shifted out
        // This represents the vertical slice of the imace that our kernal is marching over right now
        if (shift_vert_i) begin
            for (int row = 0; row < HEIGHT-1; row++)  begin
                buffer_q[row] <= buffer_q[row+1];
            end
            buffer_q[HEIGHT-1] <= next_row_i;
        // This represents a rotation horizontally of the data within each row. 
        // We do that to simulate the kernal marching horizontally over the image
        // At the end of WIDTH rotations we are back where we started and can do vertical shift
        end else if (shift_horiz_i) begin
            for (int row = 0; row < HEIGHT; row++) begin
                for (int col = 0; col < WIDTH-1; col++) begin
                    buffer_q[row][col] <= buffer_q[row][col+1];
                end
                buffer_q[row][WIDTH-1] <= buffer_q[row][0];
            end
        end
    end
endmodule 


// Takes input image of size KERNAL_SIZE*KERNAL_SIZE*NUM_CHANNELS and produces identical output
// Kernal weights and image values are in fixed-point format 
module kernal_array #(parameter KERNAL_SIZE, NUM_KERNALS,
    WEIGHT_BITS, WEIGHT_Q_SHIFT,
    VALUE_BITS, IN_CHANNELS
) (
    input clock_i, 
    input reset_i,
    // The weights for the kernal
    input logic  [ WEIGHT_BITS-1: 0 ] kernal_weights_i[IN_CHANNELS][KERNAL_SIZE][KERNAL_SIZE],
    // The image values for each of the stamped kernals
    input logic  [ VALUE_BITS-1 : 0 ] image_values_i  [NUM_KERNALS][IN_CHANNELS] [KERNAL_SIZE][KERNAL_SIZE],
    // The output values for each of the stamped kernals, comes on the clock-edge after inputs provided
    output logic [ VALUE_BITS-1 : 0 ] output_values_o  [NUM_KERNALS]
);
    // TODO pipeline this and add out_valid signal instead of just combinational logic
    always_comb begin
        for (int kernal_num = 0; kernal_num < NUM_KERNALS; kernal_num++) begin
            // We are assigning output_values_o[kernal][channel] here
            output_values_o[kernal_num] = 0;
            // Take dot product of kernal_weights[out_channel] with image_values_i[kernal_num]
            for (int in_ch = 0; in_ch < IN_CHANNELS; in_ch++) begin
                for (int x = 0; x < KERNAL_SIZE; x++) begin
                    for (int y = 0; y < KERNAL_SIZE; y++) begin
                        // Do fixed-point multiplication of the two scalar values
                        output_values_o[kernal_num] += 
                            (kernal_weights_i[in_ch][x][y] 
                            * image_values_i[kernal_num][in_ch][x][y])
                            >> WEIGHT_Q_SHIFT;
                    end
                end
            end
        end
    end
endmodule 
