let s:NormalizeSymbol = {
            \ "nil":   v:null,
            \ "true":  v:true,
            \ "false": v:false
            \ }

function! vimpire#edn#EatWhitespace(input)
    let input = a:input

    while len(input) > 0 &&
                \ (input[0] == ","
                \  || input[0] == "\n"
                \  || input[0] == "\r"
                \  || input[0] =~ '\s')
        let input = input[1:]
    endwhile

    return input
endfunction

function! vimpire#edn#ReadSymbol(input, ...)
    let input = a:input
    let name = ""

    while len(input) > 0
        if input[0] =~ '[A-Za-z0-9.*+!_?$%&=<>:#-]'
            let name .= input[0]
            let input = input[1:]
        elseif input[0] == "/" && (a:0 == 0 || a:1)
            let namespace = name
            let [name, input] = vimpire#edn#ReadSymbol(input[1:], v:false)
            let name = namespace . "/" . name
            break
        else
            break
        endif
    endwhile

    return [ name, input ]
endfunction

let s:Keywords = {}

function! vimpire#edn#ReadKeyword(input)
    let [ sym1; input ] = a:input
    let [ sym, input ] = vimpire#edn#ReadSymbol(input)

    let sym = sym1 . sym

    if !has_key(s:Keywords, sym)
        let s:Keywords[sym] = sym
    endif

    return [ s:Keywords[sym], input ]
endfunction

function! vimpire#edn#ReadComment(input)
    let input = a:input

    while len(input) > 0 && input[0] != "\n"
        let input = input[1:]
    endwhile

    return [ v:none, input ]
endfunction

function! vimpire#edn#ReadNull(input)
    let [ ignore_, input ] = vimpire#edn#ReadInput(a:input)
    return [ v:none, input ]
endfunction

let s:Pair = { "[": "]", "(": ")", "{": "}" }
let s:ReversePair = { "]": "[", ")": "(", "}": "{" }

function! vimpire#edn#ReadList(input)
    let [ delim; input ] = a:input
    let values = []

    while len(input) > 0
        let [ value, input ] = vimpire#edn#ReadInput(input)
        call add(values, value)

        let input = vimpire#edn#EatWhitespace(input)
        if len(input) > 0 && input[0] == s:Pair[delim]
            return [ values, input[1:] ]
        endif
    endwhile

    throw "EDN: EOF while reading value"
endfunction

function! vimpire#edn#ReadSet(input)
    let [ values, input ] = vimpire#edn#ReadList(a:input)

    return [ { "edn/set": values }, input ]
endfunction

function! vimpire#edn#ReadMap(input)
    let [ values, input ] = vimpire#edn#ReadList(a:input)

    if len(values) % 2 == 1
        throw "EDN: unbalanced key/value pairs in map literal"
    endif

    let alist  = []
    let keys   = []
    let canMap = v:true
    while len(values) > 0
        let [ key, value; values ] = values

        for knownKey in keys
            if type(knownKey) == type(key) && knownKey == key
                throw "EDN: duplicate key in map literal"
            endif
        endfor
        call add(keys, key)

        call add(alist, [ key, value ])

        if type(key) != type("")
            let canMap = v:false
        endif
    endwhile

    if canMap == v:false
        return [ alist, input ]
    endif

    let amap = {}
    for [ key, value ] in alist
        let amap[key] = value
    endfor

    return [ amap, input ]
endfunction

function! vimpire#edn#ReadNumber(input)
    let [ num; input ] = a:input
    let isFloat = v:false

    while len(input) > 0
        if input[0] == "."
            let isFloat = v:true
        elseif input[0] == "E" || input[0] == "e"
            let isFloat = v:true
            if len(input) == 1
                throw "EDN: EOF while reading float literal"
            endif

            if input[1] == "+" || input[1] == "-"
                let num  .= join(input[0:1], "")
                let input = input[2:]
                continue
            endif
        elseif isFloat && input[0] == "M"
            break
        elseif !isFloat && input[0] == "N"
            break
        elseif has_key(s:Pair, input[0]) || has_key(s:ReversePair, input[0])
            break
        "elseif input[0] =~ '[#:",]'
        "    break
        elseif input[0] !~ '\d'
            break
        "    throw "EDN: invalid characters in number literal"
        endif

        let num  .= input[0]
        let input = input[1:]
    endwhile

    if isFloat
        return [ str2float(num), input ]
    else
        return [ str2nr(num), input ]
    endif
