// Client, should be run on like, a normal computer

// NOTE: this client is designed for benchmarking purposes
// It attempts to remove as much overhead as possible from the client itself
// and measure only the network transmission + server processing time
//
// To this end, it loads the entirety of the input dataset into memory before starting
// any timers.
//
// Sending and recieving of data is done concurrently, and log output is generated at the end
//
// The output of this program includes both throughput and latency metrics, however it is important
// that the affects of load on the server are understood.
//
// This program impliments two benchmark modes: batch mode, and interactive mode
//
// In batch mode, the client attempts to send as many images as possible while recieving concurrently
// in order to achieve the maximum throughput possible.
//
// In interactive mode, subsequent images are not sent until the result for the current image is recieved,
// in order to measure the latency for a single image.
//
// Both modes output the same set of statistics, but it is important to understand the difference between
// these modes in order to interpret the statistics

// currently WORK IN PROGRESS, stats output may be misleading and is subject to change

#include <stdlib.h>
#include <iostream>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <netinet/in.h>

struct Globals {
    int sock;
    
    int argc;
    char** argv;
};

Globals global;

uint64_t get_usec_time() {
    struct timeval tv;
    gettimeofday(&tv,NULL);
    
    // multiply seconds by 1,000,000 to convert to usec
    return  (uint64_t)1000000 * tv.tv_sec + tv.tv_usec;
}

#define MIN(x, y) ((x<=y)?x:y)

void sendAllImages() {
// send
    vector<vector<char>> images;

    // first, pre-load all the images
    for (int i = 1; i < global.argc; ++i) {
        int img_fd = open(global.argv[i], O_RDONLY);
        if (img_fd == -1) {
            std::cout << "File " << global.argv[i] << " could not be opened" << std::endl;
            return 1;
        }
        struct stat img_stat;
        fstat(img_fd, &img_stat);
        int32_t img_size = img_stat.st_size; // in bytes, compressed
        images[i-1].resize(img_size);
        
        int32_t offset = 0;

        read(img_fd, &images[i-1][0] + offset, img_size); // TODO: check error
    }


    for (int i = 0; i < global.argc - 1; ++i) {
        auto& img = images[i];

        int32_t network_size = htonl(img.size());
        
        
        res = send(global.sock, (char*)&network_size, 4, 0);
        if (res == -1) {std::cout << "Error sending msg" << std::endl; return 1;}

        int offset = 0;
        while (offset < img.size()) {
            res = send(global.sock, &images[i][0]+offset, img.size() - offset, 0);
            if (res == -1) {std::cout << "Error sending msg" << std::endl; return 1;}
            offset += res;
        }
    }

}

void recvAllResults() {
    std::vector<std::vector<char>> results;
        
    for (int i = 0; i < global.argc - 1; ++i) {
        unsigned int results_size;
        int offset = 0;
        while (offset < 4) {
            res = recv(global.sock, (char*)&results_size+offset, 4-offset, 0);
            if (res == -1) {std::cout << "Error recieving msg (size)" << std::endl; return 1;}
            if (res == 0) {std::cout << "Error connection closed unexpectedly" << std::endl; return 1;} // connection closed
            offset += res;
        }
        results_size = ntohl(results_size);
        
        results.push_back({});
        results[i].resize(results_size);

        offset = 0;
        while (offset < results_size) {
            res = recv(global.sock, (char*)&results[i][0]+offset, results_size - offset, 0);
            if (res == -1) {std::cout << "Error recieving msg" << std::endl; return 1;}
            if (res == 0) {std::cout << "Error connection closed unexpectedly" << std::endl; return 1;} // connection closed
            offset += res;
        }
    }

    // TODO: write results to file
}

int main(int argc, char* argv[]) {
    global.argc = argc;
    global.argv = argv;

    if (argc < 2) {
        std::cout << "Useage: client <filenames...>" << std::endl;
        return 1;
    }
    int res;
    addrinfo hints;
    addrinfo* serv_info;
    
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    //hints.ai_flags = AI_PASSIVE;

    res = getaddrinfo(
                "192.168.2.123",
                "6202", // arbitrary port number
                &hints,
                &serv_info);
    if (res != 0 ) {std::cout << "Error getting addr info" << std::endl; return 1;}

    // okay, we've got the address. Now make a socket

    //int sock;
    sock = socket(serv_info->ai_family, serv_info->ai_socktype, serv_info->ai_protocol);
    if (sock == -1) {std::cout << "Error making socket" << std::endl; return 1;}

    res = connect(sock, serv_info->ai_addr, serv_info->ai_addrlen);
    if (res == -1) {std::cout << "Error, could not connect to server" << std::endl; return 1;}

    global.sock = sock;

// send each image
    for (int i = 1; i < argc; ++i) {

        close(res_file);
        close(img_fd);
    }

    
#ifdef DEBUG
    std::cout << "Finished" << std::endl;
#endif
    
    //int offset = 0;
    //while (offset < 4096) {
    //    res = recv(sock, msg+offset, 4096 - offset, 0);
    //    if (res == -1) {std::cout << "Error recieving msg" << std::endl; return 1;}
    //    if (res == 0) {std::cout << "Error connection closed unexpectedly" << std::endl; return 1;}
    //    offset += res;
    //}

    //std::cout << "Succesfully recieved data" << std::endl;
    close(sock);
}
