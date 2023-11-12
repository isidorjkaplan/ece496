// Server, run on the ARM cpu of the DE1-SoC
#include <stdlib.h>
#include <iostream>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <vector>

#include <iomanip>

#include <jpeglib.h>

//
// BEGIN FPGA BUS MACROS & GLOBALS
//

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/mman.h>
#include <sys/time.h>
#include <math.h>
#include <getopt.h>
#include <unistd.h>
#include <assert.h>

// main bus; scratch RAM
// used only for testing
#define FPGA_ONCHIP_BASE      0xC8000000
#define FPGA_ONCHIP_SPAN      0x00001000

// main bus; FIFO write address
#define FIFO_BASE            0xC0000000
#define FIFO_SPAN            0x00001000
// the read and write ports for the FIFOs
// you need to query the status ports before these operations
// PUSH the write FIFO
// POP the read FIFO
#define FIFO_WRITE		     (*(FIFO_write_ptr))
#define FIFO_READ            (*(FIFO_read_ptr))

/// lw_bus; FIFO status address
#define HW_REGS_BASE          0xff200000
#define HW_REGS_SPAN          0x00005000
// WAIT looks nicer than just braces
#define WAIT {}
// FIFO status registers
// base address is current fifo fill-level
// base+1 address is status:
// --bit0 signals "full"
// --bit1 signals "empty"
#define WRITE_FIFO_FILL_LEVEL (*FIFO_write_status_ptr)
#define READ_FIFO_FILL_LEVEL  (*FIFO_read_status_ptr)
#define WRITE_FIFO_FULL		  ((*(FIFO_write_status_ptr+1))& 1 )
#define WRITE_FIFO_EMPTY	  ((*(FIFO_write_status_ptr+1))& 2 )
#define READ_FIFO_FULL		  ((*(FIFO_read_status_ptr+1)) & 1 )
#define READ_FIFO_EMPTY	      ((*(FIFO_read_status_ptr+1)) & 2 )
// arg a is data to be written
#define FIFO_WRITE_BLOCK(a)	  {while (WRITE_FIFO_FULL){WAIT};FIFO_WRITE=a;}
// arg a is data to be written, arg b is success/fail of write: b==1 means success
#define FIFO_WRITE_NOBLOCK(a,b) {b=!WRITE_FIFO_FULL; if(!WRITE_FIFO_FULL)FIFO_WRITE=a; }
// arg a is data read
#define FIFO_READ_BLOCK(a)	  {while (READ_FIFO_EMPTY){WAIT};a=FIFO_READ;}
// arg a is data read, arg b is success/fail of read: b==1 means success
#define FIFO_READ_NOBLOCK(a,b) {b=!READ_FIFO_EMPTY; if(!READ_FIFO_EMPTY)a=FIFO_READ;}


// the light weight buss base
void *h2p_lw_virtual_base;
// HPS_to_FPGA FIFO status address = 0
volatile unsigned int * FIFO_write_status_ptr = NULL ;
volatile unsigned int * FIFO_read_status_ptr = NULL ;

// RAM FPGA command buffer
// main bus addess 0x0800_0000
//volatile unsigned int * sram_ptr = NULL ;
//void *sram_virtual_base;

// HPS_to_FPGA FIFO write address
// main bus addess 0x0000_0000
void *h2p_virtual_base;
volatile unsigned int * FIFO_write_ptr = NULL ;
volatile unsigned int * FIFO_read_ptr = NULL ;

// /dev/mem file id
int fd;

// timer variables
struct timeval t1, t2;
double elapsedTime;


#define MIN(x, y) ((x<=y)?x:y)


#ifdef DEBUG
#define PRINTF(...) (printf(__VA_ARGS__))
#endif

#ifndef DEBUG
#define PRINTF(...)
#endif

//
// END FPGA BUS MACROS & GLOBALS
//

