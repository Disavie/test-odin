#include <sys/ioctl.h>
#include <stdio.h>
#include <pty.h>
#include <unistd.h>
#include <termios.h>

int setup_pty(int  * primary_fd, int * secondary_fd, char * name, struct termios * term, struct winsize * win){

    return openpty(primary_fd, secondary_fd, name, NULL, NULL);
}
int use_ioctl(int * fd , int flags, struct winsize * ws){
    if ( ws == NULL ){
        return ioctl(*fd, flags, NULL);
    }
    return ioctl(*fd, flags, ws);
}

void myfunction(){
    printf("Hello from C");
    fflush(stdout);
}
