

// Input is streamed where we recieve an image as 28*28 individual transfers with the grayscale values
module cnn_top #(parameter 
    VALUES_PER_WORD = 1,
    VALUE_BITS = 8
)(
    input logic clock, 
    input logic reset, //+ve synchronous reset

    input logic [ 31 : 0 ] in_data,
    input logic in_valid,

    output logic [ 31 : 0 ] out_data,
    output logic out_valid, 

    input logic downstream_stall,
    output logic upstream_stall
);    
    parameter WEIGHT_BITS=8;
    parameter WEIGHT_Q_SHIFT=6;

    // CNN LAYER 0

    parameter LAYER0_KERNAL_SIZE=2;
    parameter LAYER0_WIDTH=28;
    parameter LAYER0_IN_CHANNELS=1;
    parameter LAYER0_OUT_CHANNELS=1;
    parameter LAYER0_NUM_KERNALS=1;

    logic  [ WEIGHT_BITS-1 : 0 ] layer0_kernal_weights_i[LAYER0_OUT_CHANNELS][LAYER0_IN_CHANNELS][LAYER0_KERNAL_SIZE][LAYER0_KERNAL_SIZE];

    logic [VALUE_BITS-1 : 0] layer0_in_row_i[LAYER0_WIDTH][LAYER0_IN_CHANNELS];
    logic layer0_in_row_valid_i, layer0_in_row_accept_o, layer0_in_row_last_i;
    
    logic [VALUE_BITS -1 : 0] layer0_out_row_o[LAYER0_WIDTH][LAYER0_OUT_CHANNELS];
    logic layer0_out_row_valid_o;
    logic layer0_out_row_accept_i;
    logic layer0_out_row_last_o;
    
    cnn_layer #(
        .KERNAL_SIZE(LAYER0_KERNAL_SIZE), .NUM_KERNALS(LAYER0_NUM_KERNALS), 
        .WIDTH(LAYER0_WIDTH), .VALUE_BITS(VALUE_BITS), .WEIGHT_BITS(WEIGHT_BITS), .WEIGHT_Q_SHIFT(WEIGHT_Q_SHIFT), 
        .IN_CHANNELS(LAYER0_IN_CHANNELS), .OUT_CHANNELS(LAYER0_OUT_CHANNELS)
    ) layer0(
        // General
        .clock_i(clock), .reset_i(reset),
        .kernal_weights_i(layer0_kernal_weights_i),
        // INPUT INFO
        .in_row_i(layer0_in_row_i),
        .in_row_valid_i(layer0_in_row_valid_i),
        .in_row_accept_o(layer0_in_row_accept_o),
        .in_row_last_i(layer0_in_row_last_i),
        // OUT INFO
        .out_row_o(layer0_out_row_o),
        .out_row_valid_o(layer0_out_row_valid_o),
        .out_row_accept_i(layer0_out_row_accept_i),
        .out_row_last_o(layer0_out_row_last_o)
    );

    // INPUT -> LAYER0 GLUE LOGIC
    logic [VALUE_BITS-1 : 0] in_row_par[LAYER0_WIDTH*LAYER0_IN_CHANNELS];

    parallelize #(.N(LAYER0_WIDTH*LAYER0_IN_CHANNELS), .DATA_BITS(VALUE_BITS), .DATA_PER_WORD(VALUES_PER_WORD)) par2ser(
        .clock(clock), .reset(reset), 
        .in_data(in_data), .in_valid(in_valid), 
        .out_data(in_row_par), .out_valid(layer0_in_row_valid_i),
        .downstream_stall(!layer0_in_row_accept_o), .upstream_stall(upstream_stall)
    );
    
    always_comb begin
        layer0_in_row_last_i = 0;
        for (int x = 0; x < LAYER0_WIDTH; x++) begin
            for (int in_ch = 0; in_ch < LAYER0_IN_CHANNELS; in_ch++) begin
                layer0_in_row_i[x][in_ch] = in_row_par[x + in_ch*LAYER0_WIDTH];
            end
        end
    end

    // POOLING LAYER 0

    parameter POOL0_KERNAL_SIZE=2;
    parameter POOL0_NUM_KERNALS=1;
    parameter POOL0_WIDTH=LAYER0_WIDTH;
    parameter POOL0_CHANNELS=LAYER0_OUT_CHANNELS;
    parameter POOL0_OUT_WIDTH = POOL0_WIDTH / POOL0_KERNAL_SIZE;

    logic [VALUE_BITS - 1 : 0] pool0_in_row_i[POOL0_WIDTH][POOL0_CHANNELS];
    logic pool0_in_row_valid_i, pool0_in_row_accept_o, pool0_in_row_last_i;
    
    logic [VALUE_BITS - 1 : 0] pool0_out_row_o[POOL0_OUT_WIDTH][POOL0_CHANNELS];
    logic pool0_out_row_valid_o;
    logic pool0_out_row_accept_i;
    logic pool0_out_row_last_o;

    max_pooling_layer #(
        .KERNAL_SIZE(POOL0_KERNAL_SIZE), .NUM_KERNALS(POOL0_NUM_KERNALS), 
        .WIDTH(POOL0_WIDTH), .VALUE_BITS(VALUE_BITS), .CHANNELS(POOL0_CHANNELS)
    ) pool0 (
        // General
        .clock_i(clock), .reset_i(reset),
        // INPUT INFO
        .in_row_i(pool0_in_row_i),
        .in_row_valid_i(pool0_in_row_valid_i),
        .in_row_accept_o(pool0_in_row_accept_o),
        .in_row_last_i(pool0_in_row_last_i),
        // OUT INFO
        .out_row_o(pool0_out_row_o),
        .out_row_valid_o(pool0_out_row_valid_o),
        .out_row_accept_i(pool0_out_row_accept_i),
        .out_row_last_o(pool0_out_row_last_o)
    );

    // LAYER0 -> POOL0 GLUE LOGIC
    assign pool0_in_row_i = layer0_out_row_o;
    assign pool0_in_row_valid_i = layer0_out_row_valid_o;
    assign layer0_out_row_accept_i = pool0_in_row_accept_o;
    assign pool0_in_row_last_i = layer0_out_row_last_o;

    // POOL0 -> OUT glue logic


    logic [VALUE_BITS-1 : 0] out_row_par[POOL0_OUT_WIDTH*POOL0_CHANNELS];
    serialize #(.N(POOL0_OUT_WIDTH*POOL0_CHANNELS), .DATA_BITS(VALUE_BITS), .DATA_PER_WORD(VALUES_PER_WORD)) ser2par(
        .clock(clock), .reset(reset), 
        .in_data(out_row_par), .in_valid(pool0_out_row_valid_o),
        .out_data(out_data), .out_valid(out_valid),
        .downstream_stall(downstream_stall), .upstream_stall(pool0_out_row_accept_i)
    );
    always_comb begin
        for (int x = 0; x < POOL0_OUT_WIDTH; x++) begin
            for (int out_ch = 0; out_ch < POOL0_CHANNELS; out_ch++) begin
                out_row_par[x + out_ch*POOL0_OUT_WIDTH] = pool0_out_row_o[x][out_ch];
            end
        end
    end

    // NEURAL NETWORK WEIGHTS DEFINITION - ALL LAYERS

    always_comb begin
        // LAYER 0 WEIGHTS
        for (int out_ch = 0; out_ch < LAYER0_OUT_CHANNELS; out_ch++) begin
            for (int in_ch = 0; in_ch < LAYER0_IN_CHANNELS; in_ch++) begin
                for (int x = 0; x < LAYER0_KERNAL_SIZE; x++) begin
                    for (int y = 0; y < LAYER0_KERNAL_SIZE; y++) begin
                        layer0_kernal_weights_i[out_ch][in_ch][x][y] 
                        = (1<<WEIGHT_Q_SHIFT)
                            / (LAYER0_OUT_CHANNELS*LAYER0_IN_CHANNELS*LAYER0_KERNAL_SIZE*LAYER0_KERNAL_SIZE);
                    end
                end
            end
        end
    end

