
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
    
    logic [31:0] to_model[1];
    logic [31:0] from_model[10];
    assign to_model[0] = in_data;
    assign out_data = from_model[0];

    model m(
        .clk(clock),
        .reset(reset),

        .in_data(to_model),
        .in_valid(in_valid),
        .in_ready(upstream_stall),

        .out_data(from_model),
        .out_valid(out_valid),
        .out_ready(downstream_stall)
    );


endmodule 

// This just takes a value and registers it
module axi_buffer(
    input wire clock, 
    input wire reset, //+ve synchronous reset

    input wire [ 31 : 0 ] in_data,
    input wire in_valid,

    output reg [ 31 : 0 ] out_data,
    output reg out_valid, 

    input wire downstream_stall,
    output wire upstream_stall
);

    assign upstream_stall = out_valid && downstream_stall;
    
    always_ff@(posedge clock) begin
        if (reset) begin
            out_data <= 0;
            out_valid <= 0;
        end
        else if (!downstream_stall || !out_valid) begin
            out_data <= in_data;
            out_valid <= in_valid;
        end  
    end
endmodule 
 