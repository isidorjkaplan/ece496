vlog ../verilog/*.sv
vlog ../lib/core_jpeg/src_v/*.v
vlog ../lib/core_jpeg/src_v/*.sv
vlog *.sv

vsim de1soc_tb

add wave tb/dut/jpeg/*

run -all
