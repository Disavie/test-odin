package sdl3test

import "vendor:sdl3"
import ttf "vendor:sdl3/ttf"
import "core:fmt"
import posix "core:sys/posix"
import linux "core:sys/linux"
import "core:c"
import "core:strings"
import "core:log"
import "core:os"
import  shift_map "map"

when ODIN_OS == .Linux do foreign import ioctl "system:libc.a"
when ODIN_OS == .Linux do foreign import pty "system:libutil.a"
foreign pty {openpty :: proc(primary, secondary : ^c.int, name : [^]byte, term : ^posix.termios, ws : ^winsize_t) -> c.int ---}
print_bytes :: proc(bytes : []byte) {for l  in bytes{fmt.print(l," ")} fmt.println()}


FONT_PATH :: "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf"
SHELL :: cstring("/bin/sh")
SHELL_PROFILE :: cstring("-bash")
LOG :: "log.log"
LOGFILE : ^os.File


TIOCSCTTY :: 0x540E
TIOCSWINSZ :: 0x5414
TAB_WIDTH :: 8

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
    /// setting the $TERM env to dumb
    /// causes less and other apps to show the THIS TERMINAL IS NOT COMPLETE warning
    env : []cstring = { "TERM=xterm-256color", nil}
    //env : []cstring = { "TERM=dumb", nil}

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
/// extracts the escape sequence from buf into dest 
strip_esc_seq :: proc(dest, buf : []byte, dest_sz, buf_sz : c.ssize_t ) -> int {

    sz ::  cast(c.ssize_t)16
    seq_len := 0
    for i : c.ssize_t= 0 ; i < sz && i < buf_sz ; i+=1 {

        char := buf[i]
        dest[i] = char
        seq_len += 1

        if char >= cast(byte)65 && char <= cast(byte)90 { return seq_len } /// A - Z
        if char >= cast(byte)97 && char <= cast(byte)122 { return seq_len } /// a - z
    }
    return  0
}


run :: proc(pty: ^pty_t){

    running := true
    
    ev : sdl3.Event
    
    written := false
    
    x : i32 = 0
    y : i32 = 0

    n : c.ssize_t
    readable : posix.fd_set

    ww, wh : c.int

    resized := false
    redraw := false

    font_path := cstring(FONT_PATH)
    font_size := 12
    font := ttf.OpenFont(font_path, cast(f32)font_size)
    if font == nil {
        fmt.println("Failed to load font:", sdl3.GetError())
        return
    }

    glyphs: map[u8]^sdl3.Surface


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
                fmt.fprint(LOGFILE,buf[:n])
                fmt.fprint(LOGFILE,"\n")
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
                //surface = sdl3.GetWindowSurface(window)
                sdl3.FillSurfaceRect(surface, nil, 0)

            }

            if x >= ww {
                y += cast(i32)font_size
            }

            i : int
            for i = 0 ; i < n ; i+=1 {

                ch := buf[i]
                /// stripping the escape sequences
                esc_buffer_size :: cast(c.ssize_t)16
                esc_seq : [esc_buffer_size]byte
                len : int
                if ch == 0x1B {
                    len = strip_esc_seq(esc_seq[:], buf[i:], esc_buffer_size, n-i)
                }
                if len != 0 {
                    //fmt.println(esc_seq)
                    i += len - 1
                    continue
                }

                tmp : [2]byte
                tmp[0] = ch
                tmp[1] = 0

                if glyphs[ch] == nil {
                    tmp := [2]byte{ ch, 0 }
                    glyphs[ch] = ttf.RenderText_Solid(font, cstring(&tmp[0]), 1, color)
                }

                dest_rect := sdl3.Rect{ x = x, y = y, w = glyphs[ch].w, h = glyphs[ch].h }

                /// stops (mostly) whitespace characters from being 'drawn' to the screen
                /// still need to deal with the [xxx following the \033 escape code though
                if ! (ch < cast(u8) 32)  { 
                    sdl3.BlitSurface(glyphs[ch], nil, surface, &dest_rect)
                }


                switch ch {
                    case '\n':
                        y += cast(i32)font_size
                        x = 0
                    case '\r': 
                        x = 0
                    case '\t':
                        x += TAB_WIDTH * dest_rect.w
                    case 0x08: ///backspace
                        // eventually this needs to be changed to move backwards by the amount of 
                        // space that the previous rune occupies(ed)
                        x -= dest_rect.w
                        dest_rect = sdl3.Rect{ x = x, y = y, w =glyphs[ch].w, h = glyphs[ch].h }
                        sdl3.FillSurfaceRect(surface, &dest_rect, 0)
                    case 0x07: /// bell
                        ;
                    case:
                        x += dest_rect.w
                }
            }
            sdl3.UpdateWindowSurface(window)
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
                case sdl3.EventType.KEY_DOWN:

                    key := ev.key.key
                    mod := ev.key.mod
                    scancode := ev.key.scancode /// < can maybe do someting here to query xkbcommon 
                    /// eduterm actually uses xkbcommon to do this and then writes it directly to the pty

                    ch := cast(u8)key
                    hold := false

                    if sdl3.Keymod.LSHIFT in mod || sdl3.Keymod.RSHIFT in mod{
                        if ch >= u8('a') && ch <= u8('z') {
                            ch -= u8('a' - 'A')
                            fmt.println(rune(ch))

                        } else {
                            ch = shift_map.shifted(ch)
                        }if ch == 0{
                            hold = true
                        }
                    }

                    if sdl3.Keymod.RCTRL in mod || sdl3.Keymod.LCTRL in mod{
                        ch &= 0x1F
                    }
                    if ! hold {
                        posix.write(pty.primary,&ch ,1)
                    }

                }
            }
            //ms
            redraw = false
            sdl3.Delay(5);
    }
}

window : ^sdl3.Window = nil
surface : ^sdl3.Surface = nil

main :: proc () {
    log, err := os.create(LOG)
    if err != nil { fmt.eprintf("log couldn't be created"); return }
    defer os.close(log)
    LOGFILE = log
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
