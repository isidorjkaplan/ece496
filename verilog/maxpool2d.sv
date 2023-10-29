module max_pooling_layer #(
    parameter WIDTH = 28, 
    parameter POOL_SIZE = 2, 
    parameter VALUE_BITS = 32, 
    parameter CHANNELS = 1,
) (
    // general
    input   logic                               clk,                // Operating clock
    input   logic                               reset,              // Active-high reset signal (reset when set to 1)

    // Input Interface
    input   logic signed    [VALUE_BITS-1:0]    i_data[CHANNELS],   // Input pixel value (32-bit signed Q15.16)
    input   logic                               i_valid,            // Set to 1 if input pixel is valid
    output  logic                               i_ready,            // Set to 1 if consumer block is ready to receive a new pixel
    input   logic                               i_last,             // Set to 1 if input pixel is last of image

    // Output Interface
    output  logic signed    [VALUE_BITS-1:0]    o_data[CHANNELS],   // Output pixel value (32-bit signed Q15.16)
    output  logic                               o_valid,            // Set to 1 if output pixel is valid
    input   logic                               o_ready,            // Set to 1 if this block is ready to receive a new pixel
    output  logic                               o_last              // Set to 1 if output pixel is last of image
);
    logic i_readys[CHANNELS];
    logic o_valids[CHANNELS];
    logic o_lasts[CHANNELS];

    assign i_ready = i_readys[0];
    assign o_valid = o_valids[0];
    assign o_last = o_lasts[0];

    genvar i;
    generate
        for(i = 0; i < CHANNELS; i++) begin : maxpool_channels
            max_pooling_layer_single_channel #(
                .WIDTH(WIDTH),
                .POOL_SIZE(POOL_SIZE),
                .VALUE_BITS(VALUE_BITS),
                .CHANNELS(CHANNELS)
            ) maxpool (
                .clk(clk),
                .reset(reset),
                .i_data(i_data),
                .i_valid(i_valid),
                .i_ready(i_readys[i]),
                .i_last(i_last),
                .o_data(o_data),
                .o_valid(o_valids[i]),
                .o_ready(o_ready),
                .o_last(o_lasts[i])
            );
        end
    endgenerate

endmodule 

module max_pooling_layer_single_channel #(
    parameter WIDTH = 28, 
    parameter POOL_SIZE = 2, 
    parameter VALUE_BITS = 32, 
    parameter CHANNELS = 1
) (
    // general
    input   logic                               clk,        // Operating clock
    input   logic                               reset,      // Active-high reset signal (reset when set to 1)

    // Input Interface
    input   logic signed    [VALUE_BITS-1:0]    i_data,     // Input pixel value (32-bit signed Q15.16)
    input   logic                               i_valid,    // Set to 1 if input pixel is valid
    output  logic                               i_ready,    // Set to 1 if consumer block is ready to receive a new pixel
    input   logic                               i_last,     // Set to 1 if input pixel is last of image

    // Output Interface
    output  logic signed    [VALUE_BITS-1:0]    o_data,     // Output pixel value (32-bit signed Q15.16)
    output  logic                               o_valid,    // Set to 1 if output pixel is valid
    input   logic                               o_ready,    // Set to 1 if this block is ready to receive a new pixel
    output  logic                               o_last      // Set to 1 if output pixel is last of image
);
    logic signed [VALUE_BITS - 1 : 0]   buffer_taps[POOL_SIZE][POOL_SIZE];
    logic                               buffer_ready;
    logic                               buffer_valid;
    logic                               buffer_last;

    // generate output data
    logic signed [VALUE_BITS-1:0]       o_data_q;
    logic signed [VALUE_BITS-1:0]       next_o_data;
    logic                               o_last_q;
    logic                               consumed;

    assign o_valid = ~consumed;
    assign o_last = o_last_q;
    assign o_data = o_data_q;

    // if we don't have valid output then we can get new tap from buffer
    // or if we do have valid output but it will be consumed next cycle
    assign buffer_ready = consumed || (~consumed && o_ready);

    // get max value
    always_comb begin
        // set next_o_data to minimum value
        next_o_data = '0;
        next_o_data[VALUE_BITS-1] = 1'b1;
        // get max value out of the tap values
        // prob have a better way this feels inefficient
        // for(int row = 0; row < POOL_SIZE; row++) begin
        //     for(int col = 0; col < POOL_SIZE; col++) begin
        //         if(next_o_data < buffer_taps[row][col]) begin
        //             next_o_data = buffer_taps[row][col];
        //         end
        //     end
        // end
        // for testing
        next_o_data = buffer_taps[0][0];
    end

    // control signals
    always_ff@(posedge clk) begin
        if(reset) begin
            o_data_q <= '0;
            o_last_q <= 1'b0;
            consumed <= 1'b1;
        end
        // if value is consumed and we got new stuff waiting for us
        else if(consumed && buffer_valid) begin
            o_data_q <= next_o_data;
            o_last_q <= buffer_last;
            consumed <= 1'b0;
        end
        // if value is going to be consumed and we got new stuff waiting for us
        else if(~consumed && o_ready && buffer_valid) begin
            o_data_q <= next_o_data;
            o_last_q <= buffer_last;
            consumed <= 1'b0;
        end
        // if value is going to be consumed and we dont have new stuff waiting for us
        else if(~consumed && o_ready && ~buffer_valid) begin
            consumed <= 1'b1;
        end
    end

    shift_buffer_array_pool #(
        .WIDTH(WIDTH), 
        .POOL_SIZE(POOL_SIZE),
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


