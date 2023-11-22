# AI Inference Server on FPGA
This is an ongoing project working on implementing an AI inference server on FPGA. The current targeted device is DE1Soc and uses its
Intel Cyclone V FPGA fabric and Arm Hard Processor System.  
Currently we have successfully created a multithreaded C server which accepts tcp connection to recieve image, performed inference 
in the FPGA fabric, and transmit inference results back to sender.

## Multithreaded Network Server

## Inference Model in Fabric
Fabric currently runs a mnist model with weights trained in pytorch.
## Future Improvements
