#+feature dynamic-literals
package oterm

import "vendor:sdl3"


//this will eventually get moved to a config - ish file but for now they are just constants
FONT_SIZE :: 12
FONT :: "liberation/LiberationMono-Bold.ttf"
FONT_PATH :: "/usr/share/fonts/"+FONT
SHELL_PATH :: cstring("/bin/bash")
SHELL :: cstring("bash")
LOG :: "log.log"
TIOCSCTTY :: 0x540E
TIOCSWINSZ :: 0x5414
TAB_WIDTH :: 8
height :: 500
width :: 500

// Define color for the text
color_fg := sdl3.Color{ 255, 255, 255, 00 } // white
color_bg := sdl3.Color{ 0, 0 ,0 , 0 } 
// AA RR GG BB
term_bg : u32 = 0x00_00_00_ff  

alt_map := map[rune]rune{
'`' ='◆',
'a' ='▒',
'b' ='␉',
'c' ='␌',
'd' ='␍',
'e' ='␊',
'f' ='°',
'g' ='±',
'h' ='␤',
'i' ='␋',
'j' ='┘',
'k' ='┐',
'l' ='┌',
'm' ='└',
'n' ='┼',
'o' ='⎺',
'p' ='⎻',
'q' ='─',
'r' ='⎼',
's' ='⎽',
't' ='├',
'u' ='┤',
'v' ='┴',
'w' ='┬',
'x' ='│',
'y' ='≤',
'z' ='≥',
'{' ='π',
'|' ='≠',
'}' ='£',
'~' ='·',
}
