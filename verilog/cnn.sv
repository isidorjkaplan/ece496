

// Input is streamed where we recieve an image as 28*28 individual transfers with the grayscale values
module cnn_top(
    input logic clock, 
    input logic reset, //+ve synchronous reset

    input logic [ 31 : 0 ] in_data,
    input logic in_valid,

    output logic [ 31 : 0 ] out_data,
    output logic out_valid, 

    input logic downstream_stall,
    output logic upstream_stall
);    
    parameter VALUE_BITS=8;
    parameter WEIGHT_BITS=16;
    parameter WEIGHT_Q_SHIFT=8;
    parameter KERNAL_SIZE=3;
    parameter WIDTH=28;
    parameter IN_CHANNELS=1;
    parameter OUT_CHANNELS=3;
    parameter NUM_KERNALS=2;
    parameter STRIDE=1;

    logic  [ WEIGHT_BITS-1 : 0 ] kernal_weights_i[OUT_CHANNELS][IN_CHANNELS][KERNAL_SIZE][KERNAL_SIZE];

    logic [VALUE_BITS-1 : 0] in_row_i[WIDTH][IN_CHANNELS];
    logic in_row_valid_i, in_row_accept_o, in_row_last_i;
    

    logic [VALUE_BITS -1 : 0] out_row_o[WIDTH/STRIDE][OUT_CHANNELS];
    logic out_row_valid_o;
    logic out_row_accept_i;
    logic out_row_last_o;

    cnn_layer #(
        .KERNAL_SIZE(KERNAL_SIZE), .NUM_KERNALS(NUM_KERNALS), .STRIDE(STRIDE), 
        .WIDTH(WIDTH), .VALUE_BITS(VALUE_BITS), .WEIGHT_BITS(WEIGHT_BITS), .WEIGHT_Q_SHIFT(WEIGHT_Q_SHIFT), .IN_CHANNELS(IN_CHANNELS), .OUT_CHANNELS(OUT_CHANNELS)
    ) layer0(
        // General
        .clock_i(clock), .reset_i(reset),
        .kernal_weights_i(kernal_weights_i),
        // INPUT INFO
        .in_row_i(in_row_i),
        .in_row_valid_i(in_row_valid_i),
        .in_row_accept_o(in_row_accept_o),
        .in_row_last_i(in_row_last_i),
        // OUT INFO
        .out_row_o(out_row_o),
        .out_row_valid_o(out_row_valid_o),
        .out_row_accept_i(out_row_accept_i),
        .out_row_last_o(out_row_last_o)
    );

    // GLUE LOGIC TO MAKE SURE NEURAL NETWORK NOT OPTIMIZED AWAY FOR AREA/POWER/FMAX CALCULATIONS

    logic [7:0] in_bytes[4];
    assign in_bytes = '{in_data[31:24], in_data[23:16], in_data[15:8], in_data[7:0]};

    always_comb begin
        for (int x = 0; x < WIDTH; x++) begin
            for (int in_ch = 0; in_ch < IN_CHANNELS; in_ch++) begin
                in_row_i[x][in_ch] = in_bytes[(x%4)];
            end
        end
        for (int out_ch = 0; out_ch < OUT_CHANNELS; out_ch++) begin
            for (int in_ch = 0; in_ch < IN_CHANNELS; in_ch++) begin
                for (int x = 0; x < KERNAL_SIZE; x++) begin
                    for (int y = 0; y < KERNAL_SIZE; y++) begin
                        kernal_weights_i[out_ch][in_ch][x][y] = in_bytes[(x+y)%4];
                    end
                end
            end
        end
        in_row_valid_i = in_valid;
        upstream_stall = !in_row_accept_o;
        in_row_last_i = 0;

        out_valid = out_row_valid_o;
        out_row_accept_i = !downstream_stall;
        out_data = 0;
        for (int x = 0; x < WIDTH/STRIDE; x++) begin
            for (int out_ch = 0; out_ch < OUT_CHANNELS; out_ch++) begin
                // To ensure that it does not optimize out out_row_o
                out_data += out_row_o[x][out_ch];
            end
        end
    end
endmodule 


module cnn_layer #(parameter KERNAL_SIZE, NUM_KERNALS, STRIDE, WIDTH, VALUE_BITS, WEIGHT_BITS, WEIGHT_Q_SHIFT, IN_CHANNELS, OUT_CHANNELS) (
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
    output logic [VALUE_BITS -1 : 0] out_row_o[WIDTH/STRIDE][OUT_CHANNELS],
    output logic out_row_valid_o,
    output logic out_row_last_o,
    input logic out_row_accept_i
);

    // BUFFER LOGIC
    // First kernal needs kernal_height tap, each subsequent kernal requires STRIDE rows beyond that
    //parameter BUFFER_HEIGHT = KERNAL_SIZE + (NUM_KERNALS-1)*STRIDE;
    
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
    typedef enum {S_GET_NEXT_ROW, S_CALC_ROW, S_WAIT_ROW_READ} e_state;

    // buffer registers
    e_state state_q; // for what mode we are in
    logic [7 : 0] row_idx_q; // what row number is the next row we shift in
    logic [7 : 0] col_idx_q; // what column is at zero (aka, how many times have we shifted
    logic [VALUE_BITS -1 : 0] out_row_q[WIDTH/STRIDE][OUT_CHANNELS];
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
    logic [VALUE_BITS -1 : 0] next_out_row[WIDTH/STRIDE][OUT_CHANNELS];
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
                // Change state to be calculating over that row
                if (next_row_idx >= KERNAL_SIZE) begin
                    next_state = S_CALC_ROW;
                    next_col_idx = 0;
                end
                else begin
                    in_row_accept_o = 1;
                end
            end
        end
        S_CALC_ROW: begin
            // TODO assuming can produce an output of the kernal each itteration; probably gonna have to stall here
            buffer_shift_horiz = 1;
            next_col_idx = col_idx_q + 1;
            
            for (int kernal_num = 0; kernal_num < NUM_KERNALS; kernal_num++) begin
                next_out_row[ (kernal_num*WIDTH/NUM_KERNALS) +  col_idx_q ] = kernal_arr_output[kernal_num];
            end

            if (next_col_idx*NUM_KERNALS >= WIDTH) begin
                next_state = S_WAIT_ROW_READ;
                next_out_row_valid = 1;
                // Accept the row read; the input can now put a new value on its input port
                in_row_accept_o = 1;
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
                for (int col = 1; col < WIDTH; col++) begin
                    buffer[row][col] <= buffer[row][col-1];
                end
                buffer[row][0] <= buffer[row][WIDTH-1];
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
