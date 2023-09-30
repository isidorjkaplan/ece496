
// This is the start of our actual project's DE1SOC adapter
module de1soc_top(
    input wire clock, 
    input wire reset, //+ve synchronous reset

    input wire [ 31 : 0 ] in_data,
    input wire in_valid,

    output reg [ 31 : 0 ] out_data,
    output reg out_valid, 

    input wire downstream_stall,
    output wire upstream_stall
);

    logic [9:0] clock_div_counter;
    logic CLOCK_DIV;
    always@(posedge clock) begin
        clock_div_counter <= (clock_div_counter+1);
    end
    assign CLOCK_DIV = clock_div_counter[9];

    logic out_valid_slow;
    logic upstream_stall_slow;

    // Stall upstream reads unless it is on the cycle where we are going to actually see the positive edge
    // or if we are stalling anyways from our slower logic
    assign upstream_stall = (clock_div_counter != 10'b0111111111) || upstream_stall_slow;
    // If both clock domains recognize this clock edge, and the output is valid;
    assign out_valid = (clock_div_counter == 10'b0111111111) && out_valid_slow;

    img_preproc_top preproc_mod(.clock(CLOCK_DIV), .reset(reset), 
        .in_data(in_data), .in_valid(in_valid), .out_data(out_data), .out_valid(out_valid_slow), 
        .downstream_stall(downstream_stall), .upstream_stall(upstream_stall_slow));
        
endmodule 