package charmap

shifted :: proc(ch: u8) -> u8 {
    switch ch {
    case '1': return '!'
    case '2': return '@'
    case '3': return '#'
    case '4': return '$'
    case '5': return '%'
    case '6': return '^'
    case '7': return '&'
    case '8': return '*'
    case '9': return '('
    case '0': return ')'
    case '-': return '_'
    case '=': return '+'
    case '[': return '{'
    case ']': return '}'
    case '\\': return '|'
    case ';': return ':'
    case '\'': return '"'
    case ',': return '<'
    case '.': return '>'
    case '/': return '?'
    case '`': return '~'
    }
    return 0
}

