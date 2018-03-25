function! vimpire#edn#IsMagical(form, ...)
    if type(a:form) == v:t_dict
        if a:0 > 0
            return has_key(a:form, a:1) ? v:true : v:false
        elseif has_key(a:form, "edn/list")
                    \ || has_key(a:form, "edn/set")
                    \ || has_key(a:form, "edn/map")
                    \ || has_key(a:form, "edn/symbol")
                    \ || has_key(a:form, "edn/keyword")
                    \ || has_key(a:form, "edn/char")
                    \ || has_key(a:form, "edn/tag")
            return v:true
        endif
    endif
    return v:false
endfunction

function! vimpire#edn#IsTaggedLiteral(form, ...)
    return (type(a:form) == v:t_dict
                \   && len(a:form) == 2
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

function! vimpire#edn#Symbol(...)
    if a:0 == 1
        let sym = {"edn/symbol": a:1}
    else
        let sym = {"edn/symbol": a:2}
    endif

    if a:0 == 2 && a:1 isnot g:vimpire#Nil
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

    return [vimpire#edn#Symbol(nspace, sym), input]
endfunction

let s:Keywords = {}

function! vimpire#edn#Keyword(...)
    if a:0 == 1
        let kw = {"edn/keyword": a:1}
    else
        let kw = {"edn/keyword": a:2}
    endif

    if a:0 == 2 && a:1 isnot g:vimpire#Nil
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

    let kw = vimpire#edn#Keyword(
                \ get(kw, "edn/namespace", g:vimpire#Nil),
                \ kw["edn/symbol"])

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

function! vimpire#edn#List(elements)
    return {"edn/list": a:elements}
endfunction

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

function! vimpire#edn#Set(elements)
    return {"edn/set": a:elements}
endfunction

function! vimpire#edn#ReadSet(input)
    let [values, input] = vimpire#edn#ReadList(a:input)
    return [vimpire#edn#Set(values), input]
endfunction

function! vimpire#edn#Map(list)
    let map = {}
    for [k, v] in a:list
        if type(k) != v:t_string
            break
        endif
        let map[k] = v
    endfor

    if len(map) == len(a:list)
        return map
    else
        return {"edn/map": a:list}
    endif
endfunction

function! vimpire#edn#ReadMap(input)
    let [values, input] = vimpire#edn#ReadList(a:input)

    if len(values) % 2 == 1
        throw "EDN: unbalanced key/value pairs in map literal"
    endif

    let alist  = []
    let keys   = []
    while len(values) > 0
        let [key, value; values] = values

        for knownKey in keys
            if type(knownKey) == type(key) && knownKey == key
                throw "EDN: duplicate key in map literal"
            endif
        endfor
        call add(keys, key)

        call add(alist, [key, value])
    endwhile

    return [vimpire#edn#Map(alist), input]
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

let s:ReverseCharacterCodes = {
            \ "\n": "newline",
            \ "\r": "return",
            \ " ":  "space",
            \ "\t": "tab"
            \ }

" FIXME: \uxxxx style unicode chars are missing.
function! vimpire#edn#ReadCharacter(input)
    let result = matchstr(a:input, '^\\\(newline\|return\|space\|tab\|\S\)')
    let input  = strpart(a:input, strlen(result))

    let result = strpart(result, 1)
    if has_key(s:CharacterCodes, result)
        let result = s:CharacterCodes[result]
    endif

    return [{"edn/char": result}, input]
endfunction

function! vimpire#edn#ReadNamespacedMap(input)
    let [tag, input] = vimpire#edn#ReadSymbol(a:input)
    if !vimpire#edn#IsMagical(tag, "edn/symbol")
                \ || has_key(tag, "edn/namespace")
        throw "Vimpire: tag for namespaced map must be a unqualified symbol"
    endif

    let input = vimpire#edn#EatWhitespace(input)

    let [m, input] = vimpire#edn#ReadMap(input)
    if !vimpire#edn#IsMagical(m, "edn/map")
        return [m, input]
    endif

    let nm = []
    for pair in m["edn/map"]
        let [k, v] = pair

        if !vimpire#edn#IsMagical(k, "edn/symbol")
                    \ && !vimpire#edn#IsMagical(k, "edn/keyword")
            call add(nm, pair)
            continue
        endif

        if !has_key(k, "edn/namespace")
            if vimpire#edn#IsMagical(k, "edn/keyword")
                let k = vimpire#edn#Keyword(
                            \ tag["edn/symbol"],
                            \ k["edn/keyword"])
                call add(nm, [k, v])
            else
                let k = vimpire#edn#Symbol(
                            \ tag["edn/symbol"],
                            \ k["edn/symbol"])
                call add(nm, [k, v])
            endif
            continue
        endif

        if k["edn/namespace"] == "_"
            if vimpire#edn#IsMagical(k, "edn/keyword")
                let k = vimpire#edn#Keyword(k["edn/keyword"])
                call add(nm, [k, v])
            else
                let k = vimpire#edn#Symbol(k["edn/symbol"])
                call add(nm, [k, v])
            endif
            continue
        endif

        call add(nm, pair)
    endfor

    " We know that we cannot turn into a normal vim map.
    " It would have been one in the first place. So we
    " can save the try.
    return [{"edn/map": nm}, input]
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
    elseif a:input[0] == ":"
        return vimpire#edn#ReadNamespacedMap(strpart(a:input, 1))
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
            return [vimpire#edn#List(value), input]
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

function! vimpire#edn#WriteList(thing, delim, printers)
    " Special case: Empty list. Otherwise the first fails.
    if len(a:thing) == 0
        return a:delim . s:Pair[a:delim]
    endif

    let [ first; rest ] = a:thing
    let s = a:delim . vimpire#edn#Write(first, a:printers)
    for x in rest
        let s .= " " . vimpire#edn#Write(x, a:printers)
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

" FIXME: \uxxxx character codes.
function! vimpire#edn#WriteChar(char)
    return '\' . get(s:ReverseCharacterCodes,
                \ a:char["edn/char"], a:char["edn/char"])
endfunction

function! vimpire#edn#WriteDict(thing, printers)
    let thing = a:thing

    " Special case: Empty dict. Otherwise the first fails.
    if len(thing) == 0
        return "{}"
    endif

    " Special case: tagged literal
    if vimpire#edn#IsTaggedLiteral(thing)
        let t = vimpire#edn#Write(thing["edn/tag"])
        if has_key(a:printers, t)
            return a:printers[t](thing["edn/value"], a:printers)
        else
            return "#" . t . " "
                        \ . vimpire#edn#Write(thing["edn/value"], a:printers)
        endif
    endif

    " Special case: a list, not a vector
    if vimpire#edn#IsMagical(thing, "edn/list")
        return vimpire#edn#WriteList(thing["edn/list"], "(", a:printers)
    endif

    " Special case: a set, not a vector
    if vimpire#edn#IsMagical(thing, "edn/set")
        return "#" . vimpire#edn#WriteList(thing["edn/set"], "{", a:printers)
    endif

    " Special case: a keyword, not a string
    if vimpire#edn#IsMagical(thing, "edn/keyword")
        return vimpire#edn#WriteKeyword(thing)
    endif

    " Special case: a symbol, not a string
    if vimpire#edn#IsMagical(thing, "edn/symbol")
        return vimpire#edn#WriteSymbol(thing)
    endif

    " Special case: a character, not a string
    if vimpire#edn#IsMagical(thing, "edn/char")
        return vimpire#edn#WriteChar(thing)
    endif

    " Special case: a map, not a vector
    if vimpire#edn#IsMagical(thing, "edn/map")
        let thing = thing["edn/map"]
    else
        let thing = items(thing)
    endif

    let [ firstPair; rest ] = thing
    let s = "{" . vimpire#edn#Write(firstPair[0], a:printers)
                \ . " " . vimpire#edn#Write(firstPair[1], a:printers)
    for [ key, value ] in rest
        let s .= " " . vimpire#edn#Write(key, a:printers)
                    \ . " " . vimpire#edn#Write(value, a:printers)
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

function! vimpire#edn#Write(thing, ...)
    let printers = (a:0 > 0 ? a:1 : {})

    let t = type(a:thing)

    if a:thing is v:null
        return vimpire#edn#WriteNil()
    elseif t == v:t_bool
        return vimpire#edn#WriteBool(a:thing)
    elseif t == v:t_number || t == v:t_float
        return vimpire#edn#WriteNumber(a:thing)
    elseif t == v:t_list
        return vimpire#edn#WriteList(a:thing, "[", printers)
    elseif t == v:t_dict
        return vimpire#edn#WriteDict(a:thing, printers)
    elseif t == v:t_string
        return vimpire#edn#WriteString(a:thing)
    elseif t == v:t_func
        return vimpire#edn#WriteFunc(a:thing)
    endif

    throw "EDN: Don't know how to write value: " . string(a:thing)
endfunction

function! vimpire#edn#DoSimplifyLeaf(form)
    " Special case: Elisions are left alone.
    if vimpire#edn#IsTaggedLiteral(a:form,
                \ vimpire#edn#Symbol("unrepl", "..."))
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
                \ vimpire#edn#Symbol("unrepl", "ns"))
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
    " Special case: Characters are translated to strings.
    elseif vimpire#edn#IsMagical(a:form, "edn/char")
        return a:form["edn/char"]
    " Other non-compound values, we can leave alone.
    else
        return a:form
    endif
endfunction

function! vimpire#edn#DoSimplifyCompound(form)
    " Special case: Lists are translated to vectors.
    if vimpire#edn#IsMagical(a:form, "edn/list")
        return vimpire#edn#Simplify(a:form["edn/list"])
    " Special case: Sets are translated to vectors.
    elseif vimpire#edn#IsMagical(a:form, "edn/set")
        return vimpire#edn#Simplify(a:form["edn/set"])
    else
        return a:form
    endif
endfunction

function! vimpire#edn#Simplify(form)
    return vimpire#edn#Traverse(a:form,
                \ function("vimpire#edn#DoSimplifyLeaf"),
                \ function("vimpire#edn#DoSimplifyCompound"))
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

function! vimpire#edn#Items(form)
    if type(a:form) == v:t_list
        return a:form
    elseif vimpire#edn#IsMagical(a:form, "edn/list")
        return a:form["edn/list"]
    elseif vimpire#edn#IsMagical(a:form, "edn/set")
        return a:form["edn/set"]
    elseif vimpire#edn#IsMagical(a:form, "edn/map")
        return a:form["edn/map"]
    else
        return items(a:form)
    endif
endfunction

function! vimpire#edn#SameAs(elems, form)
    if type(a:form) == v:t_list
        return a:elems
    elseif vimpire#edn#IsMagical(a:form, "edn/list")
        return vimpire#edn#List(a:elems)
    elseif vimpire#edn#IsMagical(a:form, "edn/set")
        return vimpire#edn#Set(a:elems)
    else
        return vimpire#edn#Map(a:elems)
    endif
endfunction

function! vimpire#edn#Traverse(form, f, ...)
    let Compoundf = { val -> val }
    if a:0 > 0
        let Compoundf = a:1
    endif

    if vimpire#edn#IsMagical(a:form, "edn/list")
        return Compoundf(vimpire#edn#List(
                    \ map(copy(a:form["edn/list"]),
                    \   { k_, val ->
                    \     vimpire#edn#Traverse(val, a:f, Compoundf)
                    \ })))
    elseif vimpire#edn#IsMagical(a:form, "edn/set")
        return Compoundf(vimpire#edn#Set(
                    \ map(copy(a:form["edn/set"]),
                    \   { k_, val ->
                    \     vimpire#edn#Traverse(val, a:f, Compoundf)
                    \ })))
    elseif vimpire#edn#IsMagical(a:form, "edn/map")
                \ || (type(a:form) == v:t_dict
                \     && !vimpire#edn#IsMagical(a:form))
        if vimpire#edn#IsMagical(a:form, "edn/map")
            let items = a:form["edn/map"]
        else
            let items = items(a:form)
        endif

        let alist = []
        for [k, v] in items
            let k = vimpire#edn#Traverse(k, a:f, Compoundf)
            let v = vimpire#edn#Traverse(v, a:f, Compoundf)
            call add(alist, [k, v])
        endfor
        return Compoundf(vimpire#edn#Map(alist))
    elseif type(a:form) == v:t_list
        return Compoundf(map(copy(a:form),
                    \   { k_, val ->
                    \     vimpire#edn#Traverse(val, a:f, Compoundf)
                    \ }))
    else
        return a:f(a:form)
    endif
endfunction
