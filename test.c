#include <sys/ioctl.h>
#include <stdio.h>
#include <pty.h>
#include <unistd.h>
#include <termios.h>

int setup_pty(int  * primary_fd, int * secondary_fd, struct termios * term, struct winsize * win){

    int pid = openpty(primary_fd, secondary_fd, NULL, term, win);
    printf("%d", pid);
    if (pid == -1) {
        perror("error forking pty");
        return 1;
    }

    if (pid == 0) {

    }
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
