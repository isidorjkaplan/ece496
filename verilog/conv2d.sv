module conv2d #(parameter WIDTH, KERNAL_SIZE = 3, VALUE_BITS = 8) (
	// Inputs
	input logic clk,			// Operating clock
	input logic reset,			// Active-high reset signal (reset when set to 1)
	input logic i_valid,			// Set to 1 if input pixel is valid
	input logic i_ready,			// Set to 1 if consumer block is ready to receive a new pixel
	input logic [VALUE_BITS-1:0] i_x,		// Input pixel value (8-bit unsigned value between 0 and 255)
	input logic signed [VALUE_BITS-1:0] i_weights [KERNAL_SIZE][KERNAL_SIZE],

	// Outputs
	output logic o_valid,			// Set to 1 if output pixel is valid
	output logic o_ready,			// Set to 1 if this block is ready to receive a new pixel
	output logic [VALUE_BITS-1:0] o_y		// Output pixel value (8-bit unsigned value between 0 and 255)

);
	logic [VALUE_BITS - 1 : 0] taps[KERNAL_SIZE][KERNAL_SIZE];
	logic buffer_ready, buffer_valid;

	shift_buffer_array #(.WIDTH(WIDTH), .TAP_WIDTH(KERNAL_SIZE), .TAP_HEIGHT(KERNAL_SIZE), .VALUE_BITS(VALUE_BITS)) buffer(
		.clk(clk), .reset(reset), .i_valid(i_valid), .i_ready(buffer_ready), .i_x(i_x),
		.o_taps(taps), .o_valid(buffer_valid), .o_ready(o_ready)
	);

	// KERNAL LOGIC -- SIMPLE NON-PIPELINED VERSION

	// Functioning but commenting out for FMax results of buffer
	logic signed [2*VALUE_BITS-1 : 0] tmp;
	
	logic [VALUE_BITS-1:0] o_y_comb;
	logic o_valid_comb;


	always_comb begin
		o_y_comb = o_y;
		o_valid_comb = o_valid;
		buffer_ready = i_ready; // since kernal is one-cycle FOR NOW this means buffer is ready if the kernal output is going to be accepted
		if (i_ready) begin
			o_valid_comb = buffer_valid; // and likewise our output is valid if the stuff its computed on is 
			// Later this will essentially just become a deep pipeline with ready and valid signals propogated through it
			// For now just do full multiply accumulate in one itteration
			tmp = 0;
			for (int row = 0; row < KERNAL_SIZE; row++) begin
				for (int col = 0; col < KERNAL_SIZE; col++) begin
					//if (buffer_valid)
					//	$display("%d+%d", tmp, i_weights[row][col] * signed'({1'b0, taps[row][col]}));
					tmp += i_weights[row][col] * signed'({1'b0, taps[row][col]});
					
				end
			end
			if (tmp > 255) o_y_comb = 255;
			else if (tmp < 0) o_y_comb = 0;
			else o_y_comb = tmp;
		end
		tmp = 0;
	end

	always_ff@(posedge clk) begin
		o_valid <= o_valid_comb;
		o_y <= o_y_comb;
	end
	

endmodule 

