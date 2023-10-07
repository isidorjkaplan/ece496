
// This module recieves an image over in_data; fully buffers it; and than streams it out in rapid-succession
module img_buffer(
    input wire clock, 
    input wire reset, //+ve synchronous reset

    input wire [ 31 : 0 ] in_data,
    input wire in_valid,

    output reg [ 31 : 0 ] out_data,
    output reg out_valid, 

    input logic downstream_stall,
    output logic upstream_stall
);
    parameter POW2_N = 8;
    
    // Create a ram and control signals
    logic [ POW2_N-1 : 0 ] count_q;
    logic [ POW2_N-1 : 0 ] total_count_q;
    logic [ 31 : 0 ] data_q;
    typedef enum {
        S_IDLE,
        S_RECV,
        S_SEND_START,
        S_SEND
    } e_state;
    e_state state_q;


    // Non register signals
    logic write_en;
    logic [ POW2_N-1 : 0 ] ram_addr;
    logic [ POW2_N-1 : 0 ] next_count;
    logic [ POW2_N-1 : 0 ] next_total_count;
    logic [ 31 : 0 ] ram_out;
    logic [ 31 : 0 ] next_data;
    e_state next_state;

    buffer_ram #( .ADDR_BITS(POW2_N) ) ram(.clk_i(clock),.addr_i(ram_addr), .data_i(in_data), .wr_i(write_en), .data_o(ram_out));
    
    // The combinational logic for next state
    always_comb begin
        write_en = 0;
        ram_addr = 0;
        upstream_stall = 1;
        out_data = 0;
        out_valid = 0;

        // Registers who hold their values
        next_count = count_q;
        next_total_count = total_count_q;
        next_data = data_q;
        next_state = state_q;

        case (state_q)
            S_IDLE: begin
                upstream_stall = 0;
                if (in_valid) begin
                    next_total_count = (in_data>>2) + (in_data[1:0]!=0);
                    next_data = in_data;
                    next_count = 0;
                    next_state = S_RECV;
                end
            end
            S_RECV: begin
                upstream_stall = 0;
                if (in_valid) begin
                    ram_addr = count_q;
                    write_en = 1;
                    next_count = count_q + 1;
                    if (next_count >= total_count_q) begin
                        next_state = S_SEND_START;
                    end
                end
            end
            S_SEND_START: begin
                // Wait a cycle with ram_addr = 0 so that ram_out fetches correct value
                ram_addr = 0;
                next_state = S_SEND;
                next_count = 0;
            end
            S_SEND: begin
                out_valid = 1;
                out_data = data_q;
                ram_addr = count_q;
                if (!downstream_stall) begin
                    next_data = ram_out;
                    next_count = count_q + 1;
                    ram_addr = next_count;

                    if (count_q >= total_count_q) begin
                        next_state = S_IDLE;
                        next_count = 0;
                        next_total_count = 0;
                        next_data = 0;
                    end
                end
            end
            default: begin

            end
        endcase
       
        

    end

    // The synchronous logic
    always_ff@(posedge clock) begin
        if (reset) begin
            total_count_q <= 0;
            count_q <= 0;
            state_q <= S_IDLE;
            data_q <= 0;
        end else begin
            count_q <= next_count;
            total_count_q <= next_total_count;
            state_q <= next_state;
            data_q <= next_data;
        end
    end

endmodule 

// Adapted from jpeg_idct_ram_dp.v
module buffer_ram #(parameter WIDTH = 32, parameter ADDR_BITS = 8)

(
    // Inputs
     input           clk_i
    ,input  [  ADDR_BITS-1:0]  addr_i
    ,input  [ WIDTH-1:0]  data_i
    ,input           wr_i

    // Outputs
    ,output [ WIDTH-1:0]  data_o
);

    reg [WIDTH-1:0]   ram [1<<ADDR_BITS];
   
    reg [WIDTH-1:0] ram_read_q;

    // Synchronous write
    always @ (posedge clk_i)
    begin
        if (wr_i)
            ram[addr_i] <= data_i;

        ram_read_q <= ram[addr_i];
    end

    assign data_o = ram_read_q;
endmodule