endmodule 


module max_pooling_layer #(parameter KERNAL_SIZE, NUM_KERNALS, WIDTH, VALUE_BITS, CHANNELS) (
    // General signals
    input clock_i, input reset_i,
    // next row logic
    input logic [VALUE_BITS - 1 : 0] in_row_i[WIDTH][CHANNELS], 
    input logic in_row_valid_i, 
    output logic in_row_accept_o, // must be high before in_row_i moves to next value
    input logic in_row_last_i,  // if raised we are done
    // output row valid 
    output logic [VALUE_BITS - 1 : 0] out_row_o[WIDTH/KERNAL_SIZE][CHANNELS],
    output logic out_row_valid_o,
    output logic out_row_last_o,
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
    logic [ $clog2(KERNAL_SIZE) : 0 ] next_row_count;
    e_state next_state;

    // Temp signals to use as local vriables inside of always_comb but who have no meaningful output value
    logic [ $clog2(WIDTH)-1 : 0 ] tmp_input_idx;

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
            next_pos_idx = pos_idx_q + 1;
            // Actual computing of kernal
            for (int kernal_num = 0; kernal_num < NUM_KERNALS; kernal_num++) begin
                // Each kernal computes one instance of kernal_width 
                for (int offset = 0; offset < KERNAL_SIZE; offset++) begin
                    // Compute location in input and make sure no roundoff errors (it must be in bounds)
                    tmp_input_idx = pos_idx_q*KERNAL_SIZE + kernal_num*NUM_KERNALS/WIDTH + offset;
                    if (tmp_input_idx < WIDTH) begin
                        // For all channels we do this operation
                        for (int ch_num = 0; ch_num < CHANNELS; ch_num++) begin
                            // Update value we will write if it is greater than current values for row
                            // TODO -- Need to use twos-compliment signed version of compare instead of unsigned
                            // Actually probably need to check that I do that everywhere, everything is unsigned rn
                            if (next_out_row[ pos_idx_q ][ch_num] < in_row_q[ tmp_input_idx ][ch_num] ) begin
                                next_out_row[ pos_idx_q ][ch_num] = in_row_q[ tmp_input_idx ][ch_num];
                            end
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
    end


    always_ff@(posedge clock_i) begin
        if (reset_i) begin
            state_q <= S_GET_NEXT_ROW;
            pos_idx_q <= 0;
            in_row_last_q <= 0;
            row_count_q <= 0;
        end else begin
            if (latch_in_row) begin
                in_row_q <= in_row_i;
                in_row_last_q <= in_row_last_i;
            end
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



