vlog ../verilog/*.sv
vlog ../lib/core_jpeg/src_v/*.v
vlog ../lib/core_jpeg/src_v/*.sv
vlog *.sv

vsim de1soc_tb

log *
add wave tb/*
add wave tb/dut/*
add wave tb/dut/jpeg/img_end_w
add wave tb/dut/jpeg/bb_inport_valid_w
add wave tb/dut/jpeg/*

run -all
