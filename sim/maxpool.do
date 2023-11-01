vlib work
vlog ../verilog/conv2d.sv 
vlog ../verilog/maxpool2d.sv 
vlog maxpool_tb.sv 
vsim work.tb
view wave

#add wave /tb/dut/*
#add wave /tb/dut/taps
#add wave /tb/dut/i_weights
#add wave /tb/dut/buffer/*

add wave *

run -all