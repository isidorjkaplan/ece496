vlog ../verilog/*.sv
vlog *.sv

vsim de1soc_tb

add wave dut/clock
add wave dut/reset

### add wave dut/m/conv1/*

add wave dut/m/in_valid
add wave dut/m/conv1/o_valid_q
add wave dut/m/conv1toconv2_o_valid
add wave dut/m/conv2/o_valid_q
add wave dut/m/conv2toconv3_o_valid
add wave dut/m/conv3/o_valid_q
add wave dut/m/out_valid

add wave dut/m/in_data
add wave dut/m/conv1toconv2_data
add wave dut/m/conv2toconv3_data
add wave dut/m/out_data


run -all
