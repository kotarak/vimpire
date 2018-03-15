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

let s:Registry = {}
let s:Venom = g:vimpire#Nil

function! vimpire#venom#Register(name, venom)
    let s:Registry[a:name] = a:venom
endfunction

function! s:Force(val)
    if type(a:val) == v:t_func
        return a:val()
    else
        return a:val
    endif
endfunction

function! vimpire#venom#DeMap(map)
    return substitute(
                \ substitute(a:map, '^\(;.*\n\)*{', '', ''),
                \ '}\(\s\|\n\)*$', '', '')
endfunction

function! vimpire#venom#Inject()
    if s:Venom isnot g:vimpire#Nil
        return s:Venom
    endif

    call map(s:Registry, { k_, v -> s:Force(v) })

    let s:Venom = {"actions": [], "resources": {}}
    for [peer, val] in items(s:Registry)
        call add(s:Venom.actions, val.actions)
        try
            " It is an error for peers to overwrite each others resources.
            call extend(s:Venom.resources, val.resources, "error")
        catch
            throw "Vimpire: " . peer . " is trying to overwrite existing resources"
        endtry
    endfor

    call map(s:Venom.actions, 'vimpire#venom#DeMap(v:val)')
    let s:Venom.actions = "{" . join(s:Venom.actions, "\n") . "}"

    return s:Venom
endfunction

" Epilog
let &cpo = s:save_cpo
