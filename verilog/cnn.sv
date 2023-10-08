

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

    parameter VALUE_BITS=8;
    parameter KERNAL_SIZE=3;
    parameter LAYER0_WIDTH=28;
    parameter LAYER0_IN_CHANNELS=1;
    parameter LAYER0_OUT_CHANNELS=2;
    parameter LAYER0_NUM_KERNALS=1;
    parameter LAYER0_STRIDE=1;

    logic [VALUE_BITS-1 : 0] in_row_layer0[LAYER0_WIDTH][LAYER0_IN_CHANNELS];
    logic [$clog2(LAYER0_WIDTH)-1 : 0] in_row_idx;
    logic layer0_in_ready;

    cnn_layer #(
        .KERNAL_SIZE(KERNAL_SIZE), .NUM_KERNALS(LAYER0_NUM_KERNALS), .STRIDE(LAYER0_STRIDE), 
        .WIDTH(LAYER0_WIDTH), .VALUE_BITS(VALUE_BITS), .IN_CHANNELS(LAYER0_IN_CHANNELS), .OUT_CHANNELS(LAYER0_OUT_CHANNELS)
    ) layer0(
        // General
        .clock_i(clock), .reset_i(reset),
        // INPUT INFO
        .in_row_i(in_row_layer0),
        .in_row_valid_i(in_row_idx == LAYER0_WIDTH),
        .in_row_ready_o(layer0_in_ready)
        // Don't even bother hooking up output info right now
        // TODO
    );

    
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
    parameter BUFFER_HEIGHT = KERNAL_SIZE + (NUM_KERNALS-1)*STRIDE;
    
    logic buffer_shift_horiz, buffer_shift_vert;
    logic [ VALUE_BITS-1 : 0 ] buffer_taps[IN_CHANNELS][KERNAL_SIZE][BUFFER_HEIGHT];

    shift_buffer_array #(.WIDTH(WIDTH), .HEIGHT(BUFFER_HEIGHT), .NUM_TAPS(KERNAL_SIZE), .VALUE_BITS(VALUE_BITS), .NUM_CHANNELS(IN_CHANNELS)) buffer(
        .clock_i(clock_i), .reset_i(reset_i), 
        .next_row_i(in_row_i), .next_row_valid_i(in_row_valid_i),
        .shift_horiz_i(buffer_shift_horiz), .shift_vert_i(buffer_shift_vert), 
        .taps_o(buffer_taps)
    );

    // KERNAL LOGIC
    // TODO


endmodule 

module shift_buffer_array #(parameter WIDTH, HEIGHT, NUM_TAPS, VALUE_BITS, NUM_CHANNELS) 
(
    input clock_i, input reset_i,
    // next row logic
    input logic [VALUE_BITS - 1 : 0] next_row_i[WIDTH][NUM_CHANNELS], 
    input logic next_row_valid_i, 
    // controls
    input logic shift_horiz_i, // shift over left
    input logic shift_vert_i, // shift entire row up
    // outputs
    output logic [VALUE_BITS - 1 : 0] taps_o[NUM_CHANNELS][NUM_TAPS][HEIGHT]
);
    //TODO
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