vlog ../verilog/*.sv
vlog *.sv

vsim de1soc_tb

add wave dut/*
add wave dut/pool0/* 
add wave dut/pool0/in_row_i
add wave dut/pool0/out_row_o


run -all
