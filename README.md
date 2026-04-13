i dont need to switch to opengl with truetype , just switch from blitting to using a textrenderer in sdl, basically same thingggggggggg
also work on cursor movemnet
also work on how do i want to parse csi codes with multiple args that are ; separated? -> look online @ what other people have done probs



> todo // 
> refactoring
> work on parsing ansi ommands -> actually comply with the stuff i have under terminfo
> GLFW FOR WINDOW, FreeType for ttf->bitmap, opengl for gpu text rendering... 

//-> use FreeText to do text render instead of sdl3/ttf

-> change back to glfw or maybe just use wayland-client
-> utf8 encoding instead of rely on ascii

running 
```
    clear
```
with bash shell does not give me a HOME and CLEAR SCREEN esc sequence
but doing so with sh shell does?? what

when i set term=xterm-256color then i see the osc commands
osc operating system commands
something i need to handle later..


