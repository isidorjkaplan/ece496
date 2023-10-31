module sum #(
    parameter WIDTH = 28, 
    parameter VALUE_BITS = 32, 
    parameter CHANNELS = 1,
    parameter VALUE_Q_FORMAT_N = 16
) (
    // general
    input   logic                               clk,                // Operating clock
    input   logic                               reset,              // Active-high reset signal (reset when set to 1)

    // Input Interface
    input   logic signed    [VALUE_BITS-1:0]    i_data[CHANNELS],   // Input pixel value (32-bit signed Q15.16)
    input   logic                               i_valid,            // Set to 1 if input pixel is valid
    output  logic                               i_ready,            // Set to 1 if consumer block is ready to receive a new pixel
    input   logic                               i_last,             // Set to 1 if input pixel is last of image

    // Output Interface
    output  logic signed    [VALUE_BITS-1:0]    o_data[CHANNELS],   // Output pixel value (32-bit signed Q15.16)
    output  logic                               o_valid,            // Set to 1 if output pixel is valid
    input   logic                               o_ready,            // Set to 1 if this block is ready to receive a new pixel
    output  logic                               o_last              // Set to 1 if output pixel is last of image
);
    logic signed [VALUE_BITS-1:0]   sum[CHANNELS];
    logic                           got_last;

    assign o_data = sum;
    assign i_ready = ~got_last;
    assign o_valid = got_last;
    assign o_last = got_last;

    // sums
    always_ff@(posedge clk) begin
        if(reset) begin
            for(int i = 0; i < CHANNELS; i++)
                sum[i] <= '0;
        end
        else if(o_valid && o_ready) begin
            for(int i = 0; i < CHANNELS; i++)
                sum[i] <= '0;
        end
        // accumulate only integer portion
        else if(i_ready && i_valid) begin
            for(int i = 0; i < CHANNELS; i++)
                sum[i] <= sum[i] + (i_data[i] >> (VALUE_Q_FORMAT_N));
        end
    end

    // got last
    always_ff@(posedge clk) begin
        if(reset) begin
            got_last <= '0;
        end
        else if(i_ready && i_last) begin
            got_last <= 1;
        end
        else if(o_valid && o_ready) begin
            got_last <= 0;
        end
    end

endmodule 