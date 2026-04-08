package sdl3test

import "vendor:sdl3"
import ttf "vendor:sdl3/ttf"
import "core:fmt"
import posix "core:sys/posix"
import linux "core:sys/linux"
import "core:c"
import "core:time"
when ODIN_OS == .Linux do foreign import testc "lib/test.a"

TIOCSWINSZ :: 0x5414
TIOCSCTTY :: 0x540E

width :: 500
height :: 500

winsize_t ::struct {
    row : u16,
    col : u16,
    xpixel : u16,
    ypixel : u16,
}


pty_t :: struct {
    primary, secondary : posix.FD
}
foreign testc{
    myfunction :: proc() ---
    use_ioctl:: proc(fd : ^c.int, flags : int, wz : ^winsize_t) -> c.int --- 
}

setup_sdl3 :: proc() -> bool {

    return true
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




run :: proc(pty: ^pty_t){

    running := true
    
    ev : sdl3.Event
    
    written := false
    
    w : i32
    h : i32


    fmt.println(sdl3.GetWindowSize(window,&w,&h))
    fmt.println(w," ",h,)
    str : cstring
    n : c.ssize_t
    
    resized := false

    for running{
        if ! resized{
            surface = sdl3.GetWindowSurface(window)
            fmt.println("resized")
            resized = true
        }

        buf : [256]byte

        // read shell output to buffer
        readable : posix.fd_set

        timeout : posix.timeval = {
            tv_sec = 0,
            tv_usec = 10000, // 10 ms timeout
        }
        posix.FD_ZERO(&readable)
        posix.FD_SET(pty.primary, &readable)
        if posix.select(cast(c.int)pty.primary + 1, &readable, nil, nil,&timeout) > 0{
            n = posix.read(pty.primary, &buf[0], len(buf)- 1 )
            if n > 0 {
                buf[n] = 0
                str = cstring(&buf[0])
                fmt.println(str)
            }
        }
        
        
        //write shell output to screen
            // Define font and size
        if str != nil {
            font_path := cstring("/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf")
            font_size := 12
            font := ttf.OpenFont(font_path, cast(f32)font_size)
            if font == nil {
                fmt.println("Failed to load font:", sdl3.GetError())
                return
            }

            // Define color for the text
            color := sdl3.Color{ 255, 255, 255, 255 } // white

                   // Render text to a surface
                   text_surface := ttf.RenderText_Solid(font, str, uint(n), color)
                   if text_surface == nil {
                       fmt.println("Failed to create text surface:", sdl3.GetError())
                       return
                   }

                   // Blit the text surface onto the main surface (or your window surface)
                   sdl3.BlitSurface(text_surface, nil, surface, nil)

                   // Update the window to reflect changes
        }
        sdl3.UpdateWindowSurface(window)

                   //ms
            for sdl3.PollEvent(&ev){
                #partial switch ev.type {
                case sdl3.EventType.WINDOW_RESIZED:
                    fmt.println("Updated")
                    //surface = sdl3.GetWindowSurface(window)
                    sdl3.UpdateWindowSurface(window)
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

window : ^sdl3.Window = nil
surface : ^sdl3.Surface = nil

main :: proc () {
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
        row = width,
        col = height,
    }
    result := use_ioctl(cast(^i32)&pty.primary, TIOCSWINSZ, &ws)
    
    if ! sdl3.Init(sdl3.INIT_VIDEO) {
        fmt.println("sdl3 init error", sdl3.GetError())
        return
    }
    defer sdl3.Quit()


    if ! ttf.Init() {
        fmt.println("ttf init error", sdl3.GetError())
        return
    }
    defer ttf.Quit()

    flags := sdl3.WINDOW_RESIZABLE | sdl3.WINDOW_BORDERLESS
    window = sdl3.CreateWindow("test-term", width, height, flags)
    defer{ 
        sdl3.DestroyWindow(window)
        window = nil
    }
    if window == nil{
        fmt.println(sdl3.GetError())
        return
    }
    surface = sdl3.GetWindowSurface( window )
    if surface == nil {
        fmt.println(sdl3.GetError())
        return
    }
    r : u8 = 0
    g : u8 = 0
    b:  u8 = 0
    a:  u8 = 255
    color := sdl3.Color({r,g,b,a})
    //sdl3.FillSurfaceRect(surface,color)
    sdl3.UpdateWindowSurface(window)

    run(&pty)
}
