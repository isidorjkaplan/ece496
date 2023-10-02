
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
    logic send_mode_q;
    logic [ 31 : 0 ] data_q;

    // Non register signals
    logic write_en;
    logic [ POW2_N-1 : 0 ] ram_addr;
    logic [ POW2_N-1 : 0 ] next_count;
    logic [ POW2_N-1 : 0 ] next_total_count;
    logic next_send_mode;
    logic [ 31 : 0 ] ram_out;
    logic [ 31 : 0 ] next_data;

    buffer_ram ram(.clk_i(clock),.addr_i(next_count), .data_i(in_data), .wr_i(write_en), .data_o(ram_out));
    
    // The combinational logic for next state
    always_comb begin
        // Combinational output logic
        out_valid = send_mode_q;
        out_data = data_q;
        upstream_stall = send_mode_q;
        // Next signals resetting
        next_count = count_q;
        next_total_count = total_count_q;
        next_send_mode = send_mode_q;
        next_data = data_q;
        write_en = 0;
        ram_addr = count_q;
        
        if (in_valid && total_count_q == 0) begin
            next_total_count = (in_data>>2) + (in_data[1:0]!=0);
            next_send_mode = 0;
            next_count = 1;
            write_en = 1;
            next_data = in_data; 
        end
        else if (!send_mode_q && in_valid) begin
            next_count = count_q + 1;
            write_en = 1;
            if (next_count > total_count_q) begin
                next_count = 1;
                next_send_mode = 1;
            end
        end
        else if (send_mode_q && !downstream_stall) begin
            next_count = count_q + 1;
            ram_addr = next_count;
            next_data = ram_out; 
            if (count_q > total_count_q) begin
                next_count = 0;
                next_send_mode = 0;
                next_total_count = 0;
                next_data = 0;
            end
        end
    end

    // The synchronous logic
    always_ff@(posedge clock) begin
        if (reset) begin
            total_count_q <= 0;
            count_q <= 0;
            send_mode_q <= 0;
            data_q <= 0;
        end else begin
            count_q <= next_count;
            total_count_q <= next_total_count;
            send_mode_q <= next_send_mode;
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
