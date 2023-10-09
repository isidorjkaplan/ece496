vlog ../verilog/*.sv
vlog *.sv

vsim de1soc_tb

add wave layer0/*
add wave layer0/buffer_taps
add wave layer0/buffer/buffer

run -all
