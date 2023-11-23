vlib work
vlog ../verilog/*.sv
vlog ../lib/core_jpeg/src_v/*.{v,sv} 
vlog jpeg_de1soc_tb.sv 
vsim work.tb
view wave

add wave -hex dut/*
add wave -hex dut/jpeg/*

run -all