vlog ../verilog/*.sv
vlog *.sv

vsim de1soc_tb

add wave dut/*
add wave dut/cnn/layer0/state_q
add wave dut/cnn/pool0/state_q
add wave dut/cnn/layer1/state_q
add wave dut/cnn/pool1/state_q
add wave dut/*

run -all
