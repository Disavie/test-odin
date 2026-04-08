package sdl3test

import "vendor:sdl3"
import "core:fmt"
import posix "core:sys/posix"
import linux "core:sys/linux"
import "core:c"
import "core:time"
when ODIN_OS == .Linux do foreign import testc "lib/test.a"

TIOCSWINSZ :: 0x5414
TIOCSCTTY :: 0x540E

winsize_t ::struct {
    row : u16,
    col : u16,
    xpixel : u16,
    ypixel : u16,
}

sdl_t :: struct {
    win : ^sdl3.Window,
    surface : ^sdl3.Surface,
    event : sdl3.Event
}

foreign testc{
    myfunction :: proc() ---
    use_ioctl:: proc(fd : ^c.int, flags : int, wz : ^winsize_t) -> c.int --- 
}

pty_t :: struct {
    primary, secondary : posix.FD
}

setup_pty :: proc(pty: ^pty_t) -> bool {

    flags := posix.O_Flags{.RDWR, .NOCTTY}

    pty.primary = posix.posix_openpt(flags)
    if pty.primary == -1 {
        fmt.println("posix_openpt error")
        return false
    }
    if posix.grantpt(pty.primary) == posix.result.FAIL{
        fmt.println("grantpt error")
        return false
    }
    if posix.unlockpt(pty.primary) == posix.result.FAIL {
        fmt.println("unlock error")
        return false
    }


    secondary_name := posix.ptsname(pty.primary)
    if secondary_name == nil {
        fmt.println("ptsname error")
        return false
    }

    pty.secondary = posix.open(secondary_name,flags)
    if pty.secondary == -1{
        fmt.println("open error")
        return false
    }
    return true
}

spawn :: proc(pty : ^pty_t) -> bool{
    p : posix.pid_t

    p = posix.fork()

    if p == 0 {
        //child
        posix.close(pty.primary)
        posix.setsid()
        use_ioctl(cast(^i32)&pty.secondary, TIOCSCTTY, nil)


        posix.dup2(pty.secondary, 0)
        posix.dup2(pty.secondary, 1)
        posix.dup2(pty.secondary, 2)

        posix.close(pty.secondary)
        arg0 := cstring("/bin/sh")

        posix.execle(
            "/bin/sh",
            "-sh",
            nil,
            posix.environ,
        )
        return false;
    }else if p > 0 {
        //parent
        posix.close(pty.secondary)
        return true
    }
    fmt.println("fork error")
    return false
}

read_shell :: proc(){
    buffer := [256]rune

}


run :: proc(pty: ^pty_t, sdl : ^sdl_t){

    running := true
    ev := sdl.event


    for running{
        for sdl3.PollEvent(&ev){
            #partial switch ev.type {
            case sdl3.EventType.QUIT:
                running = false

            case sdl3.EventType.KEY_DOWN:
                fmt.println(rune(ev.key.key))
            }
        }
        //ms
        sdl3.Delay(50);
    }
}

main :: proc () {
    fmt.println("hello sdl3")
    // setup pty

    pty : pty_t = {
        primary = -1,
        secondary = -1,
    }
    check : bool
    check = setup_pty(&pty)
    if ! check {
        fmt.println("brah")
        return
    }
    check = spawn(&pty)
    if ! check {
        fmt.println("brah")
        return
    }
    fmt.println("worked!")
    ws : winsize_t = {
        row = 100,
        col = 100,
    }
    result := use_ioctl(cast(^i32)&pty.primary, TIOCSWINSZ, &ws)
    sdl : sdl_t = {}
    
    // setup sdl3 
    win: ^sdl3.Window = sdl3.CreateWindow("sdl3test", cast(i32)ws.row, cast(i32)ws.col, 
        sdl3.WINDOW_BORDERLESS | sdl3.WINDOW_RESIZABLE
        )
    if win == nil {
        fmt.println("Failed to create window")
        fmt.println(sdl3.GetError())
        return
    }
    defer {
        sdl3.DestroyWindow(win)
        win = nil
    }
    sdl.win = win
    surface : ^sdl3.Surface = sdl3.GetWindowSurface(win)
    sdl.surface = surface

    sdl3.UpdateWindowSurface(win)
    r : u8 = 0
    g : u8 = 0
    b : u8 = 0
    color := sdl3.MapSurfaceRGB(surface, r,g,b)
    sdl3.FillSurfaceRect(surface,nil,color)
    sdl3.UpdateWindowSurface(win)

    ev : sdl3.Event
    sdl.event = ev

    run(&pty, &sdl)

    surface = nil
    sdl3.Quit()
}
