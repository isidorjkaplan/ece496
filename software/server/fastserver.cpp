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

#include <pthread.h>
#include <semaphore.h>

#include <array>
#include <queue>

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
#define PRINTF(...) ({printf("T=%u ms:", get_usec_time()/1000); printf(__VA_ARGS__)})
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

uint64_t get_usec_time() {
    struct timeval tv;
    gettimeofday(&tv,NULL);
    
    // multiply seconds by 1,000,000 to convert to usec
    return  (uint64_t)1000000 * tv.tv_sec + tv.tv_usec;
}

#define VALUE_READ_BITS ((unsigned int)18)
#define VALUE_MASK ((unsigned int)((1<<VALUE_READ_BITS)-1))
// Recieve data from FPGA, place into buffer
void recvFromFPGA(int* buf) {
    int* bstart = buf;
    int numtoread = 10;
    PRINTF("\nBegin recieving from FPGA\n");
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
// Flexible buffer size. 
void sendToFPGA(std::vector<char>& buf) {
    // Write size in host order
    
    PRINTF("\nBegin sending to FPGA, buf size is %d\n", buf.size());
    unsigned int newsize_w = (buf.size()+3)/4;
    FIFO_WRITE_BLOCK(((unsigned int)(newsize_w)));
    buf.resize(newsize_w * 4, 0);
    PRINTF("\nSend size %d, now sending resized buffer of size %d\n", newsize_w, buf.size());
    for (int i = 0; i < buf.size(); i+=4) {   
        FIFO_WRITE_BLOCK(*((unsigned int*)&(buf[i]))); // TODO: avoid segfault on unaligned buf
        PRINTF("E: %x", (*((unsigned int*)&(buf[i]))));
    }
    
    PRINTF("\nFinished sending to FPGA\n");
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

// Ideal threading arch:
// One thread to listen for connections
// One thread to manage FPGA
//
// Per client:
//  one thread for (network) image input
//  one thread for (network) result output

// one each:

// listen for incoming connections forever, and spin up corresponding
// recieveForever and transmitForever threads
void* listenForever(void*);
// Wait for images to be produced by reciveForever threads
// When this happens, send as many waiting images as possible to FPGA
// Then, add results to appropriate queues to be transmitted
void* manageFPGAForever(void*);
void* manageFPGAForever2(void*);


// per client:
// Recieve images forever, do image processing on them, and add to queue to be
// processed by FPGA
void* recieveForever(void*);
// Send results back to clients
void* transmitForever(void*);

#define NUM_SIM_CLIENTS 8

#define FIFO_SIZE 5000

// SPSC FIFO
// Not very efficient TBH, but it doesnt really need to be
class ResultDataQueue {
    std::queue<std::vector<char>> dataQueue;
    pthread_mutex_t mutex;
    sem_t itemsLeft;

    sem_t spaceLeft;
public:
    ResultDataQueue() {
        pthread_mutex_init(&mutex, NULL);
        sem_init(&itemsLeft, 0, 0);
        sem_init(&spaceLeft, 0, FIFO_SIZE);
    }
    ~ResultDataQueue() {
        pthread_mutex_destroy(&mutex);
        sem_destroy(&itemsLeft);
        sem_destroy(&spaceLeft);
    }

    void push(std::vector<char> && in) {
        sem_wait(&spaceLeft);
        pthread_mutex_lock(&mutex);
        dataQueue.push(std::move(in));
        pthread_mutex_unlock(&mutex);
        sem_post(&itemsLeft);
    }

    // blocks if item cannot be popped
    std::vector<char> pop() {
        sem_wait(&itemsLeft);
        pthread_mutex_lock(&mutex);
        
        std::vector<char> ret;

        assert(!dataQueue.empty());

        ret = std::move(dataQueue.front());
        dataQueue.pop();
        
        pthread_mutex_unlock(&mutex);
        sem_post(&spaceLeft);
        return std::move(ret);
    }

    void clear() {
        pthread_mutex_lock(&mutex);
        while (!dataQueue.empty())
            dataQueue.pop();
        
        sem_destroy(&itemsLeft);
        sem_init(&itemsLeft, 0, 0);
        pthread_mutex_unlock(&mutex);

    }
};

// threadsafe queue for images
class ImageDataQueue {
    std::queue<std::vector<char>> dataQueue;
    pthread_mutex_t mutex;
    sem_t spaceLeft;
public:
    ImageDataQueue() {
        pthread_mutex_init(&mutex, NULL);
        sem_init(&spaceLeft, 0, FIFO_SIZE);
    }
    ~ImageDataQueue() {
        pthread_mutex_destroy(&mutex);
        sem_destroy(&spaceLeft);
    }

    void push(std::vector<char> && in) {
        sem_wait(&spaceLeft);
        pthread_mutex_lock(&mutex);
        dataQueue.push(std::move(in));
        pthread_mutex_unlock(&mutex);
    }

    // returns empty vector if item cannot be popped
    std::vector<char> try_pop() {
        pthread_mutex_lock(&mutex);
        std::vector<char> ret;
        if (!dataQueue.empty()) {
            ret = std::move(dataQueue.front());
            dataQueue.pop();
            sem_post(&spaceLeft); // technically would be better perf if this came outside the lock
        }
        pthread_mutex_unlock(&mutex);
        return std::move(ret);
    }
    
    void clear() {
        pthread_mutex_lock(&mutex);
        while (!dataQueue.empty())
            dataQueue.pop();
        pthread_mutex_unlock(&mutex);
    }
};

class ServerInfo;

struct ClientInfo {
    bool valid; // true if this ClientInfo represents an actual connection 
    int socket; // TCP socket for client

    pthread_t reciever;
    pthread_t sender;

    ImageDataQueue imageQueue; // input image queue
    ResultDataQueue resultsQueue; // output results queue

    ServerInfo* parent; // server that owns this client

    ClientInfo() : valid(false), socket(-1) {}
};

class ServerInfo {
public:
    sem_t imagesOnARM;
    sem_t imagesInFPGA;
    sem_t deadClients;

    std::queue<int> dest_client;

    std::array<ClientInfo, NUM_SIM_CLIENTS> clients;
    bool canMakeClient() {
        for (ClientInfo& c : clients) {if (!c.valid) return true;}
        return false;
    }
    void makeClient(int socket) {
        for (ClientInfo& c : clients) {
            if (!c.valid) {
                // found an empty slot
                c.valid = true;
                c.socket = socket;
                // TODO: maybe clear queues

                // make threads to handle client
                pthread_attr_t attr;
                pthread_attr_init(&attr);
                // set needed attr here
                
#ifdef DEBUG
        std::cout << "Making client threads" << std::endl; 
#endif
                pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
                pthread_create(&c.sender, &attr, transmitForever, (void*)&c);
                pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);
                pthread_create(&c.reciever, &attr, recieveForever, (void*)&c);

#ifdef DEBUG
        std::cout << "Made client threads" << std::endl; 
#endif
                pthread_attr_destroy(&attr);

                return;
            }
        }
        std::cout << "PROBLEM" << std::endl;
        // if none, maybe wait on a cv/semaphore
    }
    void destroyClient() {
        
    }

    ServerInfo() {
        for (ClientInfo& c : clients) {
            c.parent = this;
        }
        sem_init(&imagesOnARM, 0, 0);
        sem_init(&imagesInFPGA, 0, 0);
        sem_init(&deadClients, 0, NUM_SIM_CLIENTS);
    }
    ~ServerInfo() {
        sem_destroy(&imagesOnARM);
        sem_destroy(&imagesInFPGA);
        sem_destroy(&deadClients);
    }
};


// Global server info
ServerInfo serverInfo;

void* listenForever(void*) {
#ifdef DEBUG
        std::cout << "Starting listen thread" << std::endl; 
#endif
    
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
    if (res != 0 ) {std::cerr << "Error getting addr info" << std::endl; return (void*)1;}

    // okay, we've got the address. Now make a socket

    int sock;
    sock = socket(serv_info->ai_family, serv_info->ai_socktype, serv_info->ai_protocol);
    if (sock == -1) {std::cerr << "Error making socket" << std::endl; return (void*)1;}
    res = bind(sock, serv_info->ai_addr, serv_info->ai_addrlen);
    if (res == -1) {std::cerr << "Error binding to socket" << std::endl; return (void*)1;}
    res = listen(sock, 5); // support backlog of 5 clients
    if (res == -1) {std::cerr << "Error listening to socket" << std::endl; return (void*)1;}

    // okay, we are listening for TCP connections. Now lets respond to incoming connections
    
    // TODO: initFPGABus();

    sockaddr_storage client_addr;
    socklen_t client_addr_size = sizeof(client_addr);
    int client_sock;
    
    while (true) {
#ifdef DEBUG
        std::cout << "Checking for room for a client..." << std::endl; 
#endif
        sem_wait(&serverInfo.deadClients);
#ifdef DEBUG
        std::cout << "About to listen" << std::endl; 
#endif
        client_sock = accept(sock, (sockaddr*)&client_addr, &client_addr_size);
        std::cout << "Accepting a connection" << std::endl; 
        if (client_sock == -1) {std::cerr << "Error accepting connection" << std::endl; return (void*)1;}
        serverInfo.makeClient(client_sock);
#ifdef DEBUG
        std::cout << "Made a client" << std::endl; 
#endif
    }
}


void* manageFPGAForever(void*) {
#ifdef DEBUG
        std::cout << "Starting manager thread thread" << std::endl; 
#endif

    initFPGABus();

#ifdef DEBUG
        std::cout << "Initialized FPGA bus" << std::endl; 
#endif
    while (true) {
        // turnstile so that we don't busy-wait when there are no images to process
        sem_wait(&serverInfo.imagesOnARM);
        sem_post(&serverInfo.imagesOnARM);


#ifdef DEBUG
        std::cout << "Manager awoken" << std::endl; 
#endif
        

        // send images out to FPGA
        for (int i = 0; i < NUM_SIM_CLIENTS; ++i) {
            std::vector<char> pix_buf = serverInfo.clients[i].imageQueue.try_pop();
            if (pix_buf.size() != 0) {
                
                #ifdef DEBUG
                    std::cout << "Manager is sending to FPGA..." << std::endl; 
                #endif
                sem_wait(&serverInfo.imagesOnARM);
                serverInfo.dest_client.push(i);

                // decr main semaphore
                sendToFPGA(pix_buf);
                
                sem_post(&serverInfo.imagesInFPGA);
                #ifdef DEBUG
                    std::cout << "Sent image to FPGA" << std::endl;
                #endif

                

            }
        }
    }
}

void* manageFPGAForever2(void*) {
    while (true) {
        sem_wait(&serverInfo.imagesInFPGA);
        #ifdef DEBUG
            std::cout << "Waiting for response from FPGA" << std::endl;
        #endif
        int c = serverInfo.dest_client.front();
        serverInfo.dest_client.pop();
        
        std::vector<char> pix_buf(10 * 4);
        recvFromFPGA((int*)&pix_buf[0]);
        
        #ifdef DEBUG
            std::cout << "Recieved from FPGA" << std::endl;
        #endif
        serverInfo.clients[c].resultsQueue.push(std::move(pix_buf));
    }
}

void* recieveForever(void* clientInfo_ptr) {
#ifdef DEBUG
        std::cout << "Starting reciever thread" << std::endl; 
#endif
    int res;

    ClientInfo& c = *(ClientInfo*)clientInfo_ptr;
    
    std::vector<char> img_data; // // move outside loop to avoid excessive allocations.
    while (true) {
        
        //std::vector<char> pixbuf; 
        
        int32_t img_size;
        int offset = 0;
        while (offset < 4) {
            res = recv(c.socket, (char*)&img_size+offset, 4-offset, 0);
            if (res == -1) {std::cerr << "Error recieving msg" << std::endl; return (void*)1;}
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
                res = recv(c.socket, &img_data[offset], amt_to_read - offset, 0);
                if (res == -1) {std::cerr << "Error recieving msg" << std::endl; return (void*)1;}
                if (res == 0) {std::cerr << "Error connection closed unexpectedly" << std::endl; return (void*)1;}
                offset += res;
            }
            img_size -= amt_to_read;
        }

        // process image: deprecated due to offloading to FPGA
        // res = jpeg_to_neural(img_data, pixbuf);
        // if (res != 0) {return (void*)1;}

        // queue for access to FPGA
        c.imageQueue.push(std::move(img_data));
        sem_post(&serverInfo.imagesOnARM);
    }

    // destroy the client?
    c.resultsQueue.push({});
    std::cout << "Reciever quitting gracefully.." << std::endl;
}


