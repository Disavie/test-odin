# OTerm is a terminal emulator written in Odin

> Motivation :
> Love of the game and I wanted to learn a new language

Known Issues:
- Currently buffer can misalign a read and will read part of an escape code or unicode which will cause a segfault

Below are some dev notes I am writing to myself
--- 

keep working on ansi parsing,, handling cursor movement

- https://pkg.odin-lang.org/core/terminal/ansi/
^ use this going forward for things instead of what ive been doing




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
