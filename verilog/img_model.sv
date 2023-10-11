

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

    parameter LAYER0_KERNAL_SIZE=3;
    parameter LAYER0_WIDTH=28;
    parameter LAYER0_IN_CHANNELS=1;
    parameter LAYER0_OUT_CHANNELS=4;
    parameter LAYER0_NUM_KERNALS=2; // This layer was limiting performance so increasing
    parameter LAYER0_OUT_WIDTH = LAYER0_WIDTH - LAYER0_KERNAL_SIZE + 1;

    logic  [ WEIGHT_BITS-1 : 0 ] layer0_kernal_weights_i[LAYER0_OUT_CHANNELS][LAYER0_IN_CHANNELS][LAYER0_KERNAL_SIZE][LAYER0_KERNAL_SIZE];

    logic [VALUE_BITS-1 : 0] layer0_in_row_i[LAYER0_WIDTH][LAYER0_IN_CHANNELS];
    logic layer0_in_row_valid_i, layer0_in_row_accept_o, layer0_in_row_last_i;
    
    logic [VALUE_BITS -1 : 0] layer0_out_row_o[LAYER0_OUT_WIDTH][LAYER0_OUT_CHANNELS];
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
    parameter POOL0_WIDTH=LAYER0_OUT_WIDTH;
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
    
    cnn_layer #(
        .KERNAL_SIZE(LAYER1_KERNAL_SIZE), .NUM_KERNALS(LAYER1_NUM_KERNALS), 
        .WIDTH(LAYER1_WIDTH), .VALUE_BITS(VALUE_BITS), .WEIGHT_BITS(WEIGHT_BITS), .WEIGHT_Q_SHIFT(WEIGHT_Q_SHIFT), 
        .IN_CHANNELS(LAYER1_IN_CHANNELS), .OUT_CHANNELS(LAYER1_OUT_CHANNELS)
    ) layer1(
        // General
        .clock_i(clock), .reset_i(reset),
        .kernal_weights_i(layer1_kernal_weights_i),
        // INPUT INFO
        .in_row_i(layer1_in_row_i),
        .in_row_valid_i(layer1_in_row_valid_i),
        .in_row_accept_o(layer1_in_row_accept_o),
        .in_row_last_i(layer1_in_row_last_i),
        // OUT INFO
        .out_row_o(layer1_out_row_o),
        .out_row_valid_o(layer1_out_row_valid_o),
        .out_row_accept_i(layer1_out_row_accept_i),
        .out_row_last_o(layer1_out_row_last_o)
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
    
    logic [VALUE_BITS - 1 : 0] pool1_out_row_o[POOL1_OUT_WIDTH][POOL1_CHANNELS];
    logic pool1_out_row_valid_o;
    logic pool1_out_row_accept_i;
    logic pool1_out_row_last_o;

    max_pooling_layer #(
        .KERNAL_SIZE(POOL1_KERNAL_SIZE), .NUM_KERNALS(POOL1_NUM_KERNALS), 
        .WIDTH(POOL1_WIDTH), .VALUE_BITS(VALUE_BITS), .CHANNELS(POOL1_CHANNELS)
    ) pool1 (
        // General
        .clock_i(clock), .reset_i(reset),
        // INPUT INFO
        .in_row_i(pool1_in_row_i),
        .in_row_valid_i(pool1_in_row_valid_i),
        .in_row_accept_o(pool1_in_row_accept_o),
        .in_row_last_i(pool1_in_row_last_i),
        // OUT INFO
        .out_row_o(pool1_out_row_o),
        .out_row_valid_o(pool1_out_row_valid_o),
        .out_row_accept_i(pool1_out_row_accept_i),
        .out_row_last_o(pool1_out_row_last_o)
    );

    // LAYER1 -> POOL1 GLUE LOGIC
    assign pool1_in_row_i = layer1_out_row_o;
    assign pool1_in_row_valid_i = layer1_out_row_valid_o;
    assign layer1_out_row_accept_i = pool1_in_row_accept_o;
    assign pool1_in_row_last_i = layer1_out_row_last_o;

    // POOL1 -> OUT glue logic


    logic [VALUE_BITS-1 : 0] out_row_par[POOL1_OUT_WIDTH*POOL1_CHANNELS];
    serialize #(.N(POOL1_OUT_WIDTH*POOL1_CHANNELS), .DATA_BITS(VALUE_BITS), .DATA_PER_WORD(VALUES_PER_WORD)) ser2par(
        .clock(clock), .reset(reset), 
        .in_data(out_row_par), .in_valid(pool1_out_row_valid_o),
        .out_data(out_data), .out_valid(out_valid),
        .downstream_stall(downstream_stall), .upstream_stall(pool1_out_row_accept_i)
    );
    always_comb begin
        for (int x = 0; x < POOL1_OUT_WIDTH; x++) begin
            for (int out_ch = 0; out_ch < POOL1_CHANNELS; out_ch++) begin
                out_row_par[x + out_ch*POOL1_OUT_WIDTH] = pool1_out_row_o[x][out_ch];
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

