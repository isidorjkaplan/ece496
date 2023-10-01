module de1soc_tb_syn(
    input clock,
    input reset,
    output logic [ 31 : 0 ] out_data,
    output logic out_valid,
    input downstream_stall
);
    int img_size = 470;
    logic [7:0] img_file[470] = '{
        8'hff, 8'hd8, 8'hff, 8'he0, 8'h0, 8'h10, 8'h4a, 8'h46, 8'h49, 8'h46, 8'h0, 8'h1, 8'h1, 8'h0, 8'h0, 8'h1, 
8'h0, 8'h1, 8'h0, 8'h0, 8'hff, 8'hdb, 8'h0, 8'h43, 8'h0, 8'h8, 8'h6, 8'h6, 8'h7, 8'h6, 8'h5, 8'h8, 8'h7, 
8'h7, 8'h7, 8'h9, 8'h9, 8'h8, 8'ha, 8'hc, 8'h14, 8'hd, 8'hc, 8'hb, 8'hb, 8'hc, 8'h19, 8'h12, 8'h13, 8'hf, 
8'h14, 8'h1d, 8'h1a, 8'h1f, 8'h1e, 8'h1d, 8'h1a, 8'h1c, 8'h1c, 8'h20, 8'h24, 8'h2e, 8'h27, 8'h20, 8'h22, 
8'h2c, 8'h23, 8'h1c, 8'h1c, 8'h28, 8'h37, 8'h29, 8'h2c, 8'h30, 8'h31, 8'h34, 8'h34, 8'h34, 8'h1f, 8'h27, 
8'h39, 8'h3d, 8'h38, 8'h32, 8'h3c, 8'h2e, 8'h33, 8'h34, 8'h32, 8'hff, 8'hc0, 8'h0, 8'hb, 8'h8, 8'h0, 
8'h1c, 8'h0, 8'h1c, 8'h1, 8'h1, 8'h11, 8'h0, 8'hff, 8'hc4, 8'h0, 8'h1f, 8'h0, 8'h0, 8'h1, 8'h5, 8'h1, 
8'h1, 8'h1, 8'h1, 8'h1, 8'h1, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h0, 8'h1, 8'h2, 8'h3, 8'h4, 
8'h5, 8'h6, 8'h7, 8'h8, 8'h9, 8'ha, 8'hb, 8'hff, 8'hc4, 8'h0, 8'hb5, 8'h10, 8'h0, 8'h2, 8'h1, 8'h3, 8'h3, 
8'h2, 8'h4, 8'h3, 8'h5, 8'h5, 8'h4, 8'h4, 8'h0, 8'h0, 8'h1, 8'h7d, 8'h1, 8'h2, 8'h3, 8'h0, 8'h4, 8'h11, 
8'h5, 8'h12, 8'h21, 8'h31, 8'h41, 8'h6, 8'h13, 8'h51, 8'h61, 8'h7, 8'h22, 8'h71, 8'h14, 8'h32, 8'h81, 
8'h91, 8'ha1, 8'h8, 8'h23, 8'h42, 8'hb1, 8'hc1, 8'h15, 8'h52, 8'hd1, 8'hf0, 8'h24, 8'h33, 8'h62, 8'h72, 
8'h82, 8'h9, 8'ha, 8'h16, 8'h17, 8'h18, 8'h19, 8'h1a, 8'h25, 8'h26, 8'h27, 8'h28, 8'h29, 8'h2a, 8'h34, 
8'h35, 8'h36, 8'h37, 8'h38, 8'h39, 8'h3a, 8'h43, 8'h44, 8'h45, 8'h46, 8'h47, 8'h48, 8'h49, 8'h4a, 8'h53, 
8'h54, 8'h55, 8'h56, 8'h57, 8'h58, 8'h59, 8'h5a, 8'h63, 8'h64, 8'h65, 8'h66, 8'h67, 8'h68, 8'h69, 8'h6a, 
8'h73, 8'h74, 8'h75, 8'h76, 8'h77, 8'h78, 8'h79, 8'h7a, 8'h83, 8'h84, 8'h85, 8'h86, 8'h87, 8'h88, 8'h89, 
8'h8a, 8'h92, 8'h93, 8'h94, 8'h95, 8'h96, 8'h97, 8'h98, 8'h99, 8'h9a, 8'ha2, 8'ha3, 8'ha4, 8'ha5, 8'ha6, 
8'ha7, 8'ha8, 8'ha9, 8'haa, 8'hb2, 8'hb3, 8'hb4, 8'hb5, 8'hb6, 8'hb7, 8'hb8, 8'hb9, 8'hba, 8'hc2, 8'hc3, 
8'hc4, 8'hc5, 8'hc6, 8'hc7, 8'hc8, 8'hc9, 8'hca, 8'hd2, 8'hd3, 8'hd4, 8'hd5, 8'hd6, 8'hd7, 8'hd8, 8'hd9, 
8'hda, 8'he1, 8'he2, 8'he3, 8'he4, 8'he5, 8'he6, 8'he7, 8'he8, 8'he9, 8'hea, 8'hf1, 8'hf2, 8'hf3, 8'hf4, 
8'hf5, 8'hf6, 8'hf7, 8'hf8, 8'hf9, 8'hfa, 8'hff, 8'hda, 8'h0, 8'h8, 8'h1, 8'h1, 8'h0, 8'h0, 8'h3f, 8'h0, 
8'hf9, 8'hfe, 8'h8a, 8'hea, 8'h3c, 8'h69, 8'he0, 8'hd9, 8'h3c, 8'h19, 8'h26, 8'h95, 8'h5, 8'hc5, 8'he8, 
8'h9a, 8'hea, 8'hf6, 8'hc9, 8'h2e, 8'ha6, 8'h83, 8'hca, 8'hd8, 8'hd6, 8'hcc, 8'hdf, 8'hc0, 8'h79, 8'h39, 
8'he8, 8'h79, 8'he3, 8'ha1, 8'he3, 8'hd7, 8'h97, 8'ha2, 8'hba, 8'h5f, 8'h0, 8'h78, 8'h76, 8'he3, 8'hc5, 
8'h1e, 8'h36, 8'hd3, 8'h34, 8'he8, 8'h53, 8'h29, 8'he7, 8'h2c, 8'hb3, 8'hb1, 8'hc6, 8'h16, 8'h25, 8'h39, 
8'h63, 8'hcf, 8'hb0, 8'hc7, 8'hd4, 8'h8a, 8'hb5, 8'hf1, 8'h43, 8'h5c, 8'h5f, 8'h10, 8'h7c, 8'h47, 8'hd6, 
8'h6f, 8'h63, 8'h20, 8'hc4, 8'hb3, 8'h98, 8'h23, 8'h20, 8'h82, 8'ha, 8'hc7, 8'hf2, 8'h2, 8'h8, 8'heb, 
8'h9c, 8'h67, 8'hf1, 8'hae, 8'h42, 8'h8a, 8'hf5, 8'hbf, 8'he, 8'h5f, 8'h5a, 8'h7c, 8'h3c, 8'hf8, 8'h4d, 
8'h3e, 8'hb8, 8'h8f, 8'h1c, 8'h9a, 8'hf7, 8'h88, 8'hbc, 8'hcb, 8'h7b, 8'h40, 8'ha4, 8'h31, 8'h86, 8'h15, 
8'h3b, 8'h58, 8'h91, 8'h9f, 8'h50, 8'h4f, 8'hd4, 8'ha8, 8'hec, 8'h6b, 8'hc9, 8'h40, 8'h7, 8'ha9, 8'hc7, 
8'h14, 8'h94, 8'h51, 8'h45, 8'h15, 8'hff, 8'hd9
    };

    logic upstream_stall;

    logic [15 : 0] in_count;
    always_ff@(posedge clock) begin
        if (reset) begin
            in_count = 0;
        end else if (!upstream_stall && in_count < (img_size+4)) begin
            in_count <= (in_count + 4);
        end
    end


    img_preproc_top dut(.clock(clock), .reset(reset), 
	// Inputs
	.in_data((in_count==0)?img_size:{img_file[in_count-1],img_file[in_count-2],img_file[in_count-3],img_file[in_count-4]}), 
    .in_valid(in_count < (img_size+4)),
	// Outputs
	.out_data(out_data), .out_valid(out_valid), 
	// Control Flow
	.downstream_stall(downstream_stall), .upstream_stall(upstream_stall));

endmodule 

