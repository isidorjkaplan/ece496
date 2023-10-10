vlog ../verilog/*.sv
vlog *.sv

vsim de1soc_tb

add wave dut/*
add wave dut/layer0/state_q
add wave dut/pool0/state_q
add wave dut/layer1/state_q
add wave dut/pool1/state_q

run -all
