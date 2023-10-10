
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

module parallelize #(parameter N, DATA_BITS, DATA_PER_WORD, WORD_SIZE=32) (
    input wire clock, 
    input wire reset, //+ve synchronous reset

    input wire [ WORD_SIZE-1 : 0 ] in_data,
    input wire in_valid,

    output reg [ DATA_BITS-1 : 0 ] out_data[N],
    output reg out_valid, 

    input wire downstream_stall,
    output wire upstream_stall
);
    logic [ DATA_BITS-1 : 0 ] data_buffer[N];
    logic [$clog2(N)-1:0] data_idx;

    always_ff@(posedge clock) begin
        if (reset) begin
            data_idx <= 0;
        end
        else if (in_valid && data_idx < N) begin
            data_idx <= (data_idx + DATA_PER_WORD);
            for (int data_num = 0; data_num < DATA_PER_WORD; data_num++) begin
                if (data_idx + data_num < N) begin
                    data_buffer[data_idx + data_num] 
                    <= in_data[ data_num*DATA_BITS +: DATA_BITS ];
                end
            end
        end
        else if (!downstream_stall && data_idx>=N) begin
            data_idx <= 0;
        end
    end

    assign upstream_stall = data_idx >= N;
    assign out_valid = data_idx >= N;
    assign out_data = data_buffer;

endmodule


// Takes in a wide internal wire format (such as output of jpeg) and serializes it over multiple cycles
module serialize #(parameter N, DATA_BITS, DATA_PER_WORD, WORD_SIZE=32) (
    input wire clock, 
    input wire reset, //+ve synchronous reset

    input wire [ DATA_BITS-1 : 0 ] in_data[N],
    input wire in_valid,

    output reg [ WORD_SIZE-1 : 0 ] out_data,
    output reg out_valid, 

    input wire downstream_stall,
    output wire upstream_stall
);
    logic buffer_valid;
    logic [ DATA_BITS-1 : 0 ] data_buffer[N];
    logic [$clog2(N)-1:0] data_idx;

    always_ff@(posedge clock) begin
        if (reset) begin
            buffer_valid <= 0;
            data_idx <= 0;
        end
        else if (in_valid && !buffer_valid) begin
            data_idx <= 0;
            data_buffer <= in_data;
            buffer_valid <= 1;
        end 
        else if (!downstream_stall && buffer_valid) begin
            data_idx <= (data_idx + DATA_PER_WORD);
            if (data_idx+DATA_PER_WORD >= N) begin
                data_idx <= 0;
                buffer_valid <= 0;
            end
        end
    end

    assign upstream_stall = buffer_valid;
    assign out_valid = buffer_valid;

    always_comb begin
        out_data = 0;
        for (int data_num = 0; data_num < DATA_PER_WORD; data_num++) begin
            if (data_idx + data_num < N) begin
                out_data[ data_num*DATA_BITS +: DATA_BITS ] = data_buffer[data_idx + data_num];
            end
        end
    end
    //assign out_data = data_buffer[data_idx];

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
 