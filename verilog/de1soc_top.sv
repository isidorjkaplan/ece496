
// This is the start of our actual project's DE1SOC adapter
module de1soc_top(
    input wire clock, 
    input wire reset, //+ve synchronous reset

    input wire [ 127 : 0] in_data,
    input wire in_valid,

    output reg [127 : 0] out_data,
    output reg out_valid, 

    input wire upstream_stall, //1 means we are allowed to submit data
    output reg downstream_stall //1 means we are allowed to recieve data
);
    
    always_ff@(posedge clock) begin
        if (reset) begin
            out_data <= 0;
            out_valid <= 0;
            downstream_stall <= 1;
        end
        else if (!upstream_stall) begin
            out_data <= in_data;
            out_valid <= in_valid;
            downstream_stall <= in_valid;
        end
        else begin 
            if (in_valid) begin
                out_data <= in_data;
                out_valid <= 1;
                downstream_stall <= 1; //we latched a value and have to wait until its read
            end
        end 
    end

endmodule 