endmodule 

module shift_buffer_array_pool #(
    parameter WIDTH, 
    parameter POOL_SIZE,
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
    // we could reduce ram by one row but that makes logic a lot harder
    // TODO: optimize row counts
    localparam BUFFER_HEIGHT = 2*POOL_SIZE;
    localparam OUTPUT_WIDTH = WIDTH/POOL_SIZE;
    
    // Output State
    logic signed [VALUE_BITS-1:0]       taps_q[POOL_SIZE][POOL_SIZE];
    logic                               taps_valid_q;
    logic                               taps_last_q;
    assign o_taps = taps_q;
    assign o_valid = taps_valid_q;
    assign o_last = taps_last_q;

    logic [1:0]                         bank_valid;
    // Write states
    logic [$clog2(POOL_SIZE)-1:0]       ram_w_row_select_q;             // this denotes the row we are currently writing to
    logic                               ram_w_bank_select_q;            // two banks for now
    logic [$clog2(WIDTH)-1:0]           ram_w_addr_q;                   // if we are going to write, this is the address we write to 
    logic                               ram_w_done_bank_q;              // if we are done writing a bank
    // Read states
    logic [$clog2(POOL_SIZE)-1:0]       ram_r_row_select_q;             // this denotes the row we are currently writing to
    logic                               ram_r_bank_select_q;            // two banks for now
    logic [$clog2(WIDTH)-1:0]           ram_r_addr_q;                   // if we are going to write, this is the address we write to 
    logic                               ram_r_done_bank_q;              // if we are done reading a bank
    logic [$clog2(WIDTH)-1:0]           prev_ram_r_addr_q;
    logic [VALUE_BITS-1:0]              ram_r_data_q[BUFFER_HEIGHT];    // synchronous result from the ram access
    
    // Combinational Logic Elements
    logic [$clog2(WIDTH)-1:0]           ram_r_addr;                     // this is address for reading the ram
    logic [$clog2(WIDTH)-1:0]           next_ram_w_addr;                // specify the next value for write address
    logic [$clog2(BUFFER_HEIGHT)-1:0]   next_ram_w_row_select;          // the ram write head value
    logic signed [VALUE_BITS-1:0]       next_taps[TAP_HEIGHT][TAP_WIDTH];
    logic                               write_en;                       // should we write to the ram this cycle
    
    assign write_en = i_valid && (ram_w_addr_q < WIDTH) && (~bank_valid[ram_w_bank_select_q]);
    assign i_ready = (ram_w_addr_q < WIDTH) && (~bank_valid[ram_w_bank_select_q]);

    // Declare the row buffer rams -- One for each of the rows
    genvar ram_num;
    generate
        for (ram_num = 0; ram_num < BUFFER_HEIGHT; ram_num++) begin : buffer_rams
            // we could use single port ram in this case
            // TODO: optimize to single row?
            dual_port_ram #(
                .VALUE_BITS(VALUE_BITS), 
                .WIDTH(WIDTH)
            ) line_ram(
                .clk(clk), 
                .w_data(i_data), 
                .w_addr(ram_w_addr_q),
                .w_valid(write_en && ((ram_w_bank_select_q ? ram_w_row_select_q + POOL_SIZE : ram_w_row_select_q)==ram_num)),
                .r_addr(ram_r_addr), 
                .r_data(ram_r_data_q[ram_num])
            );
        end
    endgenerate

    // bank valid signal
    always_ff@(posedge clk) begin
        if(reset) begin
            bank_valid <= 0;
        end
        else if(ram_w_done_bank_q) begin
            bank_valid[ram_w_bank_select_q] <= 1'b1;
        end
        else if(ram_r_done_bank_q) begin
            bank_valid[ram_r_bank_select_q] <= 1'b0;
        end
    end

    // write logic
    always_ff@(posedge clk) begin
        if(reset) begin
            ram_w_row_select_q <= 0;
            ram_w_bank_select_q <= 0;
            ram_w_addr_q <= 0;
            ram_w_done_bank_q <= 0;
        end
        // if done with this bank
        else if((ram_w_addr_q == WIDTH) && (ram_w_row_select_q == (POOL_SIZE-1))) begin
            ram_w_row_select_q <= 0;
            ram_w_addr_q <= 0;
            ram_w_bank_select_q <= 0;
        end
    end
    
endmodule 