package testterm

import "vendor:sdl3"


//this will eventually get moved to a config - ish file but for now they are just constants
FONT_SIZE :: 12
FONT :: "liberation/LiberationMono-Bold.ttf"
FONT_PATH :: "/usr/share/fonts/"+FONT
SHELL_PATH :: cstring("/bin/bash")
SHELL :: cstring("bash")
OPTS :: cstring("--login")
LOG :: "log.log"
TIOCSCTTY :: 0x540E
TIOCSWINSZ :: 0x5414
TAB_WIDTH :: 8
height :: 500
width :: 500

// Define color for the text
color_fg := sdl3.Color{ 255, 255, 255, 255 } // white
color_bg := sdl3.Color{ 100, 0, 0, 0 } // black
