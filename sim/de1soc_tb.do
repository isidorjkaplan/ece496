vlog ../verilog/*.sv
vlog *.sv

vsim de1soc_tb

add wave dut/layer0/* 
add wave dut/layer0/in_row_i
add wave dut/layer0/buffer_taps
add wave dut/layer0/buffer/buffer
add wave dut/layer0/out_row_o


run -all
