

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
    //debug_tap_top dut(.clock(clock), .reset(reset), 
    //    .in_data(in_data), .in_valid(in_valid), .out_data(out_data), .out_valid(out_valid), 
    //    .downstream_stall(downstream_stall), .upstream_stall(upstream_stall));

    assign upstream_stall = 1'b0;

    de1soc_tb_syn tb(.clock(clock), .reset(reset || in_valid), .out_data(out_data), .out_valid(out_valid), .downstream_stall(downstream_stall));   
endmodule 

// This is the start of our actual project's DE1SOC adapter
module debug_tap_top(
    input wire clock, 
    input wire reset, //+ve synchronous reset

    input wire [ 31 : 0 ] in_data,
    input wire in_valid,

    output reg [ 31 : 0 ] out_data,
    output reg out_valid, 

    input wire downstream_stall,
    output wire upstream_stall
);
    logic [31 : 0] conf_reg;
    always_ff@(posedge clock) begin
        if (reset) begin
            conf_reg <= 0;
        end else if (conf_reg == 0 && in_valid) begin
            conf_reg <= in_data;
        end
    end


    logic [31 : 0] debug_signals[31:0];
    logic [23 : 0] debug_conditions;

    wire [31:0] dut_out_data;
    wire dut_out_valid;

    img_preproc_top img_preproc_top(.clock(clock), .reset(reset), 
        .in_data(in_data), .in_valid(in_valid && conf_reg != 0), .out_data(dut_out_data), .out_valid(dut_out_valid), 
        .downstream_stall(downstream_stall), .upstream_stall(upstream_stall), 
        .debug_signals(debug_signals), .debug_conditions(debug_conditions));


    wire [23:0] raise_output_bitmask = conf_reg[31:8];
    wire [8:0] output_select = conf_reg[7:0];

    assign out_data = debug_signals[output_select];
    assign out_valid = |(raise_output_bitmask & debug_conditions);
endmodule 


// This is the start of our actual project's DE1SOC adapter
module clock_slowdown_top(
    input wire clock, 
    input wire reset, //+ve synchronous reset

    input wire [ 31 : 0 ] in_data,
    input wire in_valid,

    output reg [ 31 : 0 ] out_data,
    output reg out_valid, 

    input wire downstream_stall,
    output wire upstream_stall
);
    parameter DIV_N = 10;
    logic [DIV_N-1:0] clock_div_counter;
    logic clock_div;
    always@(posedge clock) begin
        clock_div_counter <= (clock_div_counter+1);
    end
    assign clock_div = clock_div_counter[DIV_N-1];


    logic reset_div;
    logic reset_div_done;
    initial reset_div_done = 0;
    initial reset_div = 0;
    // Block for telling fast domain when it can lower reset signal
    always@(posedge clock_div) begin
        // If we are currently in reset mode but reset is actually over then clear it
        if (reset==0 && reset_div) begin
            reset_div_done <= 1;
        end
        // If we are not in reset mode make sure reset_div_done is not set to high
        else if (reset_div_done) begin
            reset_div_done <= 0;
        end
    end
    // Block for updating the slow-domain reset 
    always@(posedge clock) begin
        // If high-domain reset is true than record a reset until its cleard by low-domain
        if (reset) begin
            reset_div <= 1;
        // If slow-domain has recorded that it has seen the reset than clear it from slow domain
        end else if (reset_div_done) begin
            reset_div <= 0;
        end
    end

    logic out_valid_slow;
    logic upstream_stall_slow;

    localparam cycle_before_posedge_slow = ((1<<(DIV_N-1))-1);

    // Stall upstream reads unless it is on the cycle where we are going to actually see the positive edge
    // or if we are stalling anyways from our slower logic
    assign upstream_stall = (clock_div_counter != cycle_before_posedge_slow) || upstream_stall_slow;
    // If both clock domains recognize this clock edge, and the output is valid;
    assign out_valid = (clock_div_counter == cycle_before_posedge_slow) && out_valid_slow;

    img_preproc_top dut(.clock(clock_div), .reset(reset_div), 
        .in_data(in_data), .in_valid(in_valid), .out_data(out_data), .out_valid(out_valid_slow), 
        .downstream_stall(downstream_stall), .upstream_stall(upstream_stall_slow));
        
endmodule 