endfunction

let s:StringEscapes = {
            \ "t": "\t",
            \ "n": "\n",
            \ "r": "\r",
            \ "\\": "\\",
            \ "\"": "\""
            \ }

function! vimpire#edn#ReadString(input)
    let input = a:input[1:]
    let value = ""

    while len(input) > 0 && input[0] != "\""
        if input[0] == "\\"
            if len(input) == 1
                throw "EDN: EOF while reading string"
            endif

            if !has_key(s:StringEscapes, input[1])
                throw "EDN: invalid string escapes sequence: \\" . input[1]
            endif

            let value .= s:StringEscapes[input[1]]
            let input = input[2:]
        else
            let value .= input[0]
            let input = input[1:]
        endif
    endwhile

    return [ value, input[1:] ]
endfunction

let s:CharacterCodes = [
            \ ["newline", "\n"],
            \ ["return",  "\r"],
            \ ["space",   " " ],
            \ ["tab",     "\t"]
            \ ]

function! vimpire#edn#ReadCharacter(input)
    let input = a:input[1:]

    for [ code, char ] in s:CharacterCodes
        let l = len(code)
        if len(input) >= l && join(input[0:l-1], "") == code
            return [ char, input[l :] ]
        endif
    endfor

    return [ input[0], input[1:] ]
endfunction

if !exists("g:vimpire#edn#CustomReaders")
    let vimpire#edn#CustomReaders = {}
endif

