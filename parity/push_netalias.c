/* Only used inside the owned --network none fixture namespace. */
#include <arpa/inet.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
int main(void) {
 int fd=socket(AF_INET, SOCK_DGRAM, 0);
 struct ifreq request; memset(&request,0,sizeof(request)); strcpy(request.ifr_name,"lo:push");
 struct sockaddr_in *address=(struct sockaddr_in *)&request.ifr_addr;
 address->sin_family=AF_INET; inet_pton(AF_INET,"93.184.216.34",&address->sin_addr);
 if(ioctl(fd,SIOCSIFADDR,&request)<0) { perror("fixture loopback address"); return 1; }
 if(ioctl(fd,SIOCGIFFLAGS,&request)<0) return 1;
 request.ifr_flags |= IFF_UP;
 if(ioctl(fd,SIOCSIFFLAGS,&request)<0) return 1;
 close(fd); return 0;
}