void initFPGABus() {
    if( ( fd = open( "/dev/mem", ( O_RDWR | O_SYNC ) ) ) == -1 )
	{
		PRINTF( "ERROR: could not open \"/dev/mem\"...\n" );
		//return 1;
	}

	//============================================
  // get virtual addr that maps to physical
	// for light weight bus
	// FIFO status registers
	h2p_lw_virtual_base = mmap( NULL, HW_REGS_SPAN, ( PROT_READ | PROT_WRITE ), MAP_SHARED, fd, HW_REGS_BASE );
	if( h2p_lw_virtual_base == MAP_FAILED ) {
		PRINTF( "ERROR: mmap1() failed...\n" );
		close( fd );
		//return 1;
	}
	// the two status registers
	FIFO_write_status_ptr = (unsigned int *)(h2p_lw_virtual_base);
	// From Qsys, second FIFO is 0x20
	FIFO_read_status_ptr = (unsigned int *)(h2p_lw_virtual_base + 0x20); //0x20

	// FIFO write addr
	h2p_virtual_base = mmap( NULL, FIFO_SPAN, ( PROT_READ | PROT_WRITE ), MAP_SHARED, fd, FIFO_BASE);

	if( h2p_virtual_base == MAP_FAILED ) {
		PRINTF( "ERROR: mmap3() failed...\n" );
		close( fd );
		//return(1);
	}
  	// Get the address that maps to the FIFO read/write ports
	FIFO_write_ptr =(unsigned int *)(h2p_virtual_base);
	FIFO_read_ptr = (unsigned int *)(h2p_virtual_base + 0x10); //0x10
    // Reset the FPGA since server just started
	// give the FPGA time to finish working
	usleep(3000);  
	// Flush any initial contents on the Queue
	int read_count = 0;
	while (!READ_FIFO_EMPTY) {
		FIFO_READ;
		read_count++;
	}

    FIFO_WRITE_BLOCK(1ull << 31);
	
    PRINTF("Flushed FIFO read queue with %d elements\n", read_count);
}

#define VALUE_READ_BITS ((unsigned int)18)
#define VALUE_MASK ((unsigned int)((1<<VALUE_READ_BITS)-1))
// Recieve data from FPGA, place into buffer
void recvFromFPGA(int* buf) {
    int* bstart = buf;
    int numtoread = 10;
    while (numtoread > 0) {
        //if (!READ_FIFO_EMPTY) {
            unsigned int val;
            FIFO_READ_BLOCK(val);
            PRINTF("R: %d\n", (int)val);
            val &= VALUE_MASK; // mask data bits
            bool isneg = val&(1<<(VALUE_READ_BITS-1));
            val |= isneg ? (0xffffffff & ~VALUE_MASK) : 0;
            *(buf++) = val;
            numtoread--;
            PRINTF("%d\n", (int)val);
        //}
    }
    PRINTF("%d words read\n", buf-bstart);
}

// Send data contained within buf to FPGA
// Hard-coded buffer size
void sendToFPGA(char* buf) {
    const int X = 28;
    const int Y = X;
    // This is a feature of the neural network architecture chosen
    const int NUM_ROWS_FOR_VALID_OUTPUT = 28;
    const int RESULT_WIDTH = 7;
    const int RESULT_CHANNELS = 10;
    const int INPUT_SHIFT = 7;
    
    int x, y;
    int out_row_count = 0;
    for (y=0; y < Y; y++) {
        for (x=0; x < X; x++) {
            unsigned int finish = y==Y-1 && x==X-1;
            finish <<= 30;
            PRINTF("F: %d\n", finish);
            FIFO_WRITE_BLOCK(((unsigned int)(unsigned char)buf[x + 28*y]) | finish);
            PRINTF("E: %x", (((unsigned int)(unsigned char)buf[x + 28*y]) | finish));
        }
    }
    
}

// Represents dimensions of image
struct ImgInfo {
    int height;
    int width;
    int chans;
};

