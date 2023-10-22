

// Input is streamed where we recieve an image as 28*28 individual transfers with the grayscale values
module model #(
    parameter VALUE_BITS = 8,
    // DO NOT CHANGE BELOW VALUES
    INPUT_WIDTH = 28, INPUT_CHANNELS=1, OUTPUT_WIDTH = 1, OUTPUT_CHANNELS = 10, TAG_WIDTH = 6
)(
    // General signals
    input clock_i, input reset_i,
    // next row logic
    input logic [VALUE_BITS - 1 : 0] in_row_i[INPUT_WIDTH][INPUT_CHANNELS], 
    input logic in_row_valid_i, 
    output logic in_row_accept_o, // must be high before in_row_i moves to next value
    input logic in_row_last_i,  // if raised we are done
    input logic [TAG_WIDTH-1:0] in_row_tag_i,
    // output row valid 
    output logic [VALUE_BITS - 1 : 0] out_row_o[OUTPUT_WIDTH][OUTPUT_CHANNELS],
    output logic out_row_valid_o,
    output logic out_row_last_o,
    output logic [TAG_WIDTH-1:0] out_row_tag_o,
    input logic out_row_accept_i
);    
    

endmodule 