module cnn_layer #(parameter KERNAL_SIZE, NUM_KERNALS, WIDTH, VALUE_BITS, WEIGHT_BITS, WEIGHT_Q_SHIFT, IN_CHANNELS, OUT_CHANNELS) (
    // General signals
    input clock_i, input reset_i,
    // Constant but dynamic layer config
    input logic [ WEIGHT_BITS-1 : 0 ] kernal_weights_i[OUT_CHANNELS][IN_CHANNELS][KERNAL_SIZE][KERNAL_SIZE],
    // next row logic
    input logic [VALUE_BITS - 1 : 0] in_row_i[WIDTH][IN_CHANNELS], 
    input logic in_row_valid_i, 
    output logic in_row_accept_o, // must be high before in_row_i moves to next value
    input logic in_row_last_i,  // if raised we are done
    // output row valid 
    output logic [VALUE_BITS -1 : 0] out_row_o[WIDTH][OUT_CHANNELS],
    output logic out_row_valid_o,
    output logic out_row_last_o,
    input logic out_row_accept_i
);

    // BUFFER LOGIC
    
    logic buffer_shift_horiz, buffer_shift_vert;
    logic [ VALUE_BITS-1 : 0 ] buffer_taps[NUM_KERNALS][IN_CHANNELS][KERNAL_SIZE][KERNAL_SIZE];

    shift_buffer_array #(.WIDTH(WIDTH), .HEIGHT(KERNAL_SIZE), .TAP_WIDTH(KERNAL_SIZE), .NUM_TAPS(NUM_KERNALS), .VALUE_BITS(VALUE_BITS), .NUM_CHANNELS(IN_CHANNELS)) buffer(
        .clock_i(clock_i), .reset_i(reset_i), 
        .next_row_i(in_row_i),
        .shift_horiz_i(buffer_shift_horiz), .shift_vert_i(buffer_shift_vert), 
        .taps_o(buffer_taps)
    );

    // KERNAL LOGIC
    logic [ VALUE_BITS-1 : 0 ] kernal_arr_output [NUM_KERNALS][OUT_CHANNELS];

    kernal_array #(
        .KERNAL_SIZE(KERNAL_SIZE), .NUM_KERNALS(NUM_KERNALS),
        .WEIGHT_BITS(WEIGHT_BITS), .WEIGHT_Q_SHIFT(WEIGHT_Q_SHIFT),
        .VALUE_BITS(VALUE_BITS),
        .IN_CHANNELS(IN_CHANNELS), .OUT_CHANNELS(OUT_CHANNELS)
    ) kernals(
        .clock_i(clock_i), .reset_i(reset_i), 
        .kernal_weights_i(kernal_weights_i), .image_values_i(buffer_taps), 
        .output_values_o(kernal_arr_output)
    );

    // BUFFER CONTROL FSM
    typedef enum {
        S_GET_NEXT_ROW, 
        S_CALC_ROW_WAIT, 
        S_CALC_ROW, 
        S_WAIT_ROW_READ
    } e_state;

    // buffer registers
    e_state state_q; // for what mode we are in
    logic [7 : 0] row_idx_q; // what row number is the next row we shift in
    logic [7 : 0] col_idx_q; // what column is at zero (aka, how many times have we shifted
    logic [VALUE_BITS -1 : 0] out_row_q[WIDTH][OUT_CHANNELS];
    logic out_row_valid_q;
    logic out_row_last_q;

    // For simple output ports
    assign out_row_o = out_row_q;
    assign out_row_valid_o = out_row_valid_q;
    assign out_row_last_o = out_row_last_q;

    // buffer signals
    e_state next_state;
    logic [7 : 0] next_row_idx;
    logic [7 : 0] next_col_idx;
    logic [VALUE_BITS -1 : 0] next_out_row[WIDTH][OUT_CHANNELS];
    logic next_out_row_valid;
    logic next_out_row_last;

    // Buffer combinational FSM logic
    always_comb begin
        next_state = state_q;
        next_row_idx = row_idx_q;
        next_col_idx = col_idx_q;
        next_out_row = out_row_q;
        next_out_row_valid = out_row_valid_q;
        next_out_row_last = out_row_last_q;
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
                // Change state to be calculating over that row
                if (next_row_idx >= KERNAL_SIZE) begin
                    next_state = S_CALC_ROW_WAIT;
                    next_col_idx = 0;
                end
            end
        end
        S_CALC_ROW_WAIT: begin
            // We need to wait one cycle for kernal output to update
            next_state = S_CALC_ROW;
        end
        S_CALC_ROW: begin
            // TODO assuming can produce an output of the kernal each itteration; probably gonna have to stall here
            buffer_shift_horiz = 1;
            next_col_idx = col_idx_q + 1;
            next_state = S_CALC_ROW_WAIT; // wait for kernal output to reflect this change
            
            for (int kernal_num = 0; kernal_num < NUM_KERNALS; kernal_num++) begin
                next_out_row[ (kernal_num*WIDTH/NUM_KERNALS) +  col_idx_q ] = kernal_arr_output[kernal_num];
            end

            if (next_col_idx*NUM_KERNALS >= WIDTH) begin
                next_state = S_WAIT_ROW_READ;
                next_out_row_valid = 1;
                //if this is the last row so after we are starting next image
                if (in_row_last_i) begin
                    next_row_idx = 0; 
                    next_out_row_last = 1;
                end
            end
        end
        S_WAIT_ROW_READ: begin
            if (out_row_accept_i) begin
                next_state = S_GET_NEXT_ROW;
                next_out_row_valid = 0;
                next_out_row_last = 0;
            end
        end
        endcase
    end

    // Buffer sequential logic
    always_ff@(posedge clock_i) begin
        if (reset_i) begin
            state_q <= S_GET_NEXT_ROW;
            row_idx_q <= 0;
            col_idx_q <= 0;
            out_row_valid_q <= 0;
            out_row_last_q <= 0;
        end else begin
            state_q <= next_state;
            row_idx_q <= next_row_idx;
            col_idx_q <= next_col_idx;
            out_row_q <= next_out_row;
            out_row_valid_q <= next_out_row_valid;
            out_row_last_q <= next_out_row_last;
        end
    end

    //TODO to make sure does not get optimized away

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

    logic [VALUE_BITS - 1 : 0] buffer[HEIGHT][WIDTH][NUM_CHANNELS];

    // Output taps
    always_comb begin
        for (int num_tap = 0; num_tap < NUM_TAPS; num_tap++) begin
            for (int ch_num = 0; ch_num < NUM_CHANNELS; ch_num++) begin
                for (int tap_width = 0; tap_width < TAP_WIDTH; tap_width++) begin
                    for (int tap_height = 0; tap_height < HEIGHT; tap_height++) begin
                        // TODO add in num_tap into width offset instead of just tapping offset relative to start
                        taps_o[ num_tap ][ ch_num ][ tap_width ][ tap_height ] = buffer[ tap_width ][ tap_height ][ ch_num ];
                    end
                end
            end
        end
    end
    // State update to the buffer
    always_ff@(posedge clock_i) begin
        if (shift_vert_i) begin
            for (int row = 1; row < HEIGHT; row++) begin
                buffer[row] <= buffer[row-1];
            end
            buffer[0] <= next_row_i;
        end else if (shift_horiz_i) begin
            for (int row = 0; row < HEIGHT; row++) begin
                for (int col = 0; col < WIDTH-1; col++) begin
                    buffer[row][col] <= buffer[row][col+1];
                end
                buffer[row][WIDTH-1] <= buffer[row][0];
            end
        end
    end
