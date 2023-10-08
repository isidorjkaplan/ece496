
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

endmodule 


// Takes in a wide internal wire format (such as output of jpeg) and serializes it over multiple cycles
module serialize #(parameter N=5) (
    input wire clock, 
    input wire reset, //+ve synchronous reset

    input wire [ 31 : 0 ] in_data[N],
    input wire in_valid,

    output reg [ 31 : 0 ] out_data,
    output reg out_valid, 

    input wire downstream_stall,
    output wire upstream_stall
);
    logic buffer_valid;
    logic [ 31 : 0 ] data_buffer[N];
    logic [$clog2(N)-1:0] word_idx;

    always_ff@(posedge clock) begin
        if (reset) begin
            buffer_valid <= 0;
            word_idx <= 0;
        end
        else if (in_valid && !buffer_valid) begin
            word_idx <= 0;
            data_buffer <= in_data;
            buffer_valid <= 1;
        end 
        else if (!downstream_stall) begin
            word_idx <= (word_idx + 1);
            if (word_idx == N-1) begin
                word_idx <= 0;
                buffer_valid <= 0;
            end
        end
    end

    assign upstream_stall = buffer_valid;
    assign out_valid = buffer_valid;
    assign out_data = in_data[word_idx];

endmodule
