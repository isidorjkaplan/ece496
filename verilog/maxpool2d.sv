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
    


endmodule 