
// This is the start of our actual project's DE1SOC adapter
module img_preproc_top(
    input wire clock, 
    input wire reset, //+ve synchronous reset

    input wire [ 31 : 0 ] in_data,
    input wire in_valid,

    output reg [ 31 : 0 ] out_data,
    output reg out_valid, 

    input wire downstream_stall,
    output wire upstream_stall
);

    // // Inputs
    // ,input  [ 31:0]  inport_data_i
    // ,input  [  3:0]  inport_strb_i
    // // Outputs
    // ,output [ 15:0]  outport_width_o
    // ,output [ 15:0]  outport_height_o
    // ,output [ 15:0]  outport_pixel_x_o
    // ,output [ 15:0]  outport_pixel_y_o
    // ,output [  7:0]  outport_pixel_r_o
    // ,output [  7:0]  outport_pixel_g_o
    // ,output [  7:0]  outport_pixel_b_o
    
    jpeg_core jpeg( 
        .clk_i(clock), .rst_i(reset),
        .inport_valid_i(in_valid),
        .inport_data_i(in_data),
        .inport_strb_i(4'hf), //all bytes are valid (for now)
        .outport_accept_i(~downstream_stall),

        .inport_accept_o(~upstream_stall),
        .outport_valid_o(out_valid),
        .outport_width_o(15'b0),
        .outport_height_o(15'b0),
        .outport_pixel_x_o(out_data[15:0]),
        .outport_pixel_y_o(out_data[31:16]),
        .outport_pixel_r_o(8'b0),
        .outport_pixel_g_o(8'b0),
        .outport_pixel_b_o(8'b0),
        .idle_o(1'b0));
endmodule 