void* transmitForever(void* clientInfo_ptr) {
#ifdef DEBUG
        std::cout << "Starting transmitter thread" << std::endl; 
#endif
    int res;

    ClientInfo& c = *(ClientInfo*)clientInfo_ptr;
    while (true) {
        auto pixbuf = c.resultsQueue.pop();
        // if resultsQueue.pop returns empty, then the connection is closed.
        if (pixbuf.size() == 0) break;

        int offset = 0;
        unsigned int net_size = htonl(pixbuf.size());
#ifdef DEBUG
        std::cout << "Sending result of size " << pixbuf.size() << std::endl; 
#endif
        while (offset < 4) {
            res = send(c.socket, (char*)&net_size+offset, 4-offset, 0);
            if (res == -1) {std::cerr << "Error sending msg" << std::endl; break; return (void*)1;}
            if (res == 0) break; // connection closed
            offset +=res;
        }
        if (offset != 4) break; // connection closed gracefully
        offset = 0;
        while (offset < pixbuf.size()) {
            res = send(c.socket, &pixbuf[offset], pixbuf.size() - offset, 0);
            if (res == -1) {std::cerr << "Error sending msg" << std::endl; return (void*)1;}
            if (res == 0) {std::cerr << "Error connection closed unexpectedly" << std::endl; return (void*)1;}
            offset += res;
        }
    }

    std::cout << "Transmitter waiting on reciever..." << std::endl;
    pthread_join(c.reciever, NULL);
    std::cout << "Transmitter quitting gracefully..." << std::endl;
    c.imageQueue.clear();
    c.resultsQueue.clear();
    close(c.socket);
    c.socket = -1;
    c.valid = false;
    sem_post(&serverInfo.deadClients);
    return NULL;
}

// The software server
int main(int argc, char* argv[]) {
   
    pthread_t manager, manager2, listener;
   std::cout << "Starting Server" <<std::endl;
    // create the listener and manager threads
    pthread_create(&manager,  NULL, manageFPGAForever, NULL);
    pthread_create(&manager2,  NULL, manageFPGAForever2, NULL);
    pthread_create(&listener, NULL, listenForever, NULL);



    pthread_join(manager, NULL);
    pthread_join(listener, NULL);

#ifdef DEBUG
        std::cout << "Succesfully recieved all images" << std::endl;
#endif

        
        
    std::cout << "Shutting down..." << std::endl;
}
