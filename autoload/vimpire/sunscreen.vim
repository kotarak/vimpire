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

function! vimpire#sunscreen#GetResources(roots)
    let resources = {}
    for root in a:roots
        let files = glob(root . "**/*", v:false, v:true)
        call filter(files, 'getftype(v:val) == "file"')

        for f in files
            let resource = substitute(strpart(f, strlen(root)), '\\', '/', 'g')
            let resources[resource] = join(readfile(f), "\n")
        endfor
    endfor

    return resources
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

function! vimpire#sunscreen#GenerateMarker(resources)
    let content = []
    for f in sort(keys(a:resources))
        call add(content, a:resources[f])
    endfor

    let marker = "vv-" . vimpire#sunscreen#Marker(join(content, "\n"))

    return marker
endfunction

function! vimpire#sunscreen#Base64EncodeResources(resources)
    return map(copy(a:resources), { k_, val ->
                \ vimpire#sunscreen#Base64(
                \ vimpire#sunscreen#StringToBytes(val))
                \ })
endfunction

function! vimpire#sunscreen#ShadeResourceNames(marker, resources)
    let markerDir = substitute(a:marker, '-', '_', 'g')

    let shadedResources = {}
    for resource in keys(a:resources)
        let nresource = markerDir . '/' . resource
        let shadedResources[nresource] = a:resources[resource]
    endfor

    return shadedResources
endfunction

function! vimpire#sunscreen#ShadeResources(namespaceShades, resources)
    let shadedResources = copy(a:resources)

    for [ marker, shadedNamespaceRoots ] in items(a:namespaceShades)
        let markerDir = substitute(marker, '-', '_', 'g')

        let strsToShade = '"' . substitute(shadedNamespaceRoots,
                    \ '\.', '/', 'g')

        call map(shadedResources, { resource_, content ->
                    \   substitute(
                    \     substitute(
                    \       content,
                    \       shadedNamespaceRoots,
                    \       marker . '.\1', 'g'),
                    \   strsToShade, '"' . markerDir . '/\1', 'g')
                    \ })
    endfor

    return shadedResources
endfunction

function! vimpire#sunscreen#ShadeActionsLeafs(namespaceShades,
            \ initNamespaces, form)
    if vimpire#edn#IsTaggedLiteral(a:form)
        " Note: We do not propagate namespace requires into
        " tags, since they are not necessarily existing in general.
        " We only care for the symbols on the executable level.
        let t = vimpire#sunscreen#ShadeActionsLeafs(
                    \ a:namespaceShades, [], a:form["edn/tag"])
        let v = vimpire#sunscreen#ShadeActionsTree(
                    \ a:namespaceShades, [], a:form["edn/value"])
        return {"edn/tag": t, "edn/value": v}
    elseif vimpire#edn#IsMagical(a:form, "edn/symbol")
        if !has_key(a:form, "edn/namespace")
            return a:form
        endif

        for [marker, namespaces] in items(a:namespaceShades)
            if a:form["edn/namespace"] =~ '^' . namespaces
                let shadedNamespace = marker . "." . a:form["edn/namespace"]
                call add(a:initNamespaces, shadedNamespace)
                return vimpire#edn#Symbol(a:form["edn/symbol"],
                            \ shadedNamespace)
            endif
        endfor

        return a:form
    elseif vimpire#edn#IsMagical(a:form, "edn/keyword")
        if !has_key(a:form, "edn/namespace")
            return a:form
        endif

        for [marker, namespaces] in items(a:namespaceShades)
            if a:form["edn/namespace"] =~ '^' . namespaces
                return vimpire#edn#Keyword(a:form["edn/keyword"],
                            \ marker . "." . a:form["edn/namespace"])
            endif
        endfor

        return a:form
    else
        return a:form
    endif
endfunction

function! vimpire#sunscreen#ShadeActionsTree(namespaceShades,
            \ initNamespaces, form)
    return vimpire#edn#Traverse(a:form,
                \ function("vimpire#sunscreen#ShadeActionsLeafs",
                \   [a:namespaceShades, a:initNamespaces]))
endfunction

function! vimpire#sunscreen#ShadeActions(namespaceShades,
            \ initNamespaces, form)
    let actions = []
    for [k, v] in vimpire#edn#Items(a:form)
        call add(actions, [k, vimpire#sunscreen#ShadeActionsTree(
                \ a:namespaceShades, a:initNamespaces, v)])
    endfor

    return vimpire#edn#Map(actions)
endfunction

function! vimpire#sunscreen#Apply(
            \ name,
            \ roots,
            \ exposedNamespaceRoots,
            \ hiddenNamespaceRoots,
            \ actionsFile)
    return {
                \ "name":    a:name,
                \ "roots":   a:roots,
                \ "exposed": a:exposedNamespaceRoots,
                \ "hidden":  a:hiddenNamespaceRoots,
                \ "actions": a:actionsFile
                \ }
endfunction

" Epilog
let &cpo = s:save_cpo
