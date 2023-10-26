vlog ../verilog/*.sv
vlog *.sv

vsim de1soc_tb

add wave dut/clock
add wave dut/reset
add wave dut/in_data
add wave dut/in_valid
add wave dut/out_data
add wave dut/out_valid

run -all
