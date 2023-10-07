
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

    logic [31 : 0] buffer_out_data;
    logic buffer_out_valid;
    logic img_preproc_upstream_stall;

    img_buffer buffer(.clock(clock), .reset(reset), 
        .in_data(in_data), .in_valid(in_valid), .out_data(buffer_out_data), .out_valid(buffer_out_valid), 
        .downstream_stall(img_preproc_upstream_stall), .upstream_stall(upstream_stall));


    img_preproc_sv_unit::pixel jpeg_out_data;
    logic jpeg_out_valid;
    logic jpeg_downstream_stall;
    img_preproc jpeg(.clock(clock), .reset(reset), 
        .in_data(buffer_out_data), .in_valid(buffer_out_valid), 
        
        .out_data(jpeg_out_data), .out_valid(jpeg_out_valid),

        .downstream_stall(jpeg_downstream_stall), .upstream_stall(img_preproc_upstream_stall));


    serialize pixel_to_de1soc(.clock(clock), .reset(reset), 
        .in_data({
            jpeg_out_data.pixel_x, 
            jpeg_out_data.pixel_y, 
            jpeg_out_data.pixel_r, 
            jpeg_out_data.pixel_g, 
            jpeg_out_data.pixel_b 
        }), 
        .in_valid(jpeg_out_valid),
        .out_data(out_data), .out_valid(out_valid), .upstream_stall(jpeg_downstream_stall), .downstream_stall(downstream_stall));

    //assign upstream_stall = 1'b0;
    //de1soc_tb_syn tb(.clock(clock), .reset(reset || in_valid), .out_data(out_data), .out_valid(out_valid), .downstream_stall(downstream_stall));   
endmodule 


// Takes in a wide internal wire format (such as output of jpeg) and serializes it over multiple cycles
module serialize #(parameter N=5) (
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
    logic [ 31 : 0 ] data_buffer[N];
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
    assign out_data = in_data[word_idx];

endmodule
