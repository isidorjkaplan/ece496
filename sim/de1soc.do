### rm -r work
vlib work
vlog ../verilog/conv2d.sv 
vlog ../verilog/maxpool2d.sv 
vlog ../verilog/avgpool.sv 
vlog ../verilog/model.sv 
vlog ../verilog/de1soc_top.sv 
vlog de1soc.sv 
vsim work.tb
view wave

add wave sim:/tb/dut/*
add wave -position 4  sim:/tb/dut/m/sum1/i_ready
add wave -position 4  sim:/tb/dut/m/maxpool2/i_ready
add wave -position 4  sim:/tb/dut/m/conv3/i_ready
add wave -position 4  sim:/tb/dut/m/conv2/i_ready
add wave -position 4  sim:/tb/dut/m/maxpool1/i_ready
add wave -position 4  sim:/tb/dut/m/conv1/i_ready
add wave -position 11  sim:/tb/dut/m/sum1/i_last
add wave -position 11  sim:/tb/dut/m/maxpool2/i_last
add wave -position 11  sim:/tb/dut/m/conv3/i_last
add wave -position 11  sim:/tb/dut/m/conv2/i_last
add wave -position 11  sim:/tb/dut/m/maxpool1/i_last
add wave -position 11  sim:/tb/dut/m/conv1/i_last
add wave -position end  sim:/tb/dut/m/out_data
add wave -position end  sim:/tb/o_data

run -all