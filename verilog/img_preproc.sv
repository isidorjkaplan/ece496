
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

        .inport_accept_o(out_data[0]),
        .outport_valid_o(out_data[1]),
        .outport_width_o(out_data[23:16]),
        .outport_height_o(out_data[31:24]),
        .outport_pixel_x_o(1'b0),
        .outport_pixel_y_o(1'b0),
        .outport_pixel_r_o(8'b0),
        .outport_pixel_g_o(8'b0),
        .outport_pixel_b_o(8'b0),
        .idle_o(out_data[2]));

    // For debugging so we can see a status output ~5 sec even if jpeg_core did not send a valid packet
    // This can be identified since out[7]=valid=0 on such a packet
    logic [27 : 0 ] count;
    always_ff @ (posedge clock) begin
        count <= (count + 1);
    end

    assign out_data[3] = (count == 0);

    assign out_valid = out_data[3] || out_data[1];
    
    assign upstream_stall = 1'b0;

endmodule 
