vlog ../verilog/*.sv
vlog ../lib/core_jpeg/src_v/*.v
vlog *.sv

vsim de1soc_tb

log *
add wave dut/*

run -all