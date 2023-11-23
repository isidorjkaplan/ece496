
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

    logic in_ready;
    assign upstream_stall = !in_ready;

    system_top mod(.clock(clock), .reset(reset), 
        .in_data(in_data), .in_valid(in_valid),
        .out_data(out_data), .out_valid(out_valid),
        .in_ready(in_ready), .out_ready(!downstream_stall)
    );
endmodule 

module system_top(
    input wire clock, 
    input wire reset, //+ve synchronous reset

    input wire [ 31 : 0 ] in_data,
    input wire in_valid,
    output wire in_ready, 
    
    output reg [ 31 : 0 ] out_data,
    output reg out_valid, 
    input wire out_ready
);

    logic [7:0] jpeg_out[3];
    logic jpeg_out_valid;
    logic jpeg_out_last;
    logic model_ready;

    jpeg_decoder jpeg(
        .clk(clock), .reset(reset),
        .in_data(in_data), .in_valid(in_valid), .in_ready(in_ready),
        .out_data(jpeg_out), .out_valid(jpeg_out_valid), 
        .out_last(jpeg_out_last), .out_ready(model_ready)
    );

    localparam VALUE_BITS=18;
    localparam OUT_CHANNELS=10;
    localparam Q_FORMAT_N = 8;
    
    logic signed [VALUE_BITS-1:0] to_model[1];
    logic signed [VALUE_BITS-1:0] from_model[OUT_CHANNELS];

    assign to_model[0] = signed'(jpeg_out[0]<<Q_FORMAT_N);

    logic model_out_valid;
    logic model_out_last;

    model #(
        .VALUE_BITS(VALUE_BITS),
        .VALUE_Q_FORMAT_N(8),
        .INPUT_WIDTH(28), 
        .INPUT_CHANNELS(1), 
        .OUTPUT_CHANNELS(OUT_CHANNELS)
    )m(
        .clk(clock),
        .reset(soft_reset),

        .in_data(to_model),
        .in_valid(in_valid && !soft_reset),
        .in_last(jpeg_out_last),
        .in_ready(model_ready),

        .out_data(from_model),
        .out_valid(model_out_valid),
        .out_last(model_out_last),
        .out_ready(!upstream_stall_serial)
    );

    serialize #(.N(OUT_CHANNELS), .DATA_BITS(VALUE_BITS), .WORD_SIZE(29)) ser2par(
        .clock(clock), .reset(soft_reset), 
        .in_data(from_model), .in_valid(model_out_valid),
        .in_last(model_out_last), .out_last(),
        .out_data(out_data), .out_valid(out_valid),
        .downstream_stall(!out_ready), .upstream_stall(upstream_stall_serial)
    );
endmodule 


// This is the start of our actual project's DE1SOC adapter
module de1soc_top_nojpeg(
    input wire clock, 
    input wire reset, //+ve synchronous reset

    input wire [ 31 : 0 ] in_data,
    input wire in_valid,
    
    output reg [ 31 : 0 ] out_data,
    output reg out_valid, 

    input wire downstream_stall, 
    output wire upstream_stall
);
    localparam VALUE_BITS=18;
    localparam OUT_CHANNELS=10;

    logic signed [VALUE_BITS-1:0] to_model[1];
    logic signed [VALUE_BITS-1:0] from_model[OUT_CHANNELS];
    assign to_model[0] = signed'(in_data[VALUE_BITS-1:0]); //truncate away upper bits
    
    //TODO update reset to have soft reset coming from in_data

    logic model_ready;
    logic model_out_valid;
    logic model_out_last;

    logic soft_reset;
    assign soft_reset = reset || in_data[31]; // Can write a word which does a soft-reset
    assign upstream_stall = !model_ready && !soft_reset; // pass model stalling onwards, but also always accept a reset request

    logic upstream_stall_serial;

    model #(
        .VALUE_BITS(VALUE_BITS),
        .VALUE_Q_FORMAT_N(8),
        .INPUT_WIDTH(28), 
        .INPUT_CHANNELS(1), 
        .OUTPUT_CHANNELS(OUT_CHANNELS)
    )m(
        .clk(clock),
        .reset(soft_reset),

        .in_data(to_model),
        .in_valid(in_valid && !soft_reset),
        .in_last(in_data[30] && in_valid),
        .in_ready(model_ready),

        .out_data(from_model),
        .out_valid(model_out_valid),
        .out_last(model_out_last),
        .out_ready(!upstream_stall_serial)
    );

    serialize #(.N(OUT_CHANNELS), .DATA_BITS(VALUE_BITS), .WORD_SIZE(29)) ser2par(
        .clock(clock), .reset(soft_reset), 
        .in_data(from_model), .in_valid(model_out_valid),
        .in_last(model_out_last), .out_last(),
        .out_data(out_data), .out_valid(out_valid),
        .downstream_stall(downstream_stall), .upstream_stall(upstream_stall_serial)
    );

endmodule 


// Takes in a wide internal wire format (such as output of jpeg) and serializes it over multiple cycles
module serialize #(parameter N, DATA_BITS, WORD_SIZE=32) (
    input wire clock, 
    input wire reset, //+ve synchronous reset

    input logic signed  [ DATA_BITS-1 : 0 ] in_data[N],
    input wire in_valid,
    input wire in_last,

    output reg [ WORD_SIZE-1 : 0 ] out_data,
    output reg out_valid, 
    output reg out_last,

    input wire downstream_stall,
    output wire upstream_stall
);
    logic buffer_valid;
    logic signed [ DATA_BITS-1 : 0 ] data_buffer[N];
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
            data_idx <= (data_idx + 1);
            if (data_idx == N-1) begin
                data_idx <= 0;
                buffer_valid <= 0;
            end
        end
    end

    assign out_last = in_last && (data_idx == N-1);

    assign upstream_stall = buffer_valid;
    assign out_valid = buffer_valid;
    assign out_data = unsigned'(data_buffer[data_idx]);
    
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
 