
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

    logic [  3:0]  inport_strb_i;
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
    logic [31 : 0] byte_count;
    always_ff @ (posedge clock) begin
        // Reset by setting count to zero, implying we are not actively recieving anything
        if (reset) begin
            byte_count <= 0;
        end
        // If we are not actively in an image and we randomly recieve a word, that is the start of new image
        else if (byte_count == 0 && in_valid) begin
            byte_count <= in_data;
        end
        // We are processing and recieved another byte so process it 
        else if (in_valid && inport_accept_o) begin
            // Read an entire word (4 bytes) unless less than a full word left, in which case we are done after this read
            byte_count <= (byte_count >= 4)?(byte_count - 4):0;
        end
    end

    // JPEG declaration

    always_comb begin
        // bitmask for which words are valid, normally all of them
        inport_strb_i = 4'b1111;
        // if we are at the end of the file may only be partially valid (with MSB invalid)
        if (byte_count < 4) begin
            case(byte_count[1:0]) 
            1: inport_strb_i = 4'b0001;
            2: inport_strb_i = 4'b0011;
            3: inport_strb_i = 4'b0111;
            default: inport_strb_i = 4'b1111;
            endcase
        end
    end

    jpeg_core jpeg( 
        .clk_i(clock && (in_valid || byte_count==0)), .rst_i(reset || (in_valid && byte_count==0 && in_data==0)),
        .inport_valid_i(in_valid && (byte_count != 0)), //if we put 1'b1 than inport_accept goes high
        .inport_data_i(in_data),
        .inport_strb_i(inport_strb_i), //all bytes are valid (for now)
        .inport_last_i((byte_count>0 && byte_count <= 4 && in_valid)), //last cycle of valid data  
        .outport_accept_i(!downstream_stall), //ack when not stalling and we have valid outport

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
        .idle_o(idle_o)
        );



    // JPEG CORE ASSIGNMENTS
    // bug in this, it was glitching, when we set to zero it works but misses some reads.
    // WARNING: misunderstood inport_accept_o/outport_accept_o, they are handshake signals!!! 
    assign upstream_stall = (byte_count==0) ? 1'b0 : !inport_accept_o; // Can always latch word size, must wait for rest

    assign out_data = {outport_pixel_x_o, outport_pixel_y_o};
    assign out_valid = outport_valid_o;

endmodule 