endmodule 


// Takes input image of size KERNAL_SIZE*KERNAL_SIZE*NUM_CHANNELS and produces identical output
// Kernal weights and image values are in fixed-point format 
module kernal_array #(parameter KERNAL_SIZE, NUM_KERNALS,
    WEIGHT_BITS, WEIGHT_Q_SHIFT,
    VALUE_BITS, IN_CHANNELS, OUT_CHANNELS
) (
    input clock_i, 
    input reset_i,
    // The weights for the kernal
    input logic  [ WEIGHT_BITS-1: 0 ] kernal_weights_i[OUT_CHANNELS][IN_CHANNELS][KERNAL_SIZE][KERNAL_SIZE],
    // The image values for each of the stamped kernals
    input logic  [ VALUE_BITS-1 : 0 ] image_values_i  [NUM_KERNALS][IN_CHANNELS] [KERNAL_SIZE][KERNAL_SIZE],
    // The output values for each of the stamped kernals, comes on the clock-edge after inputs provided
    output logic [ VALUE_BITS-1 : 0 ] output_values_o  [NUM_KERNALS][OUT_CHANNELS]
);
    logic [ VALUE_BITS-1 : 0 ] comb_values  [NUM_KERNALS][OUT_CHANNELS];
    // TODO pipeline this and add out_valid signal instead of just combinational logic
    always_comb begin
        for (int kernal_num = 0; kernal_num < NUM_KERNALS; kernal_num++) begin
            for (int out_ch = 0; out_ch < OUT_CHANNELS; out_ch++) begin
                // We are assigning output_values_o[kernal][channel] here
                comb_values[kernal_num][out_ch] = 0;
                // Take dot product of kernal_weights[out_channel] with image_values_i[kernal_num]
                for (int in_ch = 0; in_ch < IN_CHANNELS; in_ch++) begin
                    for (int x = 0; x < KERNAL_SIZE; x++) begin
                        for (int y = 0; y < KERNAL_SIZE; y++) begin
                            // Do fixed-point multiplication of the two scalar values
                            comb_values[kernal_num][out_ch] += 
                                (kernal_weights_i[out_ch][in_ch][x][y] 
                                * image_values_i[kernal_num][in_ch][x][y])
                                >> WEIGHT_Q_SHIFT;
                        end
                    end
                end
            end
        end
    end

    always_ff@(posedge clock_i) begin
        output_values_o <= comb_values;
    end
endmodule 
