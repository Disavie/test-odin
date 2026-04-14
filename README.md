# OTerm is a terminal emulator written in Odin

> Motivation :
> Love of the game and I wanted to learn a new language

Below are some dev notes I am writing to myself
--- 

keep working on ansi parsing,, handling cursor movement

- https://pkg.odin-lang.org/core/terminal/ansi/
^ use this going forward for things instead of what ive been doing


fix the arrow key interactions and inline editing
THERE IS AN ANSI COMMAND \e[1@<x> being sent to INSERT


```
    dch=\E[%p1%dP,                    # Delete N characters
    dch1=\E[P,                         # Delete 1 character
    il=\E[%p1%dL,                     # Insert N lines
    il1=\E[L,                          # Insert 1 line
    ich=\E[%p1%d@,                     # Insert N characters
    ech=\E[%p1%dX,                     # Erase N characters
```



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


