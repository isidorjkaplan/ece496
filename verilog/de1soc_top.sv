
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
    input wire reset, //+ve synchronous soft_reset

    input wire [ 31 : 0 ] in_data,
    input wire in_valid,
    output wire in_ready, 
    
    output reg [ 31 : 0 ] out_data,
    output reg out_valid, 
    input wire out_ready
);
    // Automatic reset logic

    localparam SOFT_RESET_BITS=28;    
    logic soft_reset;
    logic [SOFT_RESET_BITS-1:0] soft_reset_counter_q;
    always_ff@(posedge clock) begin
        // If data goes in or out, or we get a hard reset, than reset soft counter
        if (   (in_valid && in_ready) || (out_valid && out_ready) || reset ) begin
            // Initially MAX for the given bit width. That is to say we got data so go back to max time until reset
            soft_reset_counter_q <= (1<<SOFT_RESET_BITS)-1;
        end else begin 
            // Decrement the counter
            soft_reset_counter_q <= (soft_reset_counter_q - 1);
        end
    end
    // If the counter hits zero it means that we went a super long time without ever recieving an input 
    // or output, that means do a soft reset. Also if hard reset pass that along to the modules
    assign soft_reset = (soft_reset_counter_q==0) || reset;
    //assign soft_reset = reset; // disable for now

    // Jpeg logic

    localparam MAX_JPEG_WORDS = 1024;
    localparam WIDTH = 28;
    
    logic [$clog2(MAX_JPEG_WORDS+1)-1:0] counter_q;
    logic send_jpeg_last_q;



    always_ff@(posedge clock) begin
        if (soft_reset) begin
            counter_q <= 0;
            send_jpeg_last_q <= 0;
        end else if (in_valid && in_ready) begin
            if (counter_q == 0) begin
                counter_q <= in_data;
                //$display("de1soc_top.sv: Setting counter to %d", in_data);
            end else begin
                counter_q <= (counter_q-1);
                send_jpeg_last_q <= (counter_q==1);
                //$display("de1soc_top.sv: Reading in word %x with counter=%d", in_data, counter_q);
            end
        end
        // soft_reset after one cycle 
        if (send_jpeg_last_q && in_ready) send_jpeg_last_q <= 0;
    end


    logic [7:0] jpeg_out[3];
    logic jpeg_out_valid;
    logic jpeg_out_last;
    logic model_ready;

    jpeg_decoder #(.WIDTH(WIDTH), .HEIGHT(WIDTH),.MAX_JPEG_WORDS(MAX_JPEG_WORDS))jpeg(
        .clk(clock), .reset(soft_reset),
        .in_data(in_data), .in_valid((in_valid && (counter_q!=0)) || send_jpeg_last_q), 
        .in_ready(in_ready), .in_last(send_jpeg_last_q),
        .out_data(jpeg_out), .out_valid(jpeg_out_valid), 
        .out_last(jpeg_out_last), .out_ready(model_ready)
    );

    // Debugging loop
    // initial begin
    //     @(posedge clock);
    //     @(negedge soft_reset);
    //     @(posedge clock);
    //     while (1) begin
    //         for (int y = 0; y < WIDTH; y++) begin
    //             while (!jpeg_out_valid || !model_ready) begin
    //                 @(posedge clock);
    //                 #1;
    //             end
    //             $write("y=%3d: ", y);
    //             for (int x = 0; x < WIDTH; x++) begin
    //                 #1;
    //                 while (!jpeg_out_valid || !model_ready) begin
    //                     @(posedge clock);
    //                     #1;
    //                 end
    //                 $write("%1d", jpeg_out[0]>128);
    //                 @(posedge clock);
    //                 #1;
    //             end
    //             $write("\n");
    //         end
    //     end
    //     $write("\n");
    // end

    localparam VALUE_BITS=18;
    localparam OUT_CHANNELS=10;
    localparam Q_FORMAT_N = 8;
    
    logic signed [VALUE_BITS-1:0] to_model[1];
    logic signed [VALUE_BITS-1:0] from_model[OUT_CHANNELS];

    assign to_model[0] = signed'({1'b0, jpeg_out[0]});

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
        .in_valid(jpeg_out_valid),
        .in_last(jpeg_out_last),
        .in_ready(model_ready),

        .out_data(from_model),
        .out_valid(model_out_valid),
        .out_last(model_out_last),
        .out_ready(!upstream_stall_serial)
    );

    // initial begin
    //     while(1) begin
    //         @(posedge clock);

    //         if (model_out_valid && !upstream_stall_serial) begin
    //             $write("Model Classification: ");
    //             for (int i = 0; i < OUT_CHANNELS; i++) begin
    //                 $write("p(%d)=%d, ", i, from_model[i]);
    //             end
    //             $write("\n");
    //         end
    //     end
    // end

    serialize #(.N(OUT_CHANNELS), .DATA_BITS(VALUE_BITS)) ser2par(
        .clock(clock), .reset(soft_reset), 
        .in_data(from_model), .in_valid(model_out_valid),
        .in_last(model_out_last), .out_last(),
        .out_data(out_data), .out_valid(out_valid),
        .downstream_stall(!out_ready), .upstream_stall(upstream_stall_serial)
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
 