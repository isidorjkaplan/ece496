
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
    logic reset_i;
    // Assign bit 31 of in_data to hard reset the circuit
    assign reset_i = reset || (in_data[31] && in_valid);

    logic cntrl_last;
    localparam TAG_WIDTH = 6;
    logic [TAG_WIDTH-1:0] img_tag;

    always_ff@(posedge clock) begin
        if (reset_i) begin
            cntrl_last <= 0;
            img_tag <= 0;
        end else if (in_valid && !upstream_stall) begin
            // 30th bit of in_data is reserved for last signal
            cntrl_last <= in_data[30];
            img_tag <= in_data[29:24];
        end
    end



    localparam VALUES_PER_WORD = 1;
    localparam VALUE_BITS = 8;
    localparam INPUT_WIDTH = 28, INPUT_CHANNELS=1;
    localparam OUTPUT_WIDTH = 1, OUTPUT_CHANNELS = 10;

    logic [VALUE_BITS - 1 : 0] in_row_i[INPUT_WIDTH][INPUT_CHANNELS];
    logic in_row_valid_i, in_row_accept_o, in_row_last_i;
    logic [TAG_WIDTH-1:0] in_row_tag_i;
    assign in_row_tag_i = img_tag;
    
    logic [VALUE_BITS - 1 : 0] out_row_o[OUTPUT_WIDTH][OUTPUT_CHANNELS];
    logic out_row_valid_o;
    logic out_row_accept_i;
    logic out_row_last_o;
    logic [TAG_WIDTH-1:0] out_row_tag_o;

    // INPUT -> LAYER0 GLUE LOGIC
    logic [VALUE_BITS-1 : 0] in_row_par[INPUT_WIDTH*INPUT_CHANNELS];

    logic upstream_stall_paralellize;
    assign upstream_stall = upstream_stall_paralellize && !reset_i;
    assign in_row_last_i = cntrl_last;

    parallelize #(.N(INPUT_WIDTH*INPUT_CHANNELS), .DATA_BITS(VALUE_BITS), .DATA_PER_WORD(VALUES_PER_WORD), .WORD_SIZE(24)) par2ser(
        .clock(clock), .reset(reset_i), 
        .in_data(in_data[23:0]), .in_valid(in_valid), 
        .out_data(in_row_par), .out_valid(in_row_valid_i),
        .downstream_stall(!in_row_accept_o), .upstream_stall(upstream_stall_paralellize)
    );
    
    always_comb begin
        for (int x = 0; x < INPUT_WIDTH; x++) begin
            for (int in_ch = 0; in_ch < INPUT_CHANNELS; in_ch++) begin
                in_row_i[x][in_ch] = in_row_par[x + in_ch*INPUT_WIDTH];
            end
        end
    end


    cnn_top cnn(
        // General
        .clock_i(clock), .reset_i(reset_i),
        // INPUT INFO
        .in_row_i(in_row_i),
        .in_row_valid_i(in_row_valid_i),
        .in_row_accept_o(in_row_accept_o),
        .in_row_last_i(in_row_last_i),
        .in_row_tag_i(in_row_tag_i),
        // OUT INFO
        .out_row_o(out_row_o),
        .out_row_valid_o(out_row_valid_o),
        .out_row_accept_i(out_row_accept_i),
        .out_row_last_o(out_row_last_o),
        .out_row_tag_o(out_row_tag_o)
    );

    // POOL1 -> OUT glue logic

    logic [VALUE_BITS-1 : 0] out_row_par[OUTPUT_WIDTH*OUTPUT_CHANNELS];
    wire upstream_stall_serial;
    assign out_row_accept_i = !upstream_stall_serial;
    serialize #(.N(OUTPUT_WIDTH*OUTPUT_CHANNELS), .DATA_BITS(VALUE_BITS), .DATA_PER_WORD(VALUES_PER_WORD), .WORD_SIZE(24)) ser2par(
        .clock(clock), .reset(reset_i), 
        .in_data(out_row_par), .in_valid(out_row_valid_o),
        .out_data(out_data[23:0]), .out_valid(out_valid),
        .downstream_stall(downstream_stall), .upstream_stall(upstream_stall_serial)
    );


    always_ff@(posedge clock) begin
        if (reset_i) begin
            out_data[31:24] <= 0;
        end else if (out_row_valid_o && out_row_accept_i) begin
            out_data[31] <= 0; //this bit is never 1
            out_data[30] <= out_row_last_o;
            out_data[29:24] <= out_row_tag_o;
        end
    end

    always_comb begin
        for (int x = 0; x < OUTPUT_WIDTH; x++) begin
            for (int out_ch = 0; out_ch < OUTPUT_CHANNELS; out_ch++) begin
                out_row_par[x + out_ch*OUTPUT_WIDTH] = out_row_o[x][out_ch];
            end
        end
    end


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
 