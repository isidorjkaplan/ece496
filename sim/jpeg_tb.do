vlib work
vlog ../verilog/jpeg.sv 
vlog ../lib/core_jpeg/src_v/*.{v,sv} 
vlog jpeg_tb.sv 
vsim work.tb
view wave

add wave *
add wave dut/u_jpeg_input/state_q
add wave dut/u_jpeg_input/last_b_q
add wave dut/u_jpeg_input/data_r

run -all