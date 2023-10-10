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
    if (res != 0 ) {std::cout << "Error getting addr info" << std::endl; return 1;}

    // okay, we've got the address. Now make a socket

    int sock;
    sock = socket(serv_info->ai_family, serv_info->ai_socktype, serv_info->ai_protocol);
    if (sock == -1) {std::cout << "Error making socket" << std::endl; return 1;}
    res = bind(sock, serv_info->ai_addr, serv_info->ai_addrlen);
    if (res == -1) {std::cout << "Error binding to socket" << std::endl; return 1;}
    res = listen(sock, 5); // support backlog of 5 clients
    if (res == -1) {std::cout << "Error listening to socket" << std::endl; return 1;}

    // okay, we are listening for TCP connections. Now lets respond to incoming connections
    
    sockaddr_storage client_addr;
    socklen_t client_addr_size = sizeof(client_addr);
    int client_sock;
    client_sock = accept(sock, (sockaddr*)&client_addr, &client_addr_size);
    if (client_sock == -1) {std::cout << "Error accepting connection" << std::endl; return 1;}
    // okay, we have accepted 1 connection. Lets recieve some data
    
    char msg[4096];
    int offset = 0;
    while (offset < 4096) {
        res = recv(client_sock, msg+offset, 4096 - offset, 0);
        if (res == -1) {std::cout << "Error recieving msg" << std::endl; return 1;}
        if (res == 0) {std::cout << "Error connection closed unexpectedly" << std::endl; return 1;}
    }
    std::cout << "Succesfully recieved data" << std::endl;
    // just echo the packet

    offset = 0;
    while (offset < 4096) {
        res = send(client_sock, msg+offset, 4096 - offset, 0);
        if (res == -1) {std::cout << "Error sending msg" << std::endl; return 1;}
        offset += res;
    }
    std::cout << "Succesfully sent data" << std::endl;
    close(client_sock);
    close(sock);
}
