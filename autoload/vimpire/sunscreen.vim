"-
" Copyright 2009-2017 © Meikel Brandmeyer.
" All rights reserved.
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
" THE SOFTWARE.

" Prolog
let s:save_cpo = &cpo
set cpo&vim

function! vimpire#sunscreen#GetResources(root)
    let files = glob(a:root . "**/*.clj", v:false, v:true)

    let contents = {}

    for f in files
        let resource = substitute(strpart(f, strlen(a:root)), '\\', '/', 'g')
        let contents[resource] = join(readfile(f), "\n")
    endfor

    return contents
endfunction

function! vimpire#sunscreen#StringToBytes(input)
    let bytes = []

    for i in range(strlen(a:input))
        call add(bytes, char2nr(a:input[i]))
    endfor

    return bytes
endfunction

" Taken from clojure.data.codec.base64
function! vimpire#sunscreen#Base64(input, ...)
    let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    if a:0 > 0
        let table = a:1
    endif

    let output = ""

    let tailLen = len(a:input) % 3
    let loopLim = len(a:input) - tailLen

    let i = 0
    while i < loopLim
        let x  = a:input[i]
        let y  = a:input[i + 1]
        let z  = a:input[i + 2]
        let a  = and(0x3f, x / 4)
        let b1 = and(0x03, x) * 16
        let b2 = and(0x0f, y / 16)
        let b  = or(b1, b2)
        let c1 = and(0x0f, y) * 4
        let c2 = and(0x03, z / 64)
        let c  = or(c1, c2)
        let d  = and(0x3f, z)

        let output .= table[a] . table[b] . table[c] . table[d]
        let i += 3
    endwhile

    if tailLen == 1
        let x  = a:input[i]
        let a  = and(0x3f, x / 4)
        let b1 = and(0x03, x) * 16
        let output .= table[a] . table[b1] . nr2char(61) . nr2char(61)
    elseif tailLen == 2
        let x  = a:input[i]
        let y  = a:input[i + 1]
        let a  = and(0x3f, x / 4)
        let b1 = and(0x03, x) * 16
        let b2 = and(0x0f, y / 16)
        let b  = or(b1, b2)
        let c1 = and(0x0f, y) * 4
        let output .= table[a] . table[b] . table[c1] . nr2char(61)
    endif

    return output
endfunction

" Idea taken from Christophe Grand's unrepl
function! vimpire#sunscreen#Marker(input)
    " Note: This is a one way street.
    let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789AB"

    " Note: We cut off two bytes to avoid padding.
    let sha = sha256(a:input)[4:64]
    let bytes = []

    for i in range(strlen(sha) / 2)
        call add(bytes, str2nr(sha[i:i+1], 16))
    endfor

    return vimpire#sunscreen#Base64(bytes, table)
endfunction

function! vimpire#sunscreen#GenerateMarker(contents)
    let allContent = []
    for f in sort(keys(a:contents))
        call add(allContent, a:contents[f])
    endfor

    let marker = "vv-" . vimpire#sunscreen#Marker(join(allContent, "\n"))

    return marker
endfunction

function! vimpire#sunscreen#Shade(contents, rootNamespaces, marker)
    let markerDir = substitute(a:marker, '-', '_', 'g')

    let shadedContents = {}
    for [ resource, content ] in items(a:contents)
        let shadedContents[markerDir . "/" . resource] =
                    \ vimpire#sunscreen#Base64(
                    \ vimpire#sunscreen#StringToBytes(
                    \ substitute(content, ':\@<!' . a:rootNamespaces,
                    \   a:marker . '.\1', "g")))
    endfor

    return shadedContents
endfunction

function! vimpire#sunscreen#ShadeActions(form, marker, rootNamespaces)
    if vimpire#edn#IsMagical(a:form, "edn/list")
        return vimpire#edn#List(
                    \ map(copy(a:form["edn/list"]),
                    \ "vimpire#sunscreen#ShadeActions(v:val, a:marker, a:rootNamespaces)"))
    elseif vimpire#edn#IsMagical(a:form, "edn/map")
        let alist = []
        for [k, v] in a:form["edn/map"]
            let k = vimpire#sunscreen#ShadeActions(k, a:marker, a:rootNamespaces)
            let v = vimpire#sunscreen#ShadeActions(v, a:marker, a:rootNamespaces)
            call add(alist, [k, v])
        endfor
        return vimpire#edn#Map(alist)
    elseif vimpire#edn#IsMagical(a:form, "edn/set")
        return vimpire#edn#Set(
                    \ map(copy(a:form["edn/set"]),
                    \ "vimpire#sunscreen#ShadeActions(v:val, a:marker, a:rootNamespaces)"))
    elseif vimpire#edn#IsTaggedLiteral(a:form)
        let t = vimpire#sunscreen#ShadeActions(a:form["edn/tag"],
                    \ a:marker, a:rootNamespaces)
        let v = vimpire#sunscreen#ShadeActions(a:form["edn/value"],
                    \ a:marker, a:rootNamespaces)
        return {"edn/tag": t, "edn/value": v}
    elseif vimpire#edn#IsMagical(a:form, "edn/symbol")
        if !has_key(a:form, "edn/namespace")
                    \ || a:form["edn/namespace"] !~ '^' . a:rootNamespaces
            return a:form
        endif
        return vimpire#edn#Symbol(a:form["edn/symbol"],
                    \ a:marker . "." . a:form["edn/namespace"])
    elseif vimpire#edn#IsMagical(a:form, "edn/keyword")
        if !has_key(a:form, "edn/namespace")
                    \ || a:form["edn/namespace"] !~ '^' . a:rootNamespaces
            return a:form
        endif
        return vimpire#edn#Keyword(a:form["edn/keyword"],
                    \ a:marker . "." . a:form["edn/namespace"])
    elseif type(a:form) == v:t_list || type(a:form) == v:t_dict
        return map(copy(a:form),
                    \ "vimpire#sunscreen#ShadeActions(v:val, a:marker, a:rootNamespaces)")
    else
        return a:form
    endif
endfunction

function! vimpire#sunscreen#DoApply(rootNamespaces, resourcesRoot, actionsFile)
    let resources = vimpire#sunscreen#GetResources(a:resourcesRoot)
    let marker    = vimpire#sunscreen#GenerateMarker(resources)
    let rootNspaces = '\(' . escape(join(a:rootNamespaces, '\|'), '.') . '\)'

    let shadedResources = vimpire#sunscreen#Shade(resources,
                \ rootNspaces, marker)

    let [actions, trailingGarbageIgnored_] =
                \ vimpire#edn#Read(join(readfile(a:actionsFile), "\n"))

    if vimpire#edn#IsMagical(actions, "edn/map")
        let alist = []
        for [k, v] in actions["edn/map"]
            let v = vimpire#sunscreen#ShadeActions(v,
                        \ marker, rootNspaces)
            call add(alist, [k, v])
        endfor
        let actions = vimpire#edn#Map(alist)
    else
        let actions = map(copy(actions),
                    \ "vimpire#sunscreen#ShadeActions(v:val, a:marker, rootNspaces)")
    endif

    return {"resources": shadedResources, "actions": actions}
endfunction

function! vimpire#sunscreen#Apply(rootNamespaces, resourcesRoot, actionsFile)
    return function("vimpire#sunscreen#DoApply",
                \ [a:rootNamespaces, a:resourcesRoot, a:actionsFile])
endfunction

" Epilog
let &cpo = s:save_cpo
