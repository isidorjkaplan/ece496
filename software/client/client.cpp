// Client, should be run on like, a normal computer
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


uint64_t get_usec_time() {
    struct timeval tv;
    gettimeofday(&tv,NULL);
    
    // multiply seconds by 1,000,000 to convert to usec
    return  (uint64_t)1000000 * tv.tv_sec + tv.tv_usec;
}

#define MIN(x, y) ((x<=y)?x:y)

int main(int argc, char* argv[]) {
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

    int sock;
    sock = socket(serv_info->ai_family, serv_info->ai_socktype, serv_info->ai_protocol);
    if (sock == -1) {std::cout << "Error making socket" << std::endl; return 1;}

    res = connect(sock, serv_info->ai_addr, serv_info->ai_addrlen);
    if (res == -1) {std::cout << "Error, could not connect to server" << std::endl; return 1;}



// send each image
    for (int i = 1; i < argc; ++i) {
// send
        int img_fd = open(argv[i], O_RDONLY);
        if (img_fd == -1) {
            std::cout << "File " << argv[1] << " could not be opened" << std::endl;
            return 1;
        }
        struct stat img_stat;
        fstat(img_fd, &img_stat);
        int32_t img_size = img_stat.st_size; // in bytes, compressed

        // first, send size of image:
#ifdef DEBUG
        std::cout << "Sending image of size " << img_size << std::endl;
#endif
        int32_t img_size_network = htonl(img_size);
        res = send(sock, (char*)&img_size_network, 4, 0);
        if (res == -1) {std::cout << "Error sending msg" << std::endl; return 1;}

        // send image in chunks of 4KiB
        char msg[4096];
        
        while (img_size) {
            int amt_to_read = MIN(4096, img_size);
            read(img_fd, msg, amt_to_read); // todo: check error
            int offset = 0;
            while (offset < amt_to_read) {
                res = send(sock, msg+offset, amt_to_read - offset, 0);
                if (res == -1) {std::cout << "Error sending msg" << std::endl; return 1;}
                offset += res;
            }
            
            img_size -= amt_to_read;
        }
#ifdef DEBUG
        std::cout << "Sent image succesfully" << std::endl;
#endif
        
// recieve

        // recieve image in chunks of 4KiB
        unsigned int results_size;
        int offset = 0;
        while (offset < 4) {
            res = recv(sock, (char*)&results_size+offset, 4-offset, 0);
            if (res == -1) {std::cout << "Error recieving msg (size)" << std::endl; return 1;}
            if (res == 0) {std::cout << "Error connection closed unexpectedly" << std::endl; return 1;} // connection closed
            offset += res;
        }
        results_size = ntohl(results_size);
#ifdef DEBUG
        std::cout << "Recieving result of size " << results_size << std::endl;
#endif
        std::string result_file_name = argv[i];
        result_file_name += ".result";
        int res_file = open(result_file_name.c_str(), O_WRONLY | O_CREAT, S_IRWXU);
        if (res_file == -1) {std::cout << "Error opening output file " << errno << std::endl; return 1;}

        while (results_size) {
            int amt_to_read = MIN(4096, results_size);
            offset = 0;
            while (offset < amt_to_read) {
                res = recv(sock, &msg[offset], amt_to_read - offset, 0);
                if (res == -1) {std::cout << "Error recieving msg" << std::endl; return 1;}
                if (res == 0) {std::cout << "Error connection closed unexpectedly" << std::endl; return 1;}
                offset += res;
            }
            offset = 0;
            while (offset < amt_to_read) {
                res = write(res_file, msg+offset, amt_to_read-offset);
                if (res == -1) {std::cout << "Error writing to output file" << std::endl; return 1;}
                offset += res;
            }
            results_size -= amt_to_read;
        }
#ifdef DEBUG
        std::cout << "Wrote results to file" << std::endl;
#endif
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
