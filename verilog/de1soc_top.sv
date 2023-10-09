
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
    cnn_top cnn(
        .clock(clock), .reset(reset), 
        .in_data(in_data), .in_valid(in_valid), 
        .out_data(out_data), .out_valid(out_valid), 
        .downstream_stall(downstream_stall), .upstream_stall(upstream_stall)
    );
endmodule 

module parallelize #(parameter N, DATA_BITS=32) (
    input wire clock, 
    input wire reset, //+ve synchronous reset

    input wire [ DATA_BITS-1 : 0 ] in_data,
    input wire in_valid,

    output reg [ DATA_BITS-1 : 0 ] out_data[N],
    output reg out_valid, 

    input wire downstream_stall,
    output wire upstream_stall
);
    logic [ DATA_BITS-1 : 0 ] data_buffer[N];
    logic [$clog2(N)-1:0] word_idx;

    always_ff@(posedge clock) begin
        if (reset) begin
            word_idx <= 0;
        end
        else if (in_valid && word_idx < N) begin
            word_idx <= (word_idx + 1);
            data_buffer[word_idx] <= in_data;
        end
        else if (!downstream_stall && word_idx==N) begin
            word_idx <= 0;
        end
    end

    assign upstream_stall = word_idx == N;
    assign out_valid = word_idx == N;
    assign out_data = data_buffer;

endmodule


// Takes in a wide internal wire format (such as output of jpeg) and serializes it over multiple cycles
module serialize #(parameter N, DATA_BITS=32) (
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
    logic [ DATA_BITS-1 : 0 ] data_buffer[N];
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
    assign out_data = data_buffer[word_idx];

endmodule
