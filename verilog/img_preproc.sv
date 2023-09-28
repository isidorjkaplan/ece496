
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

    //JPEG CORE PORTS

    logic [ 15:0]  outport_width_o;
    logic [ 15:0]  outport_height_o;
    logic [ 15:0]  outport_pixel_x_o;
    logic [ 15:0]  outport_pixel_y_o;
    logic [  7:0]  outport_pixel_r_o;
    logic [  7:0]  outport_pixel_g_o;
    logic [  7:0]  outport_pixel_b_o ; 
    logic outport_valid_o;
    logic idle_o;
    logic inport_accept_o;

    // WORD COUNT LOGIC

    logic [31 : 0] word_count;
    always_ff @ (posedge clock) begin
        // Reset by setting count to zero, implying we are not actively recieving anything
        if (reset) begin
            word_count <= 0;
        end
        // If we are not actively in an image and we randomly recieve a word, that is the start of new image
        else if (word_count == 0 && in_valid) begin
            word_count <= in_data;
        end
        // We are processing and recieved another byte so process it 
        else if (in_valid && inport_accept_o) begin
            word_count <= (word_count - 1);
        end
    end

    // TIMEOUT LOGIC
    // TODO; this is not gonna be in final thing
    
    parameter TIMEOUT_CYCLES = 32'h2FAF080; // 50 MILLION cycles = 1 second
    logic [31 : 0 ] timeout_count;
    logic timeout;
    assign timeout = (timeout_count==0);
    always_ff @ (posedge clock) begin
        if (reset) begin
            timeout_count <= 0;
        end
        else if (timeout_count != 0) begin
            timeout_count <= (timeout_count - 1);
        end
        //TODO; also must only do this when we initially set word_count
        else if (timeout_count == 0) begin
            timeout_count <= TIMEOUT_CYCLES;
        end
    end

    // JPEG declaration

    jpeg_core jpeg( 
        .clk_i(clock), .rst_i(reset || (in_valid && word_count==0 && in_data==0)),
        .inport_valid_i(in_valid && (word_count != 0)), //if we put 1'b1 than inport_accept goes high
        .inport_data_i(in_data),
        .inport_strb_i(4'hf), //all bytes are valid (for now)
        .inport_last_i(word_count==1 && in_valid), //last cycle of valid data  
        .outport_accept_i(!downstream_stall && outport_valid_o), //ack when not stalling and we have valid outport

        // For now putting this here since we do logic with it seperately
        .inport_accept_o(inport_accept_o),
        .outport_valid_o(outport_valid_o),
        .outport_width_o(outport_width_o),
        .outport_height_o(outport_height_o),
        .outport_pixel_x_o(outport_pixel_x_o),
        .outport_pixel_y_o(outport_pixel_y_o),
        .outport_pixel_r_o(outport_pixel_r_o),
        .outport_pixel_g_o(outport_pixel_g_o),
        .outport_pixel_b_o(outport_pixel_b_o),
        .idle_o(idle_o));

    // JPEG CORE ASSIGNMENTS
    // bug in this, it was glitching, when we set to zero it works but misses some reads.
    // WARNING: misunderstood inport_accept_o/outport_accept_o, they are handshake signals!!! 
    assign upstream_stall = (word_count==0) ? 1'b0 : !inport_accept_o; // Can always latch word size, must wait for rest

    // OUTPUT HACK

    assign out_data[31:24] = word_count;
    assign out_data[0] = inport_accept_o;
    assign out_data[1] = outport_valid_o;
    assign out_data[2] = idle_o;
    assign out_data[3] = timeout;
    // Ensure it does not get optimized away
    assign out_data[4] = ^{outport_width_o, outport_height_o, outport_pixel_x_o, outport_pixel_y_o, outport_pixel_r_o, outport_pixel_g_o, outport_pixel_b_o};
 
    // For now
    assign out_valid = outport_valid_o || timeout || inport_accept_o;

endmodule 
