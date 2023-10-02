
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
    parameter POW2_N = 10;

    // Create a ram and control signals
    logic [ 31 : 0 ] data_buffer_q[1<<POW2_N];
    logic [ POW2_N-1 : 0 ] data_addr_q;

    // Create the managing FSM
    logic [ POW2_N-1 : 0 ] total_bytes_q;
    logic send_mode_q;
    
    // The combinational logic for next state
    always_comb begin
        // Combinational output logic
        out_data = data_buffer_q[data_addr_q];
        out_valid = send_mode_q;
        // Stall upstream if we are actively writing out a result
        upstream_stall = send_mode_q;
    end

    // The synchronous logic
    always_ff@(posedge clock) begin
        if (reset) begin
            total_bytes_q <= 0;
            data_addr_q <= 0;
            send_mode_q <= 0;
        end
        // This is the idle case where we are waiting to start recieving a packet
        else if (in_valid && !send_mode_q && (total_bytes_q==0)) begin
            // Record the size of the packet 
            total_bytes_q <= in_data+4; // Add 4 since we must include this word
            //packet size is also part of the data that we write to next module
            data_buffer_q[data_addr_q] <= in_data; 
            //Reset the addr for rest of write
            data_addr_q <= 1; // We will start by writing to element 1 since size is written to element 0
        end
        // Code that handles the recieving mode
        else if (in_valid && !send_mode_q) begin
            data_buffer_q[data_addr_q] <= in_data;
            data_addr_q <= (data_addr_q+1);
            // If this is the last data write
            if ((data_addr_q+1)*4 >= total_bytes_q) begin
                send_mode_q <= 1; //no longer recieving; we are in transmit mode
                data_addr_q <= 0; //back to transmitting from the start of accumulated bytes
            end
        end
        // Code that handles transmitting mode incrementing
        else if (!downstream_stall && send_mode_q) begin
            data_addr_q <= (data_addr_q+1);
            if ((data_addr_q+1)*4 >= total_bytes_q) begin
                send_mode_q <= 0;
                data_addr_q <= 0;
                total_bytes_q <= 0;
            end
        end
    end

endmodule 
