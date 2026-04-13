package oterm

import "core:fmt"

print_raw :: proc( byte_arr : []byte){
    for b in byte_arr {
        if b != 0 {
            switch (b){
                case 0x1b:
                    fmt.print("ESC")
                case:
                    fmt.print(rune(b))
            }
         }
    }
    fmt.println()
}

printd_s:: proc(args : ..string) { when DEBUG do fmt.println(args)  }
printd_i :: proc(args : ..int) { when DEBUG do fmt.println(args)  }
printd :: proc{ printd_i , printd_s }
print_bytes :: proc(bytes : []byte) {for l  in bytes{fmt.print(l," ")} fmt.println()}