function! vimpire#edn#ReadTag(input)
    let [ tag, input ] = vimpire#edn#ReadSymbol(a:input)
    let [ value, input ] = vimpire#edn#ReadInput(input)

    if has_key(g:vimpire#edn#CustomReaders, tag)
        return [ g:vimpire#edn#CustomReaders[tag](value), input ]
    else
        return [ {"edn/tag": tag, "edn/value": value }, input ]
    endif
endfunction

function! vimpire#edn#ReadHash(input)
    if len(a:input) == 0
        throw "EDN: EOF while reading value"
    endif

    if a:input[0] == "{"
        return vimpire#edn#ReadSet(a:input)
    elseif a:input[0] == "_"
        return vimpire#edn#ReadNull(a:input[1:])
    else
        return vimpire#edn#ReadTag(a:input)
    endif
endfunction

function! vimpire#edn#ReadInput(input, ...)
    let input = vimpire#edn#EatWhitespace(a:input)

    while len(input) > 0
        if input[0] == ";"
            let [ none_, input ] = vimpire#edn#ReadComment(input)
            let input = vimpire#edn#EatWhitespace(input)
        elseif input[0] == ":"
            return vimpire#edn#ReadKeyword(input)
        elseif input[0] == "\""
            return vimpire#edn#ReadString(input)
        elseif input[0] == "\\"
            return vimpire#edn#ReadCharacter(input)
        elseif input[0] == "("
            let [ value, input ] = vimpire#edn#ReadList(input)
            return [ { "edn/list": value }, input ]
        elseif input[0] == "["
            return vimpire#edn#ReadList(input)
        elseif input[0] == "{"
            return vimpire#edn#ReadMap(input)
        elseif input[0] == "#"
            let [ value, input ] = vimpire#edn#ReadHash(input[1:])
            if type(value) != type(v:none)
                return [ value, input ]
            else
                let input = vimpire#edn#EatWhitespace(input)
            endif
        elseif input[0] =~ '[+-]'
            if len(input) == 1
                throw "EDN: EOF while reading value"
            endif

            if input[1] =~ '\d'
                return vimpire#edn#ReadNumber(input)
            else
                let [ sym, input ] = vimpire#edn#ReadSymbol(input)
                return [ { "edn/symbol": sym }, input ]
            endif
        elseif input[0] =~ '\d'
            return vimpire#edn#ReadNumber(input)
        elseif input[0] =~ '[A-Za-z.*!_?$%&=<>]'
            let [ value, input ] = vimpire#edn#ReadSymbol(input)
            if has_key(s:NormalizeSymbol, value)
                return [ get(s:NormalizeSymbol, value), input ]
            else
                return [ { "edn/symbol": value }, input ]
            endif
        endif
    endwhile

    if a:0 == 0 || !a:1
        throw "EDN: EOF while reading value"
    endif

    return [ v:none, [] ]
endfunction

function! vimpire#edn#Read(input)
    let input  = split(a:input, '\zs')

    let [ value, input ] = vimpire#edn#ReadInput(input, v:true)

    return [ value, join(input, "") ]
endfunction

function! vimpire#edn#WriteNil()
    return "nil"
endfunction

function! vimpire#edn#WriteBool(thing)
    if a:thing
        return "true"
    else
        return "false"
    endif
endfunction

function! vimpire#edn#WriteNumber(thing)
    return string(a:thing)
endfunction

function! vimpire#edn#WriteList(thing, delim)
    " Special case: Empty list. Otherwise the first fails.
    if len(a:thing) == 0
        return a:delim . s:Pair[a:delim]
    endif

    let [ first; rest ] = a:thing
    let s = a:delim . vimpire#edn#Write(first)
    for x in rest
        let s .= " " . vimpire#edn#Write(x)
    endfor
    let s .= s:Pair[a:delim]

    return s
endfunction

function! vimpire#edn#WriteDict(thing)
    " Special case: Empty dict. Otherwise the first fails.
    if len(a:thing) == 0
        return "{}"
    endif

    " Special case: tagged literal
    if len(a:thing) == 2
                \ && has_key(a:thing, "edn/tag")
                \ && has_key(a:thing, "edn/value")
        return "#" . a:thing["edn/tag"]
                    \ . " " . vimpire#edn#Write(a:thing["edn/value"])
    endif

    " Special case: a list, not a vector
    if len(a:thing) == 1
                \ && has_key(a:thing, "edn/list")
        return vimpire#edn#WriteList(a:thing["edn/list"], "(")
    endif

    " Special case: a set, not a vector
    if len(a:thing) == 1
                \ && has_key(a:thing, "edn/set")
        return "#" . vimpire#edn#WriteList(a:thing["edn/set"], "{")
    endif

    " Special case: a symbol, not a string
    if len(a:thing) == 1
                \ && has_key(a:thing, "edn/symbol")
        return a:thing["edn/symbol"]
    endif

    let [ firstPair; rest ] = items(a:thing)
    let s = "{" . vimpire#edn#Write(firstPair[0])
                \ . " " . vimpire#edn#Write(firstPair[1])
    for [ key, value ] in rest
        let s .= " " . vimpire#edn#Write(key) . " " . vimpire#edn#Write
    endfor
    let s .= "}"

    return s
endfunction

function! vimpire#edn#WriteString(thing)
    if a:thing[0] == ":"
        return a:thing
    else
        let s = escape(a:thing, "\\")

        for [ c, e ] in items({"\t": "t", "\n": "n", "\r": "r", "\"": "\""})
            let s = substitute(s, c, '\\' . e, "g")
        endfor

        return '"' . s . '"'
    endif
endfunction

function! vimpire#edn#WriteFunc(thing)
    let fnName = substitute(string(a:thing),
                \ 'function(''\(.*\)'')',
                \ '\1',
                \ '')
    return "#vim/function " . vimpire#edn#Write(fnName)
endfunction

function! vimpire#edn#Write(thing)
    let t = type(a:thing)

    if t == v:t_none
        return vimpire#edn#WriteNil()
    elseif t == v:t_bool
        return vimpire#edn#WriteBool(a:thing)
    elseif t == v:t_number || t == v:t_float
        return vimpire#edn#WriteNumber(a:thing)
    elseif t == v:t_list
        return vimpire#edn#WriteList(a:thing, "[")
    elseif t == v:t_dict
        return vimpire#edn#WriteDict(a:thing)
    elseif t == v:t_string
        return vimpire#edn#WriteString(a:thing)
    elseif t == v:t_func
        return vimpire#edn#WriteFunc(a:thing)
    endif

    throw "EDN: Don't know how to write value: " . string(a:thing)
endfunction
