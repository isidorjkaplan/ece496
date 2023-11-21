vlib work
vlog ../verilog/jpeg.sv 
vlog ../lib/core_jpeg/src_v/*.{v,sv} 
vlog jpeg_tb.sv 
vsim work.tb
view wave

add wave *

run -all