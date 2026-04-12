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


window : ^sdl3.Window = nil
surface : ^sdl3.Surface = nil

Pen :: struct {
    fg : sdl3.Color,
    bg : sdl3.Color,
    font : ^ttf.Font,
}
pen : Pen

Cell :: struct {
    glyph : u8,
    surface :^sdl3.Surface,

    row : i32,
    col : i32,
}
/// Structure that describes the terminal window
Term :: struct {

    c_col : i32,
    c_row : i32,
    width : i32,
    height : i32,
    data : []Cell, /// < how do i want to store this..

    ref_rect : ^sdl3.Rect,
    ref_surface : ^sdl3.Surface,

}
term : Term ///< this is the terminal

glyphs: map[u8]^sdl3.Surface

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

    sdl3.FillSurfaceRect(surface, nil, sdl3.MapSurfaceRGB(surface, 0, 0, 0))  // clear to black

    length := min(term.width * term.height, i32(len(term.data)))

    for i: i32 = 0; i < length; i += 1 {
        cell := term.data[i]
        if cell.glyph == 0 || cell.surface == nil {
            continue
        }
        //fmt.println(cast(rune)cell.glyph, " ", cell.col," ", cell.row)
        dest_rect := sdl3.Rect{
            x = cell.col * term.ref_rect.w,
            y = cell.row * term.ref_rect.h,
            w = term.ref_rect.w,
            h = term.ref_rect.h,
        }

        sdl3.BlitSurface(cell.surface, nil, surface, &dest_rect)
    }
}

scroll :: proc(term: ^Term) {
    // shift every row up by 1
    for row: i32 = 0; row < term.height - 1; row += 1 {
        for col: i32 = 0; col < term.width; col += 1 {
            src := (row + 1) * term.width + col
            dst := row * term.width + col
            term.data[dst] = term.data[src]
            term.data[dst].row = row  
        }
    }
    // clear the last row
    for col: i32 = 0; col < term.width; col += 1 {
        idx := (term.height - 1) * term.width + col
        term.data[idx] = {}
    }
    term.c_row = term.height - 1
}

set_winsize :: proc(pty: ^pty_t, term: ^Term, ww: c.int, wh: c.int) {
    ws := winsize_t{
        row    = u16(term.height),
        col    = u16(term.width),
        xpixel = u16(ww),
        ypixel = u16(wh),
    }
    linux.ioctl(cast(linux.Fd)pty.primary, TIOCSWINSZ, uintptr(&ws))
}

tread :: proc(pty : ^pty_t, buf : [^]byte, length : uint) -> c.ssize_t { 

    n := posix.read(pty.primary, &buf[0], length)
    if n > 0 {
        buf[n] = 0
    }else{
        fmt.println("shell closed")
        return -1
    }
    return n
}

t_check_rune :: proc(b : byte, term : ^Term){

    switch b{

    case '\n':
        term.c_row += 1
        if term.c_row >= term.height { scroll(term) }
        // clear the new row
        for col: i32 = 0; col < term.width; col += 1 {
            term.data[term.c_row * term.width + col] = {}
        }

    case '\r':
        term.c_col = 0
    case '\t':
        term.c_col = (term.c_col + TAB_WIDTH) &~ (TAB_WIDTH - 1) // snap to tab stop
    case 0x08:
        if term.c_col > 0 { 
            term.c_col -= 1
            idx := term.c_row * term.width + term.c_col
            term.data[idx] = {}  // clear the cell
        }
    case 0x07: 
        ;
    case:
        if glyphs[b] == nil {
            glyphs[b] = ttf.RenderGlyph_Shaded(pen.font, cast(u32)b, pen.fg, pen.bg)
        }
        idx := term.c_row * term.width + term.c_col  // derive index from cursor
        if idx >= i32(len(term.data)) { break }
        term.data[idx].glyph   = b
        term.data[idx].surface = glyphs[b]
        term.data[idx].col     = term.c_col
        term.data[idx].row     = term.c_row
        term.c_col += 1
        if term.c_col >= term.width {
            term.c_col = 0
            term.c_row += 1
            if term.c_row >= term.height {
                scroll(term)
            } else {
                // clear the new row we just wrapped onto
                for col: i32 = 0; col < term.width; col += 1 {
                    term.data[term.c_row * term.width + col] = {}
                }
            }
        } 
    }

}

