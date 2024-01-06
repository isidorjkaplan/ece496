/*
 * commandOne.c
 *
 *  Created on: Jun 16, 2018
 *      Author: Owner
 */
///////////////////////////////////////
// commandOne
// this sends a 4 (32bit) word command thru an block transfer FIFO
//  from the HPS to the FPGA, then receives a 4 word response
//
// compiled in Eclipse using the arm9-linux-gnueabihf-gcc compiler
///////////////////////////////////////
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

void print_data(unsigned int data) {
	/*printf("Read word=0x%x, inport_accept_o=%d, outport_width_o_nonzero=%d, idle_o=%d, count_zero=%d, jpeg_debug_tap=%d, word_count=%d\n", data,
				(data>>0)&1, (data>>1)&1, (data>>2)&1, (data>>3)&1,
				0xFF & (data >> 16), 0xFF & (data >> 24));*/
	printf("Read data word= 0x%x = 32'd%d\n", data, data);
}

void read_next() { 
	while (READ_FIFO_EMPTY) {
		usleep(1000); 
	}
	print_data(FIFO_READ);
}

void assert_fifo_empty(const char* tag) {
	//usleep(100);  

	int i = 0;
	while (!READ_FIFO_EMPTY) {
		FIFO_READ;
		
		i++;
	}
	
	if (i > 0) {
		printf("ERROR (tag=%s): Flushed FIFO read queue with %d elements when expecting no elements\n", tag, i);
		exit(1);
	}
}

int main (int argc, char *argv[])
{	
	// === get FPGA addresses ==================
  // Open /dev/mem
	if( ( fd = open( "/dev/mem", ( O_RDWR | O_SYNC ) ) ) == -1 )
	{
		printf( "ERROR: could not open \"/dev/mem\"...\n" );
		return 1;
	}

	//============================================
  // get virtual addr that maps to physical
	// for light weight bus
	// FIFO status registers
	h2p_lw_virtual_base = mmap( NULL, HW_REGS_SPAN, ( PROT_READ | PROT_WRITE ), MAP_SHARED, fd, HW_REGS_BASE );
	if( h2p_lw_virtual_base == MAP_FAILED ) {
		printf( "ERROR: mmap1() failed...\n" );
		close( fd );
		return 1;
	}
	// the two status registers
	FIFO_write_status_ptr = (unsigned int *)(h2p_lw_virtual_base);
	// From Qsys, second FIFO is 0x20
	FIFO_read_status_ptr = (unsigned int *)(h2p_lw_virtual_base + 0x20); //0x20

	// FIFO write addr
	h2p_virtual_base = mmap( NULL, FIFO_SPAN, ( PROT_READ | PROT_WRITE ), MAP_SHARED, fd, FIFO_BASE);

	if( h2p_virtual_base == MAP_FAILED ) {
		printf( "ERROR: mmap3() failed...\n" );
		close( fd );
		return(1);
	}
  	// Get the address that maps to the FIFO read/write ports
	FIFO_write_ptr =(unsigned int *)(h2p_virtual_base);
	FIFO_read_ptr = (unsigned int *)(h2p_virtual_base + 0x10); //0x10

	// give the FPGA time to finish working
	usleep(30000);  
	// Flush any initial contents on the Queue
	int i = 0;
	while (!READ_FIFO_EMPTY) {
		FIFO_READ;
		i++;
	}
	printf("Flushed FIFO read queue with %d elements\n", i);
	i = 0;

	//============================================
	//printf("Usage: sudo ./command <file>\n");

	
	int img_count = 1;

	if (argc >= 2) {
		if (argc >= 3) img_count = atoi(argv[2]);

		// PRELOAD EVERYTHING INTO MEMORY TO MAKE AS FAST AS POSSIBLE

		int size;
		// Get size
		printf("Opening file %s\n", argv[1]);
		FILE* f = fopen(argv[1], "rb");
		
		if (!f) {
			fprintf(stderr, "Failed to open file: %s\n", argv[1]);
			exit(1);
		}
		fseek(f, 0, SEEK_END);
		size = ftell(f);
		size = size/4 + (size%4!=0);
		rewind(f);

		printf("File is %d words (4 bytes/word)\n", size);
		#define BUFFER_SIZE 1000
		unsigned int buffer[BUFFER_SIZE];
		assert(size < BUFFER_SIZE);
		i = 0;
		while(!feof(f))
		{
	
			fread(&buffer[i], 1, sizeof(buffer[i]), f);
			i++;
		}
		printf("Read %d of %d bytes from file.\n", i, size);
		fclose(f);

		const int RESULT_WIDTH = 1;
		const int RESULT_HEIGHT = 1;
		const int RESULT_CHANNELS = 10;
		unsigned int result[RESULT_WIDTH][RESULT_HEIGHT][RESULT_CHANNELS];
		
		// WRITE THE FIRST IMAGE AND STORE ITS RESULT

		FIFO_WRITE_BLOCK(size);
		for (i = 0; i < size; i++) {
			FIFO_WRITE_BLOCK(buffer[i]);
		}
		
		int x, y, ch;
		for (y = 0; y < RESULT_HEIGHT; y++) {
			for (x = 0; x < RESULT_WIDTH; x++) {
				printf("Read (x,y)=(%d,%d) from first image is [", x, y);
				i = 0;
				for (ch = 0; ch < RESULT_CHANNELS; ch++) {
					while(READ_FIFO_EMPTY) { i++; }
					unsigned int data = FIFO_READ;
					result[x][y][ch] = data; //store for verification later
					printf("%d, ", data);
				}
				printf("] spin_delay=%d\n", i);
			}
		}

		printf("Starting Performance Test...\n");
		time_t start = time(NULL);

		int img_num;
		for (img_num = 0; img_num < img_count; img_num++) {
			assert_fifo_empty("image_start");

			// Write the image 
			FIFO_WRITE_BLOCK(size);
			for (i = 0; i < size; i++) {
				FIFO_WRITE_BLOCK(buffer[i]);
			}

			// Read result from image and ensure it matches
			for (y = 0; y < RESULT_HEIGHT; y++) {
				for (x = 0; x < RESULT_WIDTH; x++) {
					for (ch = 0; ch < RESULT_CHANNELS; ch++) {
						while(READ_FIFO_EMPTY) {}
						unsigned int data = FIFO_READ;
						assert(result[x][y][ch] == data); 
					}
				}
			}
		}
		
		double delay = (double)(time(NULL) - start);
		printf("Completed performance test in %.2f seconds at throughput of %d images per second\n",  delay, (int)(img_count/delay));

	} else {
		printf("Usage: sudo ./command <file>\n");
	}


	printf("Program Done\n");
	exit(0);
}

//////////////////////////////////////////////////////////////////



