// Client, should be run on like, a normal computer
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



int main(int argc, char* argv[]) {
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

    // placeholder message
    char msg[4096];
    for (int i = 0; i < 4096; ++i) {
        msg[i] = i % 12;
    }
    
    int offset = 0;
    while (offset < 4096) {
        res = send(sock, msg+offset, 4096 - offset, 0);
        if (res == -1) {std::cout << "Error sending msg" << std::endl; return 1;}
        offset += res;
    }

    std::cout << "Succesfully sent data" << std::endl;
    
    offset = 0;
    while (offset < 4096) {
        res = recv(sock, msg+offset, 4096 - offset, 0);
        if (res == -1) {std::cout << "Error recieving msg" << std::endl; return 1;}
        if (res == 0) {std::cout << "Error connection closed unexpectedly" << std::endl; return 1;}
        offset += res;
    }

    std::cout << "Succesfully recieved data" << std::endl;
    close(sock);
}
