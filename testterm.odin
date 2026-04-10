package testterm

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




LOGFILE : ^os.File
/// Structure that describes the terminal window

Cell :: struct {
    glyph : u8,
    surface :^sdl3.Surface
}

Term :: struct {

    x : i32,
    y : i32,
    width : i32,
    height : i32,
    data : []Cell, /// < how do i want to store this..

}


winsize_t ::struct {
    row : u16,
    col : u16,
    xpixel : u16,
    ypixel : u16,
}
pty_t :: struct {
    primary, secondary : posix.FD
}

/// returns length of the escape sequence 
strip_esc_seq :: proc(buf : []byte,  buf_sz : c.ssize_t ) -> int {

    sz ::  cast(c.ssize_t)16
    seq_len := 0
    for i : c.ssize_t= 0 ; i < sz && i < buf_sz ; i+=1 {

        seq_len += 1

        if buf[i] >= cast(byte)65 && buf[i] <= cast(byte)90 { return seq_len } /// A - Z
        if buf[i] >= cast(byte)97 && buf[i] <= cast(byte)122 { return seq_len } /// a - z
    }
    return  0
}


run :: proc(pty: ^pty_t){

    running := true
    
    ev : sdl3.Event
    
    written := false
    

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
    color_fg := sdl3.Color{ 255, 255, 255, 255 } // white
    color_bg := sdl3.Color{ 100, 0, 0, 0 } // black

    

    ref_surface := ttf.RenderGlyph_Shaded(font, cast(u32)'a', color_fg, color_bg)
    ref_rect := sdl3.Rect{ x = 0, y = 0, w =ref_surface.w, h = ref_surface.h }

    term : Term = {
        x = 0,
        y = 0,
        width = (i32(ww) / ref_rect.w),
        height = (i32(wh) / ref_rect.h),
        data = make([]Cell, i32(width) * height),
    }


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
                //fmt.fprint(LOGFILE,buf[:n])
                //fmt.fprint(LOGFILE,"\n")
            }else{
                fmt.println("shell closed")
                return
            }
        }

        //write shell output to screen
        // Define font and size
        if redraw == true {

            if term.y + cast(i32)font_size >= wh {
                term.y = 0
                sdl3.FillSurfaceRect(surface, nil, 0)
            }
            if term.x >= ww {
                term.y += cast(i32)font_size
            }

            i : int
            for i = 0 ; i < n ; i+=1 {


                /// stripping the escape sequences
                len : int
                if buf[i] == 0x1B {
                    len = strip_esc_seq(buf[i:], n-i)
                }
                if len != 0 {
                    //fmt.println(esc_seq)
                    i += len - 1
                    continue
                }


                if glyphs[buf[i]] == nil {
                    tmp := [2]byte{ buf[i], 0 }
                    glyphs[buf[i]] = ttf.RenderGlyph_Shaded(font, cast(u32)buf[i], color_fg, color_bg)
                }

                dest_rect := sdl3.Rect{ x = term.x, y = term.y, w = glyphs[buf[i]].w, h = glyphs[buf[i]].h }

                /// stops (mostly) whitespace characters from being 'drawn' to the screen
                /// still need to deal with the [xxx following the \033 escape code though
                if ! (buf[i] < cast(u8) 32)  { 
                    sdl3.BlitSurface(glyphs[buf[i]], nil, surface, &dest_rect)
                }

                term.data[i].glyph = buf[i] 
                term.data[i].surface = glyphs[buf[i]] 
                //hi
                switch buf[i] {
                    case '\n':
                        term.y += cast(i32)font_size
                    case '\r': 
                        term.x = 0
                    case '\t':
                        term.x += TAB_WIDTH * dest_rect.w
                    case 0x08: ///backspace
                        // eventually this needs to be changed to move backwards by the amount of 
                        // space that the previous rune occupies(ed)
                        term.x -= dest_rect.w
                        dest_rect = sdl3.Rect{ x = term.x, y = term.y, w =glyphs[buf[i]].w, h = glyphs[buf[i]].h }
                        sdl3.FillSurfaceRect(surface, &dest_rect, 0)
                    case 0x07: /// bell
                        ;
                    case:
                        term.x += dest_rect.w
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
    if  i == 1 { fmt.eprintln("brah"); return}

    check = spawn(&pty)
    if ! check { fmt.eprintln("brah"); return}

    result := linux.ioctl(cast(linux.Fd)pty.primary, TIOCSWINSZ, 0)
    
    if ! sdl3.Init(sdl3.INIT_VIDEO) { fmt.eprintln("sdl3 init error", sdl3.GetError()); return}
    defer sdl3.Quit()


    if ! ttf.Init() { fmt.eprintln("ttf init error", sdl3.GetError()); return}
    defer ttf.Quit()

    flags := sdl3.WINDOW_RESIZABLE | sdl3.WINDOW_BORDERLESS
    window = sdl3.CreateWindow("test-term", width, height, flags)
    defer{ sdl3.DestroyWindow(window); window = nil}

    if window == nil{ fmt.eprintln(sdl3.GetError()); return}
    surface = sdl3.GetWindowSurface( window )
    if surface == nil { fmt.eprintln(sdl3.GetError()); return}

    sdl3.UpdateWindowSurface(window)

    run(&pty)
}
