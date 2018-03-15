function! vimpire#edn#IsMagical(form, type)
    return has_key(a:form, a:type) ? v:true : v:false
endfunction

function! vimpire#edn#IsTaggedLiteral(form, ...)
    return (len(a:form) == 2
                \   && has_key(a:form, "edn/tag")
                \   && has_key(a:form, "edn/value")
                \   && (a:0 == 0 || a:form["edn/tag"] == a:1))
                \ ? v:true : v:false
endfunction

let s:NormalizeSymbol = {
            \ "nil":   v:null,
            \ "true":  v:true,
            \ "false": v:false
            \ }

function! vimpire#edn#EatWhitespace(input)
    let ws = matchstr(a:input, '^\([,\n\r]\|\s\)*')
    return strpart(a:input, strlen(ws))
endfunction

function! vimpire#edn#Symbol(sym, ...)
    let sym = {"edn/symbol": a:sym}
    if a:0 > 0 && a:1 isnot g:vimpire#Nil
        let sym["edn/namespace"] = a:1
    endif

    return sym
endfunction

function! vimpire#edn#ReadSymbol(input)
    let nspace = g:vimpire#Nil
    let sym    = matchstr(a:input, "^[A-Za-z0-9.*+'!_?$%&=<>:#-]\\+")
    let input  = strpart(a:input, strlen(sym))

    if input[0] == "/"
        let nspace = sym
        let sym = matchstr(input, "^/[A-Za-z0-9.*+'!_?$%&=<>:#-]\\+")
        if sym == ""
            return [g:vimpire#Nil, a:input]
        endif

        let input = strpart(input, strlen(sym))
        let sym   = strpart(sym, 1)
    endif

    return [vimpire#edn#Symbol(sym, nspace), input]
endfunction

let s:Keywords = {}

function! vimpire#edn#Keyword(kw, ...)
    let kw = {"edn/keyword": a:kw}
    if a:0 > 0 && a:1 isnot g:vimpire#Nil
        let kw["edn/namespace"] = a:1
    endif

    let k = vimpire#edn#Write(kw)
    if !has_key(s:Keywords, k)
        let s:Keywords[k] = kw
    endif

    return s:Keywords[k]
endfunction

function! vimpire#edn#ReadKeyword(input)
    let [kw, input] = vimpire#edn#ReadSymbol(strpart(a:input, 1))

    let kw = vimpire#edn#Keyword(kw["edn/symbol"],
                \ get(kw, "edn/namespace", g:vimpire#Nil))

    return [kw, input]
endfunction

function! vimpire#edn#ReadComment(input)
    let comment = matchstr(a:input, '[^\n]*\n')
    let input   = strpart(a:input, strlen(comment))

    return [g:vimpire#Nil, input]
endfunction

function! vimpire#edn#ReadNull(input)
    let [ignore_, input] = vimpire#edn#ReadInput(a:input)
    return [g:vimpire#Nil, input]
endfunction

let s:Pair = { "[": "]", "(": ")", "{": "}" }
let s:ReversePair = { "]": "[", ")": "(", "}": "{" }

function! vimpire#edn#ReadList(input)
    let delim = a:input[0]
    let input = strpart(a:input, 1)

    let values = []
    while len(input) > 0
        let input = vimpire#edn#EatWhitespace(input)
        if strlen(input) == 0
            throw "EDN: EOF while reading value"
        endif

        if input[0] == s:Pair[delim]
            return [values, strpart(input, 1)]
        endif

        let [value, input] = vimpire#edn#ReadInput(input)
        call add(values, value)
    endwhile
endfunction

function! vimpire#edn#ReadSet(input)
    let [values, input] = vimpire#edn#ReadList(a:input)
    return [{"edn/set": values}, input]
endfunction

function! vimpire#edn#ReadMap(input)
    let [values, input] = vimpire#edn#ReadList(a:input)

    if len(values) % 2 == 1
        throw "EDN: unbalanced key/value pairs in map literal"
    endif

    let alist  = []
    let keys   = []
    let canMap = v:true
    while len(values) > 0
        let [key, value; values] = values

        for knownKey in keys
            if type(knownKey) == type(key) && knownKey == key
                throw "EDN: duplicate key in map literal"
            endif
        endfor
        call add(keys, key)

        call add(alist, [key, value])

        if type(key) != type("")
            let canMap = v:false
        endif
    endwhile

    if canMap == v:false
        return [{'edn/map': alist}, input]
    endif

    let amap = {}
    for [key, value] in alist
        let amap[key] = value
    endfor

    return [amap, input]
endfunction

function! vimpire#edn#ReadNumber(input)
    let result = matchstr(a:input,
                \ '^[+-]\?\d\+\(\.\d\+\)\?\([eE][+-]\?\d\+\)\?[MN]\?')

    if result == ""
        return [g:vimpire#Nil, a:input]
    endif

    let input = strpart(a:input, strlen(result))

    let end = strlen(result) - 1
    if result[end] == "M" || result[end] == "N"
        let result = strpart(result, 0, end)
    endif

    if result =~ '\(\.\|[eEM]\)'
        let result = str2float(result)
    else
        let result = str2nr(result)
    endif

    return [result, input]
endfunction

function! vimpire#edn#ReadString(input)
    let result = matchstr(a:input, '^"\([^"\\]*\(\\.[^"\\]*\)*\)"')
    if result == ""
        throw "EDN: EOF while reading value"
    endif

    let input  = strpart(a:input, strlen(result))
    let result = eval(result)

    return [result, input]
endfunction

let s:CharacterCodes = {
            \ "newline": "\n",
            \ "return":  "\r",
            \ "space":   " " ,
            \ "tab":     "\t"
            \ }

" FIXME: \uxxxx style unicode chars are missing.
function! vimpire#edn#ReadCharacter(input)
    let result = matchstr(a:input, '^\\\(newline\|return\|space\|tab\|\S\)')
    let input  = strpart(a:input, strlen(result))

    let result = strpart(result, 1)
    if has_key(s:CharacterCodes, result)
        let result = s:CharacterCodes[result]
    endif

    return [result, input]
endfunction

if !exists("g:vimpire_edn_custom_readers")
    let g:vimpire_edn_custom_readers = {}
endif

function! vimpire#edn#ReadTag(input)
    let [tag, input] = vimpire#edn#ReadSymbol(a:input)
    if tag is g:vimpire#Nil
        throw "EDN: invalid tag symbol"
    endif

    let [value, input] = vimpire#edn#ReadInput(input)

    let tags = vimpire#edn#Simplify(tag)
    if has_key(g:vimpire_edn_custom_readers, tags)
        return [g:vimpire_edn_custom_readers[tags](value), input]
    else
        return [{"edn/tag": tag, "edn/value": value}, input]
    endif
endfunction

function! vimpire#edn#ReadHash(input)
    if strlen(a:input) == 0
        throw "EDN: EOF while reading value"
    endif

    if a:input[0] == "{"
        return vimpire#edn#ReadSet(a:input)
    elseif a:input[0] == "_"
        return vimpire#edn#ReadNull(strpart(a:input, 1))
    else
        return vimpire#edn#ReadTag(a:input)
    endif
endfunction

function! vimpire#edn#ReadInput(input, ...)
    let input = vimpire#edn#EatWhitespace(a:input)

    while len(input) > 0
        if input[0] == ";"
            let [none_, input] = vimpire#edn#ReadComment(input)
            let input = vimpire#edn#EatWhitespace(input)
        elseif input[0] == ":"
            return vimpire#edn#ReadKeyword(input)
        elseif input[0] == "\""
            return vimpire#edn#ReadString(input)
        elseif input[0] == "\\"
            return vimpire#edn#ReadCharacter(input)
        elseif input[0] == "("
            let [value, input] = vimpire#edn#ReadList(input)
            return [{"edn/list": value}, input]
        elseif input[0] == "["
            return vimpire#edn#ReadList(input)
        elseif input[0] == "{"
            return vimpire#edn#ReadMap(input)
        elseif input[0] == "#"
            let [value, input] = vimpire#edn#ReadHash(strpart(input, 1))
            if value isnot g:vimpire#Nil
                return [value, input]
            else
                let input = vimpire#edn#EatWhitespace(input)
            endif
        elseif input[0] =~ '[+-]'
            if strlen(input) > 1 && input[1] =~ '\d'
                return vimpire#edn#ReadNumber(input)
            else
                return vimpire#edn#ReadSymbol(input)
            endif
        elseif input[0] =~ '\d'
            return vimpire#edn#ReadNumber(input)
        elseif input[0] =~ '[A-Za-z.*!_?$%&=<>]'
            let [value, input] = vimpire#edn#ReadSymbol(input)
            if !has_key(value, "edn/namespace")
                        \ && has_key(s:NormalizeSymbol, value["edn/symbol"])
                return [s:NormalizeSymbol[value["edn/symbol"]], input]
            else
                return [value, input]
            endif
        endif
    endwhile

    if a:0 == 0 || !a:1
        throw "EDN: EOF while reading value"
    endif

    return [g:vimpire#Nil, ""]
endfunction

function! vimpire#edn#Read(input)
    return vimpire#edn#ReadInput(a:input, v:true)
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

function! vimpire#edn#WriteSymbol(sym)
    return (has_key(a:sym, "edn/namespace") ?
                \   a:sym["edn/namespace"] . "/" : "")
                \ . a:sym["edn/symbol"]
endfunction

function! vimpire#edn#WriteKeyword(kw)
    return ":" . (has_key(a:kw, "edn/namespace") ?
                \   a:kw["edn/namespace"] . "/" : "")
                \ . a:kw["edn/keyword"]
endfunction

function! vimpire#edn#WriteDict(thing)
    let thing = a:thing

    " Special case: Empty dict. Otherwise the first fails.
    if len(thing) == 0
        return "{}"
    endif

    " Special case: tagged literal
    if vimpire#edn#IsTaggedLiteral(thing)
        return "#" . vimpire#edn#Write(thing["edn/tag"])
                    \ . " " . vimpire#edn#Write(thing["edn/value"])
    endif

    " Special case: a list, not a vector
    if vimpire#edn#IsMagical(thing, "edn/list")
        return vimpire#edn#WriteList(thing["edn/list"], "(")
    endif

    " Special case: a set, not a vector
    if vimpire#edn#IsMagical(thing, "edn/set")
        return "#" . vimpire#edn#WriteList(thing["edn/set"], "{")
    endif

    " Special case: a keyword, not a string
    if vimpire#edn#IsMagical(thing, "edn/keyword")
        return vimpire#edn#WriteKeyword(thing)
    endif

    " Special case: a symbol, not a string
    if vimpire#edn#IsMagical(thing, "edn/symbol")
        return vimpire#edn#WriteSymbol(thing)
    endif

    " Special case: a map, not a vector
    if vimpire#edn#IsMagical(thing, "edn/map")
        let thing = thing["edn/map"]
    else
        let thing = items(thing)
    endif

    let [ firstPair; rest ] = thing
    let s = "{" . vimpire#edn#Write(firstPair[0])
                \ . " " . vimpire#edn#Write(firstPair[1])
    for [ key, value ] in rest
        let s .= " " . vimpire#edn#Write(key) . " " . vimpire#edn#Write(value)
    endfor
    let s .= "}"

    return s
endfunction

function! vimpire#edn#WriteString(thing)
    let s = escape(a:thing, "\\")

    for [ c, e ] in items({"\t": "t", "\n": "n", "\r": "r", "\"": "\""})
        let s = substitute(s, c, '\\' . e, "g")
    endfor

    return '"' . s . '"'
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

    if a:thing is v:null
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

function! vimpire#edn#Simplify(form)
    let t = type(a:form)

    if a:form is g:vimpire#Nil
        return v:null
    elseif t == v:t_list
        let f = []
        for x in a:form
            call add(f, vimpire#edn#Simplify(x))
        endfor
        return f
    elseif t == v:t_dict
        " Special case: Elisions are left alone.
        if vimpire#edn#IsTaggedLiteral(a:form,
                    \ vimpire#edn#Symbol("...", "unrepl"))
            " Special case: If the associated value is nil, then this
            " elision is for the key of a map. We return a pure string
            " to be able use a vim map. The true elision is put in the
            " value.
            if a:form["edn/value"] is v:null
                return "unrepl/..."
            else
                return a:form
            endif
        " Special case: Namespaces have their symbol translated.
        elseif vimpire#edn#IsTaggedLiteral(a:form,
                    \ vimpire#edn#Symbol("ns", "unrepl"))
            return vimpire#edn#Simplify(a:form["edn/value"])
        " Special case: Other tagged literals are stringified.
        elseif vimpire#edn#IsTaggedLiteral(a:form)
            return vimpire#edn#Write(a:form)
        " Special case: Symbols are translated to strings.
        elseif vimpire#edn#IsMagical(a:form, "edn/symbol")
            return vimpire#edn#Write(a:form)
        " Special case: Keywords are translated to strings.
        elseif vimpire#edn#IsMagical(a:form, "edn/keyword")
            return vimpire#edn#Write(a:form)
        " Special case: Lists are translated to vectors.
        elseif vimpire#edn#IsMagical(a:form, "edn/list")
            return vimpire#edn#Simplify(a:form["edn/list"])
        " Special case: Sets are translated to vectors.
        elseif vimpire#edn#IsMagical(a:form, "edn/set")
            return vimpire#edn#Simplify(a:form["edn/set"])
        " Special case: Alists are translated to maps. In particalur
        " at least one key is stringified.
        elseif vimpire#edn#IsMagical(a:form, "edn/map")
            let f = {}
            for [ k, v ] in a:form["edn/map"]
                let ks = vimpire#edn#Simplify(k)
                let vs = vimpire#edn#Simplify(v)
                let f[ks] = vs
            endfor
            return f
        " For a true vim map, we can skip the key handling.
        else
            let f = {}
            for [ k, v ] in items(a:form)
                let f[k] = vimpire#edn#Simplify(v)
            endfor
            return f
        endif
    " Other non-compound values, we can leave alone.
    else
        return a:form
    endif
endfunction

function! vimpire#edn#SimplifyMap(form)
    if vimpire#edn#IsMagical(a:form, "edn/map")
        let m = {}
        for [k, v] in a:form["edn/map"]
            let ks = vimpire#edn#Simplify(k)
            let m[ks] = v
        endfor
        return m
    else
        return a:form
    endif
endfunction
