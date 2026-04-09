package sdl3test

import "vendor:sdl3"
import ttf "vendor:sdl3/ttf"
import "core:fmt"
import posix "core:sys/posix"
import linux "core:sys/linux"
import "core:c"
import charmap "map"

when ODIN_OS == .Linux do foreign import pty "system:libutil.a"
when ODIN_OS == .Linux do foreign import ioctl "system:libc.a"
foreign pty {openpty :: proc(primary, secondary : ^c.int, name : [^]byte, term : ^posix.termios, ws : ^winsize_t) -> c.int ---}

SHELL :: cstring("/bin/sh")
SHELL_PROFILE :: cstring("-sh")

TIOCSCTTY :: 0x540E
TIOCSWINSZ :: 0x5414

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



spawn :: proc(pty : ^pty_t) -> bool{
    p : posix.pid_t

    p = posix.fork()
    env : []cstring = { "TERM=dumb", nil}

    if p == 0 {
        //child
        posix.close(pty.primary)
        posix.setsid()
        linux.ioctl(cast(linux.Fd)pty.secondary, TIOCSCTTY, 0)


        posix.dup2(pty.secondary, 0)
        posix.dup2(pty.secondary, 1)
        posix.dup2(pty.secondary, 2)

        posix.close(pty.secondary)
        arg0 := cstring("/bin/sh")
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
    fmt.println("fork error")
    return false
}




run :: proc(pty: ^pty_t){

    running := true
    
    ev : sdl3.Event
    
    written := false
    
    x : i32 = 0
    y : i32 = 0

    str : cstring
    n : c.ssize_t
    readable : posix.fd_set

    ww, wh : c.int

    
    resized := false
    redraw := false

    font_path := cstring("/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf")
    font_size := 12
    font := ttf.OpenFont(font_path, cast(f32)font_size)
    if font == nil {
        fmt.println("Failed to load font:", sdl3.GetError())
        return
    }


    surface = sdl3.GetWindowSurface(window)
    sdl3.UpdateWindowSurface(window)
    sdl3.GetWindowSize(window,&ww,&wh)

    // Define color for the text
    color := sdl3.Color{ 255, 255, 255, 255 } // white

    for running{

        buf : [256]byte

        // read shell output to buffer
        posix.FD_ZERO(&readable)
        posix.FD_SET(pty.primary, &readable)
        timeout : posix.timeval = {
            tv_sec = 0,
            tv_usec = 10000, // 10 ms timeout
        }
        if posix.select(cast(c.int)pty.primary + 1, &readable, nil, nil,&timeout) > 0{
            n = posix.read(pty.primary, &buf[0], len(buf)- 1 )
            if n > 0 {
                redraw = true
                buf[n] = 0
                str = cstring(&buf[0])
                //debug
                //fmt.print(str)
            }else{
                fmt.println("shell closed")
                return
            }
        }
        
        
        //write shell output to screen
        // Define font and size
        if redraw == true {
            if y + cast(i32)font_size >= wh {
                //reset screen if at the bottom
                y = 0
                surface = sdl3.GetWindowSurface(window)
                sdl3.FillSurfaceRect(surface, nil, 0)
                sdl3.UpdateWindowSurface(window)
            }

            if x >= ww {
                y += cast(i32)font_size
            }

            for i in 0..<n {
                ch := buf[i]

                if ch == '\n' {
                    y += cast(i32)font_size
                    x = 0
                    continue
                }

                tmp : [2]byte
                tmp[0] = ch
                tmp[1] = 0

                text_surface := ttf.RenderText_Solid(font, cstring(&tmp[0]), 1, color)

                dest_rect := sdl3.Rect{ x = x, y = y, w = text_surface.w, h = text_surface.h }
                sdl3.BlitSurface(text_surface, nil, surface, &dest_rect)

                x += dest_rect.w

                sdl3.UpdateWindowSurface(window)
                sdl3.DestroySurface(text_surface)
            }
        }

                   //ms
            for sdl3.PollEvent(&ev){
                #partial switch ev.type {
                case sdl3.EventType.WINDOW_RESIZED:
                    fmt.println("Updated")
                    //if resized i need to get a new surface
                    sdl3.DestroySurface(surface)
                    surface = sdl3.GetWindowSurface(window)
                    sdl3.GetWindowSize(window,&wh,&wh)
                    sdl3.UpdateWindowSurface(window)
                case sdl3.EventType.QUIT:
                    running = false
                    /*
                case sdl3.EventType.KEY_DOWN:

//                    fmt.println(rune(ev.key.key))
                    key := ev.key.key
                    mod := ev.key.mod

                    ch := cast(u8)key
                    hold := false

                    if sdl3.Keymod.LSHIFT in mod || sdl3.Keymod.RSHIFT in mod{
                        // do this part, converting a -> A or symbols 1 -> ! etc..
                    }

                    if sdl3.Keymod.RCTRL in mod || sdl3.Keymod.LCTRL in mod{
                        ch &= 0x1F
                    }
                    if ! hold {
                        posix.write(pty.primary,&ch ,1)
                    }
                    */
                case sdl3.EventType.TEXT_INPUT:
                    posix.write(pty.primary, &ev.text.text, len(ev.text.text))

                }
            }
            //ms
            redraw = false
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
    check : bool = true

    term : posix.termios = {}
    secondary_name : [64]byte

    i:= openpty(cast(^i32)&pty.primary, cast(^i32)&pty.secondary, &secondary_name[0], nil, nil)
    if  i == 1 {
        fmt.println("brah")
        return
    }

    n : int
    for i in 0..=64 {
        if secondary_name[i] == 0{
            n = i
            break
        }
    }

    fmt.println(string(secondary_name[:n]))

    check = spawn(&pty)
    if ! check {
        fmt.println("brah")
        return
    }

    result := linux.ioctl(cast(linux.Fd)pty.primary, TIOCSWINSZ, 0)
    
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
    sdl3.UpdateWindowSurface(window)

    run(&pty)
}
