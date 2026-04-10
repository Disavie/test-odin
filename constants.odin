package testterm


//this will eventually get moved to a config - ish file but for now they are just constants
FONT_PATH :: "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf"
SHELL :: cstring("/bin/sh")
SHELL_PROFILE :: cstring("-bash")
LOG :: "log.log"
TIOCSCTTY :: 0x540E
TIOCSWINSZ :: 0x5414
TAB_WIDTH :: 8
height :: 500
width :: 500
