
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
        .outport_accept_i(1'b1),

        .inport_accept_o(1'b1),
        .outport_valid_o(out_valid),
        .outport_width_o(out_data[23:16]),
        .outport_height_o(out_data[31:24]),
        .outport_pixel_x_o(out_data[6:0]),
        .outport_pixel_y_o(out_data[14:8]),
        .outport_pixel_r_o(8'b0),
        .outport_pixel_g_o(8'b0),
        .outport_pixel_b_o(8'b0),
        .idle_o(out_data[15]));
        
    assign out_data[7] = out_valid;
    // For some reason it was sending when out_valid=0 so something seems fishy, even valid-bit out[7] was zero; so really strange
    // When out_valid=(count==0) AND top-level was waiting on register + waiting on this out_valid than than it was still spamming
    assign upstream_stall = 1'b0;

endmodule 
