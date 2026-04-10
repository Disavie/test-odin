package test

import "core:fmt"
import "core:c"
import "vendor:glfw" // for creating window
import opengl "vendor:OpenGL" // for drawing to window
import  "vendor:sdl3" // for drawing text


when ODIN_OS == .Linux do foreign import testc "lib/test.a"

foreign testc{
    myfunction :: proc() ---
}

create_glfw_win :: proc() {

    stat : b32 = glfw.Init() 
    defer glfw.Terminate()
    if ! stat {
        fmt.println("Failed GLFW init")
        return
    }else{
        fmt.println("Yay!")
    }

    win : glfw.WindowHandle = glfw.CreateWindow(100, 100,  "Hello World", nil, nil )
    if win == nil {
        fmt.println("Failed to create window")
        return
    }

    fmt.println(win)
    glfw.MakeContextCurrent(win)
    glfw.ShowWindow(win)

    for !glfw.WindowShouldClose(win){
        glfw.PollEvents()
        glfw.SwapBuffers(win)
    }
}

sdl3_create_win :: proc(){

    stat := sdl3.Init(nil)

}

main :: proc () {

    fmt.println("Hello World")
    myfunction()

    for i in 0..= 10{
        fmt.println(i)
    }
    //create_glfw_win()

    fmt.println("Yippie!")

}
