vlib work
vlog ../verilog/conv2d.sv 
vlog ../verilog/maxpool2d.sv 
vlog ../verilog/avgpool.sv 
vlog ../verilog/model.sv 
vlog model_tb.sv 
vsim work.tb
view wave

add wave *
add wave -position 4  sim:/tb/dut/sum1/i_ready
add wave -position 4  sim:/tb/dut/maxpool2/i_ready
add wave -position 4  sim:/tb/dut/conv3/i_ready
add wave -position 4  sim:/tb/dut/conv2/i_ready
add wave -position 4  sim:/tb/dut/maxpool1/i_ready
add wave -position 4  sim:/tb/dut/conv1/i_ready
add wave -position 11  sim:/tb/dut/sum1/i_last
add wave -position 11  sim:/tb/dut/maxpool2/i_last
add wave -position 11  sim:/tb/dut/conv3/i_last
add wave -position 11  sim:/tb/dut/conv2/i_last
add wave -position 11  sim:/tb/dut/maxpool1/i_last
add wave -position 11  sim:/tb/dut/conv1/i_last
add wave -position end  sim:/tb/o_data

run -all