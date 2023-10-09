

// Input is streamed where we recieve an image as 28*28 individual transfers with the grayscale values
module cnn_top(
    input wire clock, 
    input wire reset, //+ve synchronous reset

    input wire [ 31 : 0 ] in_data,
    input wire in_valid,

    output reg [ 31 : 0 ] out_data,
    output reg out_valid, 

    input wire downstream_stall,
    output wire upstream_stall
);
    assign upstream_stall = 0;

    // TODO

    
endmodule 


module cnn_layer #(parameter KERNAL_SIZE, NUM_KERNALS, STRIDE, WIDTH, VALUE_BITS, IN_CHANNELS, OUT_CHANNELS) (
    // General signals
    input clock_i, input reset_i,
    // next row logic
    input logic [VALUE_BITS - 1 : 0] in_row_i[WIDTH][IN_CHANNELS], 
    input logic in_row_valid_i, 
    output logic in_row_ready_o, 
    // output row valid 
    output logic [VALUE_BITS -1 : 0] out_row_o[WIDTH/STRIDE][OUT_CHANNELS],
    output logic out_row_valid_o,
    input logic out_row_accept_i
);

    // BUFFER LOGIC

    // First kernal needs kernal_height tap, each subsequent kernal requires STRIDE rows beyond that
    //parameter BUFFER_HEIGHT = KERNAL_SIZE + (NUM_KERNALS-1)*STRIDE;
    
    logic buffer_shift_horiz, buffer_shift_vert;
    logic [ VALUE_BITS-1 : 0 ] buffer_taps[NUM_KERNALS][IN_CHANNELS][KERNAL_SIZE][KERNAL_SIZE];

    assign buffer_shift_vert = in_row_valid_i;
    assign buffer_shift_horiz = 1;

    shift_buffer_array #(.WIDTH(WIDTH), .HEIGHT(KERNAL_SIZE), .TAP_WIDTH(KERNAL_SIZE), .NUM_TAPS(NUM_KERNALS), .VALUE_BITS(VALUE_BITS), .NUM_CHANNELS(IN_CHANNELS)) buffer(
        .clock_i(clock_i), .reset_i(reset_i), 
        .next_row_i(in_row_i),
        .shift_horiz_i(buffer_shift_horiz), .shift_vert_i(buffer_shift_vert), 
        .taps_o(buffer_taps)
    );

    // KERNAL LOGIC
    // TODO


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

    always_comb begin
        for (int num_tap = 0; num_tap < NUM_TAPS; num_tap++) begin
            for (int ch_num = 0; ch_num < NUM_CHANNELS; ch_num++) begin
                for (int tap_width = 0; tap_width < TAP_WIDTH; tap_width++) begin
                    for (int tap_height = 0; tap_height < HEIGHT; tap_height++) begin
                        // TODO add in num_tap into width offset instead of just tapping offset relative to start
                        taps_o[ num_tap ][ ch_num ][ tap_width ][ tap_height ] = buffer[ ((num_tap*WIDTH)/NUM_TAPS) + tap_width ][ tap_height ][ ch_num ];
                    end
                end
            end
        end
    end
    
    always_ff@(posedge clock_i) begin
        if (shift_vert_i) begin
            for (int row = 1; row < HEIGHT; row++) begin
                buffer[row] <= buffer[row-1];
            end
            buffer[0] <= next_row_i;
        end else if (shift_horiz_i) begin
            for (int col = 1; col < WIDTH; col++) begin
                for (int row = 0; row < HEIGHT; row++) begin
                    buffer[row][col] <= buffer[row][col-1];
                end
            end
        end
    end
endmodule 


/*
// An array of multiple stamped instances of the kernals
module kernal_array #(parameter 
    KERNAL_SIZE, NUM_KERNALS,
    BUFFER_HEIGHT
    WEIGHT_BITS=16, WEIGHT_Q_SHIFT=8,
    VALUE_BITS, IN_CHANNELS, OUT_CHANNELS
) (
    input clock, 
    input reset,
    input in_valid, 
    input out_valid, 
    input logic  [ WEIGHT_BITS-1 : 0 ] kernal_weights[KERNAL_SIZE][KERNAL_SIZE][OUT_CHANNELS],
    input logic  [ VALUE_BITS-1  : 0 ] image_values[BUFFER_HEIGHT][KERNAL_SIZE][IN_CHANNELS],
    output logic [ VALUE_BITS-1  : 0 ] output_value[NUM_KERNALS][OUT_CHANNELS],
);;
       logic [ VALUE_BITS -1 : 0] kernal_outputs[NUM_KERNALS][NUM_CHANNELS];

    genvar i;
    generate 
        for (i = 0; i < NUM_KERNALS; i++) begin
            kernal #(KERNAL_SIZE=KERNAL_SIZE, VALUE_BITS=VALUE_BITS, ) kern();
        end
    endgenerate 
endmodule

// Takes input image of size KERNAL_SIZE*KERNAL_SIZE*NUM_CHANNELS and produces identical output
// Kernal weights and image values are in fixed-point format 
module kernal #(parameter KERNAL_SIZE, 
    WEIGHT_BITS=16, WEIGHT_Q_SHIFT=8,
    VALUE_BITS, IN_CHANNELS, OUT_CHANNELS
) (
    input clock, 
    input reset,
    input in_valid, 
    input out_valid, 
    input logic  [ WEIGHT_BITS-1 : 0 ] kernal_weights[KERNAL_SIZE][KERNAL_SIZE][OUT_CHANNELS],
    input logic  [ VALUE_BITS-1  : 0 ] image_values[KERNAL_SIZE][KERNAL_SIZE][IN_CHANNELS],
    output logic [ VALUE_BITS-1  : 0 ] output_value[OUT_CHANNELS],
);
endmodule 
*/