// converts JPEG image in img_data, places result in pixbuf.
// result image dims placed into img_info
int decodeJPEG(const std::vector<char>& img_data, std::vector<char>& pixbuf, ImgInfo& img_info) {
    struct jpeg_decompress_struct cinfo;
    struct jpeg_error_mgr jerr;
    
    // make decompression errors not crash the server because that is bad
    cinfo.err = jpeg_std_error(&jerr);  
    // does some initialization stuff for cinfo
    jpeg_create_decompress(&cinfo);
    // tell libjpeg to grab the jpeg from our vector buffer
    jpeg_mem_src(&cinfo, (unsigned char*)&img_data[0], img_data.size());

    // bad function name. Doesn't really parse header for data, but will return -1 if jpeg header invalid
    int res = jpeg_read_header(&cinfo, TRUE);
    if (res == -1) {std::cerr << "Error reading jpeg, something wrong with the jpeg file" << std::endl; return 1;}

    // actually read the header now
    jpeg_start_decompress(&cinfo);

    int img_width, img_height, num_components;
    img_width = cinfo.output_width; img_height = cinfo.output_height;
    num_components = cinfo.output_components;
    
    size_t pixbuf_size = img_width * img_height * num_components;
    size_t row_size = img_width * num_components;

    pixbuf.resize(pixbuf_size);

    // read all the lines of the JPEG. Might be a better way than this, idk
    while (cinfo.output_scanline < cinfo.output_height) {
        unsigned char *scanbuf[1];
        scanbuf[0] = (unsigned char*)&pixbuf[row_size * cinfo.output_scanline];
        jpeg_read_scanlines(&cinfo, scanbuf, 1);
    }
    
    // reset cinfo, can now be used for new image
    jpeg_finish_decompress(&cinfo);

    // destroy cinfo
    jpeg_destroy_decompress(&cinfo);
/*
    for (int i = 0; i < 28; ++i) {
        for (int j = 0; j < 28; ++j) {
            std::cout << (int)pixbuf[i*row_size + j*num_components] << ' ';
        }
        std::cout << std::endl;
    }
*/
    img_info = {img_height, img_width, num_components};

    return 0;
}

// Scale *raw pixel* image in ipixbuf with dims described by img_info
// place result into outbuf. out_info describes size of desired output image, but only one channel is supported for now
void scaleNN(const std::vector<char>& ipixbuf, const ImgInfo img_info, std::vector<char>& outbuf, const ImgInfo out_info) {
    outbuf.resize(out_info.width * out_info.height * 1);
    
    // TODO: maybe support more than one output channel
    // sample from middle
    int r_offset = img_info.height / out_info.height / 2;
    int c_offset = img_info.width / out_info.width / 2;
    //std::cout << "FROM: " << img_info.height << ' ' << img_info.width << " TO: " << out_info.height << ' ' << out_info.width <<std::endl;
    for (int r = 0; r < out_info.height; ++r) {
        for (int c = 0; c < out_info.width; ++c) {
            int R, C;
            R = r * img_info.height / out_info.height + r_offset;
            C = c * img_info.width / out_info.width + c_offset;

            //std::cout << (int)ipixbuf[img_info.chans*(R * img_info.width + C)] << ' ';
            // todo: luminance
            outbuf[r * out_info.width + c] = ipixbuf[img_info.chans*(R * img_info.width + C)];
#ifdef DEBUG
            std::cout << std::setw (4)<< (unsigned int)ipixbuf[img_info.chans*(R * img_info.width + C)] << " ";
#endif


        }
#ifdef DEBUG
        std::cout << std::endl;
#endif
    }
}

// End-to-end conversion from JPEG in img_data, to a 28x28x1 image output to nbuf
int jpeg_to_neural(const std::vector<char>& img_data, std::vector<char>& nbuf) {
    std::vector<char> temp_buf;
    ImgInfo temp_info;
    int res = decodeJPEG(img_data, temp_buf, temp_info);
    if (res != 0) return 1;
#ifdef DEBUG
    std::cout << "Decode succesful, about to scale" << std::endl;
#endif
    ImgInfo neural_info = {28, 28, 1};
    scaleNN(temp_buf, temp_info, nbuf, neural_info);
#ifdef DEBUG
    std::cout << "Scale succesful" << std::endl;
#endif
    return 0;
}

