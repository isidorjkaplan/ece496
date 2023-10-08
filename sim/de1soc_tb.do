vlog ../verilog/*.sv
vlog *.sv

vsim de1soc_tb

add wave tb/layer0/*

run -all
