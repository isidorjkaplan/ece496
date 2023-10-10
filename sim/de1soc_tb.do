vlog ../verilog/*.sv
vlog *.sv

vsim de1soc_tb

add wave dut/*
add wave dut/layer0/* 
add wave dut/layer0/in_row_i
add wave dut/layer0/buffer_taps
add wave dut/layer0/buffer/buffer
add wave dut/layer0/out_row_o
add wave dut/pool0/* 
add wave dut/pool0/in_row_i
add wave dut/pool0/out_row_o


run -all
