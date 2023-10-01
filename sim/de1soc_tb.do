vlog ../verilog/*.sv
vlog ../lib/core_jpeg/src_v/*.v
vlog *.sv

vsim de1soc_tb

log *
add wave dut/*
add wave dut/jpeg/img_end_w
add wave dut/jpeg/bb_inport_valid_w
add wave dut/jpeg/*

run -all
