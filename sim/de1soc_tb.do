vlog ../verilog/*.sv
vlog *.sv

vsim de1soc_tb

add wave dut/clock
add wave dut/reset_i
add wave dut/in_data
add wave dut/in_valid
add wave dut/in_row_tag_i
add wave dut/cnn/layer0/state_q
add wave dut/cnn/layer0/in_row_i
add wave dut/cnn/layer0/in_row_valid_i
add wave dut/cnn/layer0/buffer_taps
add wave dut/cnn/pool0/state_q
add wave dut/cnn/layer1/state_q
add wave dut/cnn/pool1/state_q
add wave dut/out_row_tag_o
add wave dut/out_data
add wave dut/out_valid

run -all
