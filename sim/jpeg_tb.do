vlib work
vlog ../verilog/jpeg.sv 
vlog ../lib/core_jpeg/src_v/*.{v,sv} 
vlog jpeg_tb.sv 
vsim work.tb
view wave

add wave -hex dut/in_*
add wave -unsigned dut/idle_o
add wave -unsigned dut/*byte_idx_q
#add wave dut/inport*
#add wave -hex dut/jpeg/u_jpeg_input/last_b_q
#add wave -hex dut/jpeg/u_jpeg_input/data_r
#add wave -unsigned dut/jpeg/u_jpeg_input/state_q
add wave -unsigned dut/outport*
add wave -unsigned dut/result_*
add wave -unsigned dut/row_result_count_q
#add wave -unsigned dut/out_buffer/rams[0]/ram/*
add wave -hex dut/out_*


run -all