// The software server
int main(int argc, char* argv[]) {
    int res;
    addrinfo hints;
    addrinfo* serv_info;
    
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_PASSIVE;

    res = getaddrinfo(
                nullptr,//"192.168.2.123",
                "6202", // arbitrary port number
                &hints,
                &serv_info);
    if (res != 0 ) {std::cerr << "Error getting addr info" << std::endl; return 1;}

    // okay, we've got the address. Now make a socket

    int sock;
    sock = socket(serv_info->ai_family, serv_info->ai_socktype, serv_info->ai_protocol);
    if (sock == -1) {std::cerr << "Error making socket" << std::endl; return 1;}
    res = bind(sock, serv_info->ai_addr, serv_info->ai_addrlen);
    if (res == -1) {std::cerr << "Error binding to socket" << std::endl; return 1;}
    res = listen(sock, 5); // support backlog of 5 clients
    if (res == -1) {std::cerr << "Error listening to socket" << std::endl; return 1;}

    // okay, we are listening for TCP connections. Now lets respond to incoming connections
    
    initFPGABus();

    sockaddr_storage client_addr;
    socklen_t client_addr_size = sizeof(client_addr);
    int client_sock;
    std::vector<char> pixbuf; // move outside loop to avoid excessive allocations.
    std::vector<char> img_data; // ^^
    while (true) {
        client_sock = accept(sock, (sockaddr*)&client_addr, &client_addr_size);
        if (client_sock == -1) {std::cerr << "Error accepting connection" << std::endl; return 1;}
        // okay, we have accepted 1 connection. Lets recieve some data
     
        while (true) {
            int32_t img_size;
            int offset = 0;
            while (offset < 4) {
                res = recv(client_sock, (char*)&img_size+offset, 4-offset, 0);
                if (res == -1) {std::cerr << "Error recieving msg" << std::endl; return 1;}
                if (res == 0) break; // connection closed
                offset += res;
            }
            if (offset != 4) break; // connection closed gracefully
            img_size = ntohl(img_size);
            offset = 0;
#ifdef DEBUG
            std::cout << "Recieving image of size " << img_size << std::endl;
#endif
            img_data.resize(img_size);
            while (img_size) {
                int amt_to_read = img_size;
                while (offset < amt_to_read) {
                    res = recv(client_sock, &img_data[offset], amt_to_read - offset, 0);
                    if (res == -1) {std::cerr << "Error recieving msg" << std::endl; return 1;}
                    if (res == 0) {std::cerr << "Error connection closed unexpectedly" << std::endl; return 1;}
                    offset += res;
                }
                img_size -= amt_to_read;
            }

            {
                // begin image processing
                res = jpeg_to_neural(img_data, pixbuf);
                if (res != 0) {return 1;}
                // end image processing
                // begin FPGA I/O
                sendToFPGA(&pixbuf[0]);
                pixbuf.resize(4 * 10);
#ifdef DEBUG
                std::cout << "Sent to FPGA" << std::endl;
#endif
                recvFromFPGA((int*)&pixbuf[0]);
                // end FPGA I/O
                offset = 0;
                unsigned int net_size = htonl(pixbuf.size());
#ifdef DEBUG
                std::cout << "Sending result of size " << pixbuf.size() << std::endl; 
#endif
                while (offset < 4) {
                    res = send(client_sock, (char*)&net_size+offset, 4-offset, 0);
                    if (res == -1) {std::cerr << "Error sending msg" << std::endl; return 1;}
                    offset +=res;
                }
                offset = 0;
                while (offset < pixbuf.size()) {
                    res = send(client_sock, &pixbuf[offset], pixbuf.size() - offset, 0);
                    if (res == -1) {std::cerr << "Error sending msg" << std::endl; return 1;}
                    offset += res;
                }
            }
        }

#ifdef DEBUG
        std::cout << "Succesfully recieved all images" << std::endl;
#endif

        

        // send data to FPGA
        //  sendToFPGA((int*)&img_data[0], 123456);
        //  recvFromFPGA((int*)&img_data[0], 123456);
    /*
        offset = 0;
        while (offset < 4096) {
            res = send(client_sock, msg+offset, 4096 - offset, 0);
            if (res == -1) {std::cerr << "Error sending msg" << std::endl; return 1;}
            offset += res;
        }
    */
#ifdef DEBUG
        std::cout << "Succesfully sent data" << std::endl;
#endif
        close(client_sock);
    }
    std::cout << "Shutting down..." << std::endl;
    close(sock);
}
