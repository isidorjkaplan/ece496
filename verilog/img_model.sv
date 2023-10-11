

// Input is streamed where we recieve an image as 28*28 individual transfers with the grayscale values
module cnn_top #(
    parameter VALUE_BITS = 8,
    localparam INPUT_WIDTH = 28, INPUT_CHANNELS=1, OUTPUT_WIDTH = 1, OUTPUT_CHANNELS = 10, TAG_WIDTH = 6
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
    parameter WEIGHT_BITS=8;
    parameter WEIGHT_Q_SHIFT=6;

    // CNN LAYER 0

    parameter LAYER0_KERNAL_SIZE=3;
    parameter LAYER0_WIDTH=28;
    parameter LAYER0_IN_CHANNELS=1;
    parameter LAYER0_OUT_CHANNELS=4;
    parameter LAYER0_NUM_KERNALS=2; // This layer was limiting performance so increasing
    parameter LAYER0_OUT_WIDTH = LAYER0_WIDTH - LAYER0_KERNAL_SIZE + 1;

    logic  [ WEIGHT_BITS-1 : 0 ] layer0_kernal_weights_i[LAYER0_OUT_CHANNELS][LAYER0_IN_CHANNELS][LAYER0_KERNAL_SIZE][LAYER0_KERNAL_SIZE];
    
    logic [VALUE_BITS -1 : 0] layer0_out_row_o[LAYER0_OUT_WIDTH][LAYER0_OUT_CHANNELS];
    logic [TAG_WIDTH-1:0] layer0_out_row_tag_o; 
    logic layer0_out_row_valid_o;
    logic layer0_out_row_accept_i;
    logic layer0_out_row_last_o;

    cnn_layer #(
        .KERNAL_SIZE(LAYER0_KERNAL_SIZE), .NUM_KERNALS(LAYER0_NUM_KERNALS), 
        .WIDTH(LAYER0_WIDTH), .VALUE_BITS(VALUE_BITS), .WEIGHT_BITS(WEIGHT_BITS), .WEIGHT_Q_SHIFT(WEIGHT_Q_SHIFT), 
        .IN_CHANNELS(LAYER0_IN_CHANNELS), .OUT_CHANNELS(LAYER0_OUT_CHANNELS), .TAG_WIDTH(TAG_WIDTH)
    ) layer0(
        // General
        .clock_i(clock_i), .reset_i(reset_i),
        .kernal_weights_i(layer0_kernal_weights_i),
        // INPUT INFO
        .in_row_i(in_row_i),
        .in_row_valid_i(in_row_valid_i),
        .in_row_accept_o(in_row_accept_o),
        .in_row_last_i(in_row_last_i),
        .in_row_tag_i(in_row_tag_i),
        // OUT INFO
        .out_row_o(layer0_out_row_o),
        .out_row_valid_o(layer0_out_row_valid_o),
        .out_row_accept_i(layer0_out_row_accept_i),
        .out_row_tag_o(layer0_out_row_tag_o),
        .out_row_last_o(layer0_out_row_last_o)
    );

    // POOLING LAYER 0

    parameter POOL0_KERNAL_SIZE=2;
    parameter POOL0_NUM_KERNALS=1;
    parameter POOL0_WIDTH=LAYER0_OUT_WIDTH;
    parameter POOL0_CHANNELS=LAYER0_OUT_CHANNELS;
    parameter POOL0_OUT_WIDTH = POOL0_WIDTH / POOL0_KERNAL_SIZE;

    logic [VALUE_BITS - 1 : 0] pool0_in_row_i[POOL0_WIDTH][POOL0_CHANNELS];
    logic pool0_in_row_valid_i, pool0_in_row_accept_o, pool0_in_row_last_i;
    
    logic [VALUE_BITS - 1 : 0] pool0_out_row_o[POOL0_OUT_WIDTH][POOL0_CHANNELS];
    logic pool0_out_row_valid_o;
    logic pool0_out_row_accept_i;
    logic pool0_out_row_last_o;
    logic [TAG_WIDTH-1:0] pool0_out_row_tag_o; 

    max_pooling_layer #(
        .KERNAL_SIZE(POOL0_KERNAL_SIZE), .NUM_KERNALS(POOL0_NUM_KERNALS), 
        .WIDTH(POOL0_WIDTH), .VALUE_BITS(VALUE_BITS), .CHANNELS(POOL0_CHANNELS), .TAG_WIDTH(TAG_WIDTH)
    ) pool0 (
        // General
        .clock_i(clock_i), .reset_i(reset_i),
        // INPUT INFO
        .in_row_i(pool0_in_row_i),
        .in_row_valid_i(pool0_in_row_valid_i),
        .in_row_accept_o(pool0_in_row_accept_o),
        .in_row_last_i(pool0_in_row_last_i),
        .in_row_tag_i(layer0_out_row_tag_o),
        // OUT INFO
        .out_row_o(pool0_out_row_o),
        .out_row_valid_o(pool0_out_row_valid_o),
        .out_row_accept_i(pool0_out_row_accept_i),
        .out_row_last_o(pool0_out_row_last_o),
        .out_row_tag_o(pool0_out_row_tag_o)
    );

    // LAYER0 -> POOL0 GLUE LOGIC
    assign pool0_in_row_i = layer0_out_row_o;
    assign pool0_in_row_valid_i = layer0_out_row_valid_o;
    assign layer0_out_row_accept_i = pool0_in_row_accept_o;
    assign pool0_in_row_last_i = layer0_out_row_last_o;

    // CNN LAYER 1

    parameter LAYER1_KERNAL_SIZE=3;
    parameter LAYER1_WIDTH=POOL0_OUT_WIDTH;
    parameter LAYER1_OUT_WIDTH = LAYER1_WIDTH - LAYER1_KERNAL_SIZE + 1;
    parameter LAYER1_IN_CHANNELS=POOL0_CHANNELS;
    parameter LAYER1_OUT_CHANNELS=10;
    parameter LAYER1_NUM_KERNALS=1;

    logic  [ WEIGHT_BITS-1 : 0 ] layer1_kernal_weights_i[LAYER1_OUT_CHANNELS][LAYER1_IN_CHANNELS][LAYER1_KERNAL_SIZE][LAYER1_KERNAL_SIZE];

    logic [VALUE_BITS-1 : 0] layer1_in_row_i[LAYER1_WIDTH][LAYER1_IN_CHANNELS];
    logic layer1_in_row_valid_i, layer1_in_row_accept_o, layer1_in_row_last_i;
    
    logic [VALUE_BITS -1 : 0] layer1_out_row_o[LAYER1_OUT_WIDTH][LAYER1_OUT_CHANNELS];
    logic layer1_out_row_valid_o;
    logic layer1_out_row_accept_i;
    logic layer1_out_row_last_o;
    logic [TAG_WIDTH-1:0] layer1_out_row_tag_o; 
    
    cnn_layer #(
        .KERNAL_SIZE(LAYER1_KERNAL_SIZE), .NUM_KERNALS(LAYER1_NUM_KERNALS), 
        .WIDTH(LAYER1_WIDTH), .VALUE_BITS(VALUE_BITS), .WEIGHT_BITS(WEIGHT_BITS), .WEIGHT_Q_SHIFT(WEIGHT_Q_SHIFT), 
        .IN_CHANNELS(LAYER1_IN_CHANNELS), .OUT_CHANNELS(LAYER1_OUT_CHANNELS), .TAG_WIDTH(TAG_WIDTH)
    ) layer1(
        // General
        .clock_i(clock_i), .reset_i(reset_i),
        .kernal_weights_i(layer1_kernal_weights_i),
        // INPUT INFO
        .in_row_i(layer1_in_row_i),
        .in_row_valid_i(layer1_in_row_valid_i),
        .in_row_accept_o(layer1_in_row_accept_o),
        .in_row_last_i(layer1_in_row_last_i),
        .in_row_tag_i(pool0_out_row_tag_o),
        // OUT INFO
        .out_row_o(layer1_out_row_o),
        .out_row_valid_o(layer1_out_row_valid_o),
        .out_row_accept_i(layer1_out_row_accept_i),
        .out_row_last_o(layer1_out_row_last_o),
        .out_row_tag_o(layer1_out_row_tag_o)
    );

    // POOL0 -> LAYER1
    assign layer1_in_row_i = pool0_out_row_o;
    assign layer1_in_row_valid_i = pool0_out_row_valid_o;
    assign pool0_out_row_accept_i = layer1_in_row_accept_o;
    assign layer1_in_row_last_i = pool0_out_row_last_o;

    // POOLING LAYER 1

    parameter POOL1_KERNAL_SIZE=LAYER1_OUT_WIDTH; // this should reduce it to 1x1xCHANNELS which is output shape we want
    parameter POOL1_NUM_KERNALS=1;
    parameter POOL1_WIDTH=LAYER1_OUT_WIDTH;
    parameter POOL1_CHANNELS=LAYER1_OUT_CHANNELS;
    parameter POOL1_OUT_WIDTH = POOL1_WIDTH / POOL1_KERNAL_SIZE;

    logic [VALUE_BITS - 1 : 0] pool1_in_row_i[POOL1_WIDTH][POOL1_CHANNELS];
    logic pool1_in_row_valid_i, pool1_in_row_accept_o, pool1_in_row_last_i;


    max_pooling_layer #(
        .KERNAL_SIZE(POOL1_KERNAL_SIZE), .NUM_KERNALS(POOL1_NUM_KERNALS), 
        .WIDTH(POOL1_WIDTH), .VALUE_BITS(VALUE_BITS), .CHANNELS(POOL1_CHANNELS), .TAG_WIDTH(TAG_WIDTH)
    ) pool1 (
        // General
        .clock_i(clock_i), .reset_i(reset_i),
        // INPUT INFO
        .in_row_i(pool1_in_row_i),
        .in_row_valid_i(pool1_in_row_valid_i),
        .in_row_accept_o(pool1_in_row_accept_o),
        .in_row_last_i(pool1_in_row_last_i),
        .in_row_tag_i(layer0_out_row_tag_o),
        // OUT INFO
        .out_row_o(out_row_o),
        .out_row_valid_o(out_row_valid_o),
        .out_row_accept_i(out_row_accept_i),
        .out_row_last_o(out_row_last_o),
        .out_row_tag_o(out_row_tag_o)
    );

    // LAYER1 -> POOL1 GLUE LOGIC
    assign pool1_in_row_i = layer1_out_row_o;
    assign pool1_in_row_valid_i = layer1_out_row_valid_o;
    assign layer1_out_row_accept_i = pool1_in_row_accept_o;
    assign pool1_in_row_last_i = layer1_out_row_last_o;

    // NEURAL NETWORK WEIGHTS DEFINITION - ALL LAYERS

    always_comb begin
        // LAYER 0 WEIGHTS
        for (int out_ch = 0; out_ch < LAYER0_OUT_CHANNELS; out_ch++) begin
            for (int in_ch = 0; in_ch < LAYER0_IN_CHANNELS; in_ch++) begin
                for (int x = 0; x < LAYER0_KERNAL_SIZE; x++) begin
                    for (int y = 0; y < LAYER0_KERNAL_SIZE; y++) begin
                        layer0_kernal_weights_i[out_ch][in_ch][x][y] 
                        = 1<<(WEIGHT_Q_SHIFT-$clog2(LAYER0_OUT_CHANNELS*LAYER0_IN_CHANNELS*LAYER0_KERNAL_SIZE*LAYER0_KERNAL_SIZE));
                    end
                end
            end
        end
        // LAYER 1 WEIGHTS
        for (int out_ch = 0; out_ch < LAYER1_OUT_CHANNELS; out_ch++) begin
            for (int in_ch = 0; in_ch < LAYER1_IN_CHANNELS; in_ch++) begin
                for (int x = 0; x < LAYER1_KERNAL_SIZE; x++) begin
                    for (int y = 0; y < LAYER1_KERNAL_SIZE; y++) begin
                        layer1_kernal_weights_i[out_ch][in_ch][x][y] 
                        = 1<<(WEIGHT_Q_SHIFT-$clog2(LAYER1_OUT_CHANNELS*LAYER1_IN_CHANNELS*LAYER1_KERNAL_SIZE*LAYER1_KERNAL_SIZE));
                    end
                end
            end
        end
    end

endmodule 

