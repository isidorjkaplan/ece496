module max_pooling_layer #(
    parameter WIDTH = 28, 
    parameter POOL_SIZE = 2, 
    parameter VALUE_BITS = 32, 
    parameter CHANNELS = 1,
    parameter RELU = 0
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
                .RELU(RELU)
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
    parameter RELU = 0
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
    localparam O_WIDTH = WIDTH/POOL_SIZE;
    localparam I_WIDTH = O_WIDTH*POOL_SIZE;

    // general logic
    logic                           in_or_out_q;            // 0 for in, 1 for out
    logic                           next_in_or_out;
    logic                           i_ready_q;
    logic                           next_i_ready;
    logic                           got_last_q;             // got the last signal

    // end image logic
    logic                           reset_after_output_q;   // will perform reset by sending last with last output pixel
    logic                           next_reset_after_output;
    logic                           output_last;
    logic                           reset_after_consumed_q; // will perform reset once consumed
    logic                           next_reset_after_consumed;
    logic                           reset_now;              // combinationally asserted

    // ram logic
    logic [$clog2(O_WIDTH)-1:0]     ram_w_addr_q; 
    logic [$clog2(O_WIDTH)-1:0]     next_ram_w_addr; 
    logic [$clog2(O_WIDTH)-1:0]     ram_r_addr;
    logic [$clog2(O_WIDTH)-1:0]     prev_ram_r_addr_q;
    logic signed [VALUE_BITS-1:0]   ram_r_data;
    logic signed [VALUE_BITS-1:0]   ram_w_data;
    logic                           write_en;

    // max pool logic
    logic [$clog2(WIDTH):0]         in_counter_q;           // how many pixels we recieved for this row so far
    logic [$clog2(WIDTH):0]         next_in_counter;
    logic [$clog2(POOL_SIZE+1):0]   per_pool_counter_q;     // how many pixels we recieved for this pool window so far
    logic [$clog2(POOL_SIZE+1):0]   next_per_pool_counter;
    logic [$clog2(POOL_SIZE):0]     row_counter_q;          // which row we are working on rn
    logic [$clog2(POOL_SIZE):0]     next_row_counter;
    logic signed [VALUE_BITS-1:0]   prev_max_q;
    logic signed [VALUE_BITS-1:0]   next_prev_max;
    logic signed [VALUE_BITS-1:0]   new_data_q[POOL_SIZE];
    logic [$clog2(POOL_SIZE):0]     new_data_idx_q;
    logic [$clog2(POOL_SIZE):0]     next_new_data_idx;

    assign i_ready = i_ready_q && ~got_last_q;
    assign o_last = reset_after_consumed_q || output_last;
    

    // main logic of interacting with ram
    always_comb begin
        // default values
        // general control
        next_in_or_out = in_or_out_q;
        next_i_ready = 0;
        // end control
        next_reset_after_output = reset_after_output_q;
        next_reset_after_consumed = reset_after_consumed_q;
        reset_now = 0;
        // ram control
        next_ram_w_addr = ram_w_addr_q;
        ram_r_addr = prev_ram_r_addr_q;
        write_en = 0;
        // max pool logic
        next_in_counter = in_counter_q;
        next_per_pool_counter = per_pool_counter_q;
        next_row_counter = row_counter_q;
        next_prev_max = prev_max_q;
        next_new_data_idx = new_data_idx_q;
        // output logic
        o_data = '0;
        o_valid = 0;
        output_last = 0;

        // if this ever get set we are not doing jack until we reset with last consumed
        if(reset_after_consumed_q) begin
            if(o_ready) 
                reset_now = 1;
        end
        else begin
            // if we are in input mode
            if(~in_or_out_q) begin
                // when processing useful pixels
                if(in_counter_q < I_WIDTH) begin
                    case(per_pool_counter_q)
                        // first cycle do nothing as we are waiting for
                        // prev max on readdata
                        // increment per_pool_counter
                        // TODO: this cycle prob could be eliminated
                        0: begin
                            next_per_pool_counter = next_per_pool_counter + 1;
                        end
                        // second cycle assign prev max value and increment ram_r_addr
                        1: begin
                            // if we are on first row then prev_max shouldn't be read value
                            if(row_counter_q == 0) begin
                                // reset to 0
                                next_prev_max = '0;
                                // if not RELU then reset to most negative value possible
                                if(!RELU) begin
                                    next_prev_max[VALUE_BITS-1] = 1'b1;
                                end                                
                            end
                            else begin
                                next_prev_max = ram_r_data;
                            end
                            // increment ram_r_addr
                            ram_r_addr = ram_r_addr + 1;
                            // next cycle we start reading in pixels, have i_ready high
                            next_i_ready = 1;
                            next_per_pool_counter = next_per_pool_counter + 1;
                        end
                        // last cycle for this pool window, reset relevant counters
                        (POOL_SIZE + 2): begin
                            // ram_w_data would have the correct values to be written in the ram now
                            // increment ram_w_addr and have write_en high
                            write_en = 1'b1;
                            next_ram_w_addr = next_ram_w_addr + 1;
                            // reset counters for next pool
                            next_per_pool_counter = '0;
                            next_new_data_idx = '0;
                        end
                        // default case is then trying to read in pixels
                        default: begin
                            // if data is valid then we would consume that data
                            // increment relevant counters
                            if(i_valid) begin
                                next_in_counter = next_in_counter + 1;
                                next_per_pool_counter = next_per_pool_counter + 1;
                                next_new_data_idx = next_new_data_idx + 1;
                            end
                            // if we will not finish collecting the pixels for this pool window
                            // keep i_ready high
                            if(next_new_data_idx < POOL_SIZE) begin
                                next_i_ready = 1;
                            end
                            // or keep i_ready high if this is last pixel of useful pixels
                            // and we need to get rid of useless pixels
                            if(next_in_counter == I_WIDTH && I_WIDTH != WIDTH) begin
                                next_i_ready = 1;
                            end
                            // if we got last here then it would be in the middle of 
                            // data, so the prev are garbage and we should reset 
                            // after consumed
                            if(got_last_q) next_reset_after_consumed = 1;
                        end
                    endcase
                end
                // when we recived all pixels of a row
                // i_ready should be low when in here
                else if(in_counter_q == WIDTH) begin
                    // if per_pool_counter_q not yet reset
                    if(per_pool_counter_q == POOL_SIZE + 2) begin
                        // ram_w_data would have the correct values to be written in the ram now
                        // have write_en high
                        write_en = 1'b1;
                    end
                    // reset relevant signals 
                    next_row_counter = next_row_counter + 1;
                    ram_r_addr = '0;
                    next_ram_w_addr = '0;
                    next_in_counter = '0;
                    next_per_pool_counter = '0;
                    next_new_data_idx = '0;
                    // hand control to output mode if we are done with input
                    if(next_row_counter == POOL_SIZE) begin
                        next_in_or_out = 1'b1;
                        next_row_counter = '0;
                        // if we are handing control to output right as we got last pixel
                        // then these data in front are still valid, output them
                        // and then reset once consumed
                        if(got_last_q) next_reset_after_output = 1;
                    end
                end
                // when processing not useful pixels
                else begin
                    // if per_pool_counter_q not yet reset
                    if(per_pool_counter_q == POOL_SIZE + 2) begin
                        // ram_w_data would have the correct values to be written in the ram now
                        // increment ram_w_addr and have write_en high
                        write_en = 1'b1;
                        next_ram_w_addr = next_ram_w_addr + 1;
                        // reset counters for next pool
                        next_per_pool_counter = '0;
                        next_new_data_idx = '0;
                    end
                    if(i_valid) begin
                        next_in_counter = next_in_counter + 1;
                    end
                    // keep collecting useless data if there would be more
                    if(next_in_counter != WIDTH) begin
                        next_i_ready = 1;
                    end
                    // if we got last here, assuming pool mask is sqaure and 
                    // image is square, this means that what ever data we got is useless
                    // advertise last and reset
                    if(got_last_q) next_reset_after_consumed = 1;
                end
            end
            // if we are in output mode
            else begin
                // ram_r_addr would be 0 last cycle already so r_data are of valid values
                o_data = ram_r_data;
                o_valid = 1;
                // if data will be consumed increment ram_r_addr so new value is shown next cycle
                if(o_ready) begin
                    ram_r_addr = ram_r_addr + 1;
                end
                // if we are already showing the last data and the next data we are reading
                // is from address out of bounds, then we have finished outputing,
                // reset address and switch back to input mode
                if(ram_r_addr == O_WIDTH) begin
                    ram_r_addr = '0;
                    next_in_or_out = 1'b0;
                    // if this was high then we should be asserting last signal together
                    // and also reset
                    if(reset_after_output_q) begin
                        output_last = 1;
                        reset_now = 1;
                    end
                end
                // if i_last is showing during output then assert i_ready to consume i_last
                if(i_last) begin
                    next_i_ready = 1;
                end
            end
        end
    end

    // keep this logic simple, control by using write_en
    always_comb begin
        ram_w_data = prev_max_q;
        for(int i = 0; i < POOL_SIZE; i++) begin
            if(new_data_q[i] > ram_w_data) ram_w_data = new_data_q[i];
        end
    end

    // to log data into new_data_q
    // doesn't really need reset cause new_data_q would not be writing into
    // ram unless w_en is asserted which have its own logic
    always_ff@(posedge clk) begin
        if(new_data_idx_q < POOL_SIZE)
            new_data_q[new_data_idx_q] <= i_data;
    end

    // ff
    always_ff@(posedge clk) begin
        if(reset) begin
            in_or_out_q <= 0;
            i_ready_q <= 0;
            reset_after_output_q <= '0;
            reset_after_consumed_q <= '0;
            ram_w_addr_q <= '0;
            prev_ram_r_addr_q <= '0;
            in_counter_q <= '0;
            per_pool_counter_q <= '0;
            row_counter_q <= '0;
            prev_max_q <= '0;
            new_data_idx_q <= '0;
        end
        else if(reset_now) begin
            in_or_out_q <= 0;
            i_ready_q <= 0;
            reset_after_output_q <= '0;
            reset_after_consumed_q <= '0;
            ram_w_addr_q <= '0;
            prev_ram_r_addr_q <= '0;
            in_counter_q <= '0;
            per_pool_counter_q <= '0;
            row_counter_q <= '0;
            prev_max_q <= '0;
            new_data_idx_q <= '0;
        end
        else begin
            in_or_out_q <= next_in_or_out;
            i_ready_q <= next_i_ready;
            reset_after_output_q <= next_reset_after_output;
            reset_after_consumed_q <= next_reset_after_consumed;
            ram_w_addr_q <= next_ram_w_addr;
            prev_ram_r_addr_q <= ram_r_addr;
            in_counter_q <= next_in_counter;
            per_pool_counter_q <= next_per_pool_counter;
            row_counter_q <= next_row_counter;
            prev_max_q <= next_prev_max;
            new_data_idx_q <= next_new_data_idx;
        end
    end

    always_ff@(posedge clk) begin
        if(reset) begin
            got_last_q <= 0;
        end
        else if(reset_now) begin
            got_last_q <= 0;
        end
        else begin
            // when in input mode
            if(~in_or_out_q) begin
                if(i_ready_q && i_last)
                    got_last_q <= 1;
            end
            // when in output mode just consume it
            else begin
                if(i_last)
                    got_last_q <= 1;
            end
        end
    end


    dual_port_ram #(
        .VALUE_BITS(VALUE_BITS), 
        .WIDTH(O_WIDTH)
    ) line_ram(
        .clk(clk), 
        .w_data(ram_w_data), 
        .w_addr(ram_w_addr_q),
        .w_valid(write_en),
        .r_addr(ram_r_addr), 
        .r_data(ram_r_data)
    );

endmodule 

/*
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
*/