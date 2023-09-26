
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
    img_preproc_top preproc_mod(.clock(clock), .reset(reset), 
        .in_data(in_data), .in_valid(in_valid), .out_data(out_data), .out_valid(out_valid), 
        .downstream_stall(downstream_stall), .upstream_stall(upstream_stall));
        
endmodule 