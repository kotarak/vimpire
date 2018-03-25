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

let vimpire#venom#PoisonCabinet = []
let vimpire#venom#Venom = g:vimpire#Nil

function! vimpire#venom#Register(venom)
    call add(g:vimpire#venom#PoisonCabinet, a:venom)
endfunction

function! vimpire#venom#NamespacesToRegex(namespaces)
    return '\(' . escape(join(a:namespaces, '\|'), '.') . '\)'
endfunction

function! vimpire#venom#Inject()
    if g:vimpire#venom#Venom isnot g:vimpire#Nil
        return g:vimpire#venom#Venom
    endif

    " Step 1+2: Read resources & actions and generate markers.
    let markers = {}
    for vial in g:vimpire#venom#PoisonCabinet
        let vial.resources =
                    \ vimpire#sunscreen#GetResources(vial.roots)
        let vial.actions =
                    \ vimpire#edn#Read(join(readfile(vial.actions), "\n"))[0]
        let vial.marker =
                    \ vimpire#sunscreen#GenerateMarker(vial.resources)
        if len(vial.exposed) > 0
            let markers[vial.marker] =
                        \ vimpire#venom#NamespacesToRegex(vial.exposed)
        endif
    endfor

    " Step 3: Shade resources and actions.
    let initNamespaces = []
    for vial in g:vimpire#venom#PoisonCabinet
        let localMarkers = copy(markers)
        if len(vial.exposed) > 0 || len(vial.hidden) > 0
            let localMarkers[vial.marker] = vimpire#venom#NamespacesToRegex(
                        \ vial.exposed + vial.hidden)
        endif

        let vial.resources = vimpire#sunscreen#ShadeResourceNames(
                    \ vial.marker, vial.resources)
        let vial.resources = vimpire#sunscreen#ShadeResources(
                    \ localMarkers, vial.resources)
        let vial.resources = vimpire#sunscreen#Base64EncodeResources(
                    \ vial.resources)
        let vial.actions = vimpire#sunscreen#ShadeActions(
                    \ localMarkers, initNamespaces, vial.actions)
    endfor

    " Step 4: Distill the venom!
    let resources = {}
    let actions   = []
    let keys      = []
    for vial in g:vimpire#venom#PoisonCabinet
        try
            " It is an error for peers to overwrite each others resources.
            " In fact this should never happen. But hey, you never know
            " what people come up with.
            call extend(resources, vial.resources, "error")
        catch
            throw "Vimpire: " . vial.name . " is trying to overwrite existing resources"
        endtry

        for [k, v] in vimpire#edn#Items(vial.actions)
            if index(keys, k) > -1
                throw "Vimpire: "
                            \ . vial.name
                            \ . " is trying to overwrite existing action "
                            \ . vimpire#edn#Write(k)
            endif

            call add(keys, k)
            call add(actions, [k, v])
        endfor
    endfor

    let actions = vimpire#edn#Write(vimpire#edn#Map(actions))
    call map(uniq(sort(initNamespaces)), { idx_, nspace ->
                \   vimpire#edn#List([
                \     vimpire#edn#Symbol("clojure.core", "symbol"),
                \     nspace
                \   ])
                \ })

    let g:vimpire#venom#Venom = {
                \ "actions":   actions,
                \ "resources": resources,
                \ "init":      vimpire#edn#Write(vimpire#edn#List([
                \   vimpire#edn#Symbol("clojure.core", "require")
                \ ] + initNamespaces))}

    return g:vimpire#venom#Venom
endfunction

" Epilog
let &cpo = s:save_cpo
