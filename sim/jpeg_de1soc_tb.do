vlib work
vlog ../verilog/*.sv
vlog ../lib/core_jpeg/src_v/*.{v,sv} 
vlog jpeg_de1soc_tb.sv 
vsim work.tb
view wave

add wave cycle_num
add wave -hex dut/*
#add wave -hex dut/jpeg/decoders[0]/decoder/in_*
#add wave -hex dut/jpeg/decoders[0]/is_selected
add wave -unsigned dut/counter_q
add wave -hex dut/send_jpeg_last_q
##add wave -unsigned dut/jpeg/idle_o
##add wave -unsigned dut/jpeg/*byte_idx_q
#add wave dut/jpeg/inport*
#add wave -hex dut/jpeg/jpeg/u_jpeg_input/last_b_q
#add wave -hex dut/jpeg/jpeg/u_jpeg_input/data_r
#add wave -unsigned dut/jpeg/jpeg/u_jpeg_input/state_q
#add wave -unsigned dut/jpeg/outport*
#add wave -unsigned dut/jpeg/result_*
#add wave -unsigned dut/jpeg/row_result_count_q
#add wave -unsigned dut/jpeg/out_buffer/rams[0]/ram/*
add wave -hex dut/jpeg/out_*
add wave -hex dut/jpeg/out_data
add wave dut/jpeg/input_sel
add wave dut/jpeg/output_sel

run -all