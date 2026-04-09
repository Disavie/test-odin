package foreigntest

foreign import stdio "system:libc.a"
foreign import math "system:libc.a"
foreign import pty "system:libutil.a"

import "core:fmt"
import "core:c"

//foreign stdio {printf :: proc(cstr : cstring) ---}
//foreign math {pow :: proc(x , y : i64) -> i64 ---}

foreign pty { openpty :: proc(primary, secondary : ^c.int, name : [^]byte, tptr, winptr : ^byte) -> c.int --- }


main :: proc(){
    p : c.int 
    s : c.int
    i:= openpty(&p, &s, nil, nil, nil)
    fmt.println(i)
}