t_handle_event :: proc(pty :^pty_t, event : sdl3.Event)-> bool{
    ww, wh : c.int 
    #partial switch event.type {
    case sdl3.EventType.WINDOW_RESIZED:
        surface = sdl3.GetWindowSurface(window)
        sdl3.GetWindowSize(window, &ww, &wh)

        new_width  := i32(ww) / term.ref_rect.w
        new_height := i32(wh) / term.ref_rect.h

        data_n := make([]Cell, new_width * new_height)

        for cell in term.data {
            if cell.glyph == 0 { continue }
            if cell.col >= new_width || cell.row >= new_height { continue }
            idx := cell.row * new_width + cell.col
            data_n[idx] = cell
        }
        delete(term.data)
        term.data   = data_n
        term.width  = new_width
        term.height = new_height
        set_winsize(pty, &term, term.width, term.height)

        tdraw(&term)
        sdl3.UpdateWindowSurface(window)

    case sdl3.EventType.QUIT:
        return false
    case sdl3.EventType.KEY_DOWN:

        key := sdl3.GetKeyFromScancode(event.key.scancode, event.key.mod, false )

        if sdl3.Keymod.RCTRL in event.key.mod || sdl3.Keymod.LCTRL in event.key.mod{
            key &= 0x1F
        }
        if key < 256 { /// UTF-8
            posix.write(pty.primary,cast(^byte)&key, 1)
        }
    }
    return true
}

run :: proc(pty: ^pty_t){
    running := true
    redraw := false

    ev : sdl3.Event
    n : c.ssize_t
    readable : posix.fd_set
    ww, wh : c.int

    sdl3.GetWindowSize(window,&ww,&wh)

    ref_surface := ttf.RenderGlyph_Shaded(pen.font, cast(u32)'a', pen.fg, pen.bg)
    ref_rect := sdl3.Rect{ x = 0, y = 0, w =ref_surface.w, h = ref_surface.h }

    term = {
        c_col = 0,
        c_row = 0,
        width = (i32(ww) / ref_rect.w),
        height = (i32(wh) / ref_rect.h),


        ref_rect = &ref_rect,
        ref_surface = ref_surface,
    }

    term.data = make([]Cell, i32(term.width * term.height))
    set_winsize(pty, &term, term.width, term.height)

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
            n = tread(pty,&buf[0],len(buf-1))
            if n == -1 {
                return
            }else if n > 0{
                redraw = true
            }

        }

        //write shell output to screen
        if redraw == true {
            i : int
            for i = 0 ; i < n ; i+=1 {
                esc_n : int
            ///============= WORK ON THIS TOMORROW ====================///////////
                if buf[i] == 0x1B {
                    esc_n = strip_esc_seq(buf[i:], n-i)
                }

                if esc_n != 0 {
                    /// TODO : handle these
                    i += esc_n - 1
                    continue
                }
                // ============================================///////


                t_check_rune(buf[i],&term)

            }
            tdraw(&term)
            sdl3.UpdateWindowSurface(window)
        }

        for sdl3.PollEvent(&ev){
            if !t_handle_event(pty,ev) { return }
        }

        redraw = false
        sdl3.Delay(10);
    }
}

main :: proc () {

    if ! sdl3.Init(sdl3.INIT_VIDEO) { fmt.eprintln("sdl3 init error", sdl3.GetError()); return}
    defer sdl3.Quit()

    if ! ttf.Init() { fmt.eprintln("ttf init error", sdl3.GetError()); return}
    defer ttf.Quit()

    pen.fg = color_fg
    pen.bg = color_bg
    font_path := cstring(FONT_PATH)
    font_size := FONT_SIZE
    font := ttf.OpenFont(font_path, cast(f32)font_size)
    if font == nil {
        fmt.println("Failed to load font:", font_path, "\n",sdl3.GetError())
        return
    }
    pen.font = font

    log, err := os.create(LOG)
    if err != nil { fmt.eprintf("log couldn't be created"); return }
    defer os.close(log)
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

    flags := sdl3.WINDOW_RESIZABLE | sdl3.WINDOW_BORDERLESS
    window = sdl3.CreateWindow("test-term", width, height, flags)
    defer{ sdl3.DestroyWindow(window); window = nil}

    if window == nil{ fmt.eprintln(sdl3.GetError()); return}
    surface = sdl3.GetWindowSurface( window )
    if surface == nil { fmt.eprintln(sdl3.GetError()); return}

    run(&pty)
}
