vlog ../verilog/*.sv
vlog *.sv

vsim de1soc_tb

add wave tb/dut/jpeg/jpeg/*

run -all
