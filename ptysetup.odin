package testterm

import "core:fmt"
import posix "core:sys/posix"
import linux "core:sys/linux"
import "core:c"

when ODIN_OS == .Linux do foreign import ioctl "system:libc.a"
when ODIN_OS == .Linux do foreign import pty "system:libutil.a"

spawn :: proc(pty : ^pty_t) -> bool{
    p : posix.pid_t

    p = posix.fork()

    if p == 0 {
        //child
        posix.close(pty.primary)
        posix.setsid()
        linux.ioctl(cast(linux.Fd)pty.secondary, TIOCSCTTY, 0)


        posix.dup2(pty.secondary, 0)
        posix.dup2(pty.secondary, 1)
        posix.dup2(pty.secondary, 2)
        posix.close(pty.secondary)

        posix.setenv(cstring("TERM"),cstring("oterm"), true)
        args : []cstring = { SHELL, "-bash", nil }
        posix.execvp(SHELL_PATH,&args[0])
        return false;
    }else if p > 0 {
        //parent 
        posix.close(pty.secondary)
        return true
    }
    fmt.eprintln("fork error")
    return false
}
