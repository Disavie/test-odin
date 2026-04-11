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
    /// setting the $TERM env to dumb
    /// causes less and other apps to show the THIS TERMINAL IS NOT COMPLETE warning
    //env : []cstring = { "TERM=xterm-256color", nil}
    env : []cstring = { "TERM=xterm", nil}

    if p == 0 {
        //child
        posix.close(pty.primary)
        posix.setsid()
        linux.ioctl(cast(linux.Fd)pty.secondary, TIOCSCTTY, 0)


        posix.dup2(pty.secondary, 0)
        posix.dup2(pty.secondary, 1)
        posix.dup2(pty.secondary, 2)
        posix.close(pty.secondary)
        // arg0 "-" will use the default login profile
        // arg0 "-sh" uses the sh login profile
        // arg0 "-bash" uses the bash login profile... etc
        // arg0 "sh" will just open sh and not load a login profle
        posix.execle(
            SHELL,
            SHELL_PROFILE, 
            cast(^rune)nil,
            env,
        )
        return false;
    }else if p > 0 {
        //parent 
        posix.close(pty.secondary)
        return true
    }
    fmt.eprintln("fork error")
    return false
}
