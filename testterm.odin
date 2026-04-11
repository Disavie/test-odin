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

window : ^sdl3.Window = nil
surface : ^sdl3.Surface = nil

Cell :: struct {
    glyph : u8,
    surface :^sdl3.Surface,

    row : i32,
    col : i32,
}

Term :: struct {

    c_col : i32,
    c_row : i32,
    width : i32,
    height : i32,
    data : []Cell, /// < how do i want to store this..

    front : i32,
    back : i32,

    ref_rect : ^sdl3.Rect,
    ref_surface : ^sdl3.Surface,

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
tdraw :: proc(term: ^Term) {
    length := min(term.width * term.height, i32(len(term.data)))

    for i: i32 = 0; i < length; i += 1 {
        cell := term.data[i]
        if cell.glyph == 0 || cell.surface == nil {
            continue
        }
        fmt.println(cast(rune)cell.glyph, " ", cell.col," ", cell.row)
        dest_rect := sdl3.Rect{
            x = cell.col * term.ref_rect.w,
            y = cell.row * term.ref_rect.h,
            w = term.ref_rect.w,
            h = term.ref_rect.h,
        }

        sdl3.BlitSurface(cell.surface, nil, surface, &dest_rect)
    }
}
run :: proc(pty: ^pty_t){

    running := true

    ev : sdl3.Event
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

    ref_surface := ttf.RenderGlyph_Shaded(font, cast(u32)'a', color_fg, color_bg)
    ref_rect := sdl3.Rect{ x = 0, y = 0, w =ref_surface.w, h = ref_surface.h }

    term : Term = {
        c_col = 0,
        c_row = 0,
        width = (i32(ww) / ref_rect.w),
        height = (i32(wh) / ref_rect.h),

        front = 0,
        back = 0,

        ref_rect = &ref_rect,
        ref_surface = ref_surface,
    }
    term.data = make([]Cell, i32(term.width * term.height))
    fmt.println( ref_rect.w, " ", ref_rect.h)
    fmt.println( term.width, " ", term.height)

    for running{

        buf : [256]byte

        // read shell output to buffer
        posix.FD_ZERO(&readable)
        posix.FD_SET(pty.primary, &readable)
        timeout : posix.timeval = {
            tv_sec = 0,
            tv_usec = 10000, // 10 ms timeout
                              //tv_usec = 10000, // 10 ms timeout
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

                switch buf[i]{

                case '\n':
                    term.c_row += 1
                case '\r':
                    term.c_col = 0
                case '\t':
                    term.c_col += TAB_WIDTH
                case 0x08:
                    if term.c_col > 0 { term.c_col -= 1 }
                case 0x07: 
                    ;
                case:
                    if glyphs[buf[i]] == nil {
                        glyphs[buf[i]] = ttf.RenderGlyph_Shaded(font, cast(u32)buf[i], color_fg, color_bg)
                    }
                    term.data[term.front].glyph   = buf[i]
                    term.data[term.front].surface = glyphs[buf[i]]
                    term.data[term.front].col     = term.c_col  // baked in at write time
                    term.data[term.front].row     = term.c_row
                    term.front    += 1
                    term.c_col += 1
                    if term.c_col >= term.width {               // wrap
                        term.c_col = 0
                        term.c_row += 1
                    }}
            }
            tdraw(&term)
            sdl3.UpdateWindowSurface(window)
        }
        for sdl3.PollEvent(&ev){
            #partial switch ev.type {
            case sdl3.EventType.WINDOW_RESIZED:
                fmt.println("Updated")
                //if resized i need to get a new surface
                surface = sdl3.GetWindowSurface(window)
                sdl3.GetWindowSize(window,&ww,&wh)
                sdl3.UpdateWindowSurface(window)

                term.width = (i32(ww) / term.ref_rect.w)
                term.height = (i32(wh) /term.ref_rect.h)
                data_n := make([]Cell, i32(term.width * term.height))

                for i in 0..< term.front {
                    data_n[i] = term.data[i] 
                }
                term.data = data_n


            case sdl3.EventType.QUIT:
                running = false
            case sdl3.EventType.KEY_DOWN:

                key := ev.key.key
                mod := ev.key.mod

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

        redraw = false
        sdl3.Delay(5);
    }
}


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
