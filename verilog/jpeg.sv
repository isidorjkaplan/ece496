// Input is streamed as a jpeg file 
// Output is streamed in row-major order 
module jpeg_decoder #(
    parameter WIDTH = 28,
    parameter HEIGHT = 28,
    parameter MAX_JPEG_WORDS = 1024
)(
    // General signals
    input clk, 
    input reset,
    // next row logic
    input   logic        [31 : 0]  in_data,
    input   logic                  in_last,
    input   logic                  in_valid,
    output  logic                  in_ready,
    // output row valid 
    output  logic         [7 : 0] out_data[3], // RGBA 7-bit
    output  logic                 out_valid,
    output  logic                 out_last,
    input   logic                 out_ready
);    
    localparam VALUE_BITS = 8;
    localparam WORD_SIZE = 32;

    logic [$clog2(MAX_JPEG_WORDS-1)-1:0] write_byte_idx;
    logic [$clog2(MAX_JPEG_WORDS-1)-1:0] read_byte_idx;

    logic [WORD_SIZE-1:0] read_word;

    ram_1d #(.VALUE_BITS(WORD_SIZE), .WIDTH(MAX_JPEG_WORDS)) img_buffer(
        .clk(clk), 
        .w_data(in_data), 
        .w_addr(write_byte_idx),
        .w_valid(in_valid),
        .r_addr(read_byte_idx),
        .r_data(read_word)
    );

    // DUT signals

    logic          inport_valid_i;
    logic [ 31:0]  inport_data_i;
    logic [  3:0]  inport_strb_i;
    logic          inport_last_i;
    logic          outport_accept_i;
    logic          inport_accept_o;
    logic          outport_valid_o;
    logic [ 15:0]  outport_width_o;
    logic [ 15:0]  outport_height_o;
    logic [ 15:0]  outport_pixel_x_o;
    logic [ 15:0]  outport_pixel_y_o;
    logic [  7:0]  outport_pixel_r_o;
    logic [  7:0]  outport_pixel_g_o;
    logic [  7:0]  outport_pixel_b_o;
    logic          idle_o;


    // GLUE 

    always_comb begin

    end

    always_ff @(posedge clk) begin

    end


    // DUT
    jpeg_core dut(
        //Inputs
        .clk_i(clk),
        .rst_i(reset),
        .inport_valid_i(inport_valid_i),
        .inport_data_i(inport_data_i),
        .inport_strb_i(inport_strb_i),
        .inport_last_i(inport_last_i),
        .outport_accept_i(outport_accept_i),
        // Outputs
        .inport_accept_o(inport_accept_o),
        .outport_valid_o(outport_valid_o),
        .outport_width_o(outport_width_o),
        .outport_height_o(outport_height_o),
        .outport_pixel_x_o(outport_pixel_x_o),
        .outport_pixel_y_o(outport_pixel_y_o),
        .outport_pixel_r_o(outport_pixel_r_o),
        .outport_pixel_g_o(outport_pixel_g_o),
        .outport_pixel_b_o(outport_pixel_b_o),
        .idle_o(idle_o)
    );


endmodule

module ram_2d #(
    parameter VALUE_BITS, 
    parameter WIDTH,
    parameter HEIGHT
)(
    input   logic                           clk,
    
    // write interface
    input   logic [VALUE_BITS-1:0]          w_data,    
    input   logic [$clog2(WIDTH-1)-1:0]     w_addr_x,
    input   logic [$clog2(HEIGHT-1)-1:0]    w_addr_y,
    input   logic                           w_valid,

    // read interface
    input   logic [$clog2(WIDTH-1)-1: 0]    r_addr_x,
    input   logic [$clog2(HEIGHT-1)-1: 0]   r_addr_y,
    output  logic [VALUE_BITS-1:0]          r_data
);

    logic [VALUE_BITS-1:0] read_vals[HEIGHT];

    genvar i;
    generate
        for (i = 0; i < HEIGHT; i++) begin : rams
            ram_1d #(.VALUE_BITS(VALUE_BITS), .WIDTH(WIDTH)) mod(
                .clk(clk), 
                .w_data(w_data),
                .w_addr(w_addr_x), 
                .w_valid(w_addr_y == i),

                .r_addr(r_addr_x),
                .r_data(read_vals[i])  
            );
        end
    endgenerate

    assign r_data = read_vals[r_addr_y];
endmodule 


// A dual-port ram with word-size of VALUE_BITS, and WIDTH elements
module ram_1d #(
    parameter VALUE_BITS, 
    parameter WIDTH
)(
    input   logic                           clk,
    
    // write interface
    input   logic [VALUE_BITS-1:0]          w_data,    
    input   logic [$clog2(WIDTH-1)-1:0]       w_addr,
    input   logic                           w_valid,

    // read interface
    input   logic [$clog2(WIDTH-1)-1: 0]      r_addr,
    output  logic [VALUE_BITS-1:0]          r_data
);
    // The actual ram
    logic [VALUE_BITS-1:0] ram[WIDTH];
    // All operations are synchronous
    always_ff@(posedge clk) begin
        // read
        r_data <= ram[r_addr];
        // write
        if (w_valid) begin
            ram[w_addr] <= w_data;
        end
    end
endmodule