module shift_buffer_array #(parameter WIDTH, TAP_WIDTH, TAP_HEIGHT, VALUE_BITS) 
(
	input logic clk,			// Operating clock
	input logic reset,			// Active-high reset signal (reset when set to 1)
	input logic i_valid,			// Set to 1 if input pixel is valid
	input logic i_ready,			// Set to 1 if consumer block is ready to receive a new pixel
	input logic [VALUE_BITS-1:0] i_x,		// Input pixel value (8-bit unsigned value between 0 and 255)
    // outputs
    output logic [VALUE_BITS - 1 : 0] o_taps[TAP_HEIGHT][TAP_WIDTH], // row-major output to be tapped by the kernal
	output logic o_valid,
	output logic o_ready
);
	localparam BUFFER_HEIGHT = TAP_HEIGHT;
	// SEQUENTIAL LOGIC ELEMENTS

	logic [ VALUE_BITS - 1 : 0 ] taps_q[ TAP_HEIGHT ][ TAP_WIDTH ];
	assign o_taps = taps_q;
	// Read state
	logic [ VALUE_BITS - 1 : 0 ] ram_read_output_q[ BUFFER_HEIGHT ]; // synchronous result from the ram access
	// Write synchronous state
	logic [ $clog2(BUFFER_HEIGHT)-1 : 0 ] ram_write_row_head_q; // this denotes the row we are currently writing to
	logic [ $clog2(WIDTH)-1 : 0 ] ram_write_addr_q; // if we are going to write, this is the address we write to 
	logic [ $clog2(WIDTH+1)-1 : 0] last_ram_read_addr_q; 
	logic input_done_row_q, output_done_row_q;
	logic buffer_contents_valid_q; // on reset or new image buffer contents are invalid initially

	// Combinational Logic Elements
	logic [ $clog2(WIDTH+1)-1 : 0 ] ram_read_addr; // this is address for reading the ram
	logic [ $clog2(WIDTH)-1 : 0 ] next_ram_write_addr;  // specify the next value for write address
	logic [ $clog2(BUFFER_HEIGHT)-1 : 0 ] next_ram_write_row_head; // the ram write head value
	logic [ VALUE_BITS - 1 : 0 ] next_taps[ TAP_HEIGHT ][ TAP_WIDTH ];
	logic write_en; // should we write to the ram this cycle
	logic next_input_done_row, next_output_done_row;
	logic next_buffer_contents_valid;

	// Declare the row buffer rams
	genvar ram_num;
	generate
		for (ram_num = 0; ram_num < BUFFER_HEIGHT; ram_num++) begin : buffer_rams
			duel_port_ram #(.VALUE_BITS(VALUE_BITS), .WIDTH(WIDTH)) line_ram(
				.clk(clk), .i_x(i_x), .ram_write_addr_q(ram_write_addr_q), 
				.ram_read_addr(ram_read_addr), .ram_read_output_q(ram_read_output_q[ram_num]),
				.write_en(write_en && (ram_write_row_head_q==ram_num))
			);
		end
	endgenerate

	always_comb begin
		// Persistant outputsignals
		ram_read_addr = last_ram_read_addr_q;
		next_ram_write_addr = ram_write_addr_q;
		next_ram_write_row_head = ram_write_row_head_q;
		next_taps = taps_q;
		next_buffer_contents_valid = buffer_contents_valid_q;
		write_en = 0;
		// Local signals
		next_input_done_row = input_done_row_q;
		next_output_done_row = output_done_row_q;

		o_valid = 0;
		o_ready = !input_done_row_q && i_ready;
		// Input and output march in lockstep so both must be ready to march
		if ((i_valid || input_done_row_q) && i_ready) begin // If we actually latch a value this cycle 
			// Input logic
			if (!input_done_row_q) begin
				write_en = 1; // latch this value into our ram
				next_input_done_row = ram_write_addr_q == WIDTH-1; // Check if we are done
				next_ram_write_addr = ram_write_addr_q + 1; // Increment 
			end
			// Output Logic
			if (!output_done_row_q && buffer_contents_valid_q && (ram_write_addr_q > 1)) begin // If o_ready is false don't bother doing anything at all
				// This tells if the current value on the taps is the last valid one, if so the next_taps value from this cycle is garbage but who cares
				next_output_done_row = (last_ram_read_addr_q == WIDTH); 
				ram_read_addr = last_ram_read_addr_q + 1;//increment 
				// Latch value into output taps
				for (int out_row = 0; out_row < TAP_HEIGHT; out_row++) begin
					for (int out_col = 1; out_col < TAP_WIDTH; out_col++) begin
						next_taps[out_row][out_col-1] = taps_q[out_row][out_col]; 
					end
					// Perform unwrapping when feeding into shift register so we always get the TAP_HEIGHT rows we actually care about
					// Note this is the value that was read from ram last cycle, at last_ram_read_addr_q
					next_taps[out_row][TAP_WIDTH-1] = ram_read_output_q[ 
						((out_row+ram_write_row_head_q+1)<BUFFER_HEIGHT)?
								(out_row+ram_write_row_head_q+1)
							:	(out_row+ram_write_row_head_q+1-BUFFER_HEIGHT) 
					]; 
				end
				// last_ram_read_addr_q also happens to be the value getting shifted into next_taps this cycle
				// that value must be greater than TAP_WIDTH for it to imply that current cycle taps_o has all valid values
				o_valid = last_ram_read_addr_q >= TAP_WIDTH; 
			end
		end

		// Logic to change which row is currently the buffer row and which rows are the output rows being read
		if (input_done_row_q && (output_done_row_q || !buffer_contents_valid_q)) begin
			// Reset the flags so they can both start again
			next_input_done_row = 0;
			next_output_done_row = 0;
			// We are incrementing rows so go back to start of row
			next_ram_write_addr = 0;
			ram_read_addr = 0;
			// Increment the write row pointer by one
			next_ram_write_row_head = ram_write_row_head_q + 1;
			// If the write row is the last row than rotate back around to zero
			if (ram_write_row_head_q == BUFFER_HEIGHT-1) begin
				// Reset write row head back to zero for wrap around
				next_ram_write_row_head = 0;
			end
			// Once first TAP_HEIGHT rows have been written than buffer contents are for sure valid
			if (next_ram_write_row_head == TAP_HEIGHT-1) begin
				next_buffer_contents_valid = 1;
			end
		end

	end


	always_ff@(posedge clk) begin
		if (reset) begin
			ram_write_row_head_q <= 0;
			ram_write_addr_q <= 0;
			last_ram_read_addr_q <= 0;
			input_done_row_q <= 0;
			output_done_row_q <= 0;
			buffer_contents_valid_q <= 0;
		end else begin
			ram_write_row_head_q <= next_ram_write_row_head;
			ram_write_addr_q <= next_ram_write_addr;
			last_ram_read_addr_q <= ram_read_addr;
			taps_q <= next_taps;
			input_done_row_q <= next_input_done_row;
			output_done_row_q <= next_output_done_row;
			buffer_contents_valid_q <= next_buffer_contents_valid;
		end
	end
endmodule 

module duel_port_ram #(parameter VALUE_BITS, WIDTH)(
	input clk,
	input logic [VALUE_BITS-1:0] i_x,	
	input logic [ $clog2(WIDTH)-1 : 0 ] ram_write_addr_q,
	input logic [ $clog2(WIDTH)-1 : 0 ] ram_read_addr,
	output logic [ VALUE_BITS - 1 : 0 ] ram_read_output_q,
	input write_en
);
	logic [ VALUE_BITS - 1 : 0 ] buffer_ram_q[ WIDTH ];
	always_ff@(posedge clk) begin
		ram_read_output_q <= buffer_ram_q[ ram_read_addr ];
		if (write_en) begin
			buffer_ram_q[ ram_write_addr_q ] <= i_x;
		end
	end
endmodule