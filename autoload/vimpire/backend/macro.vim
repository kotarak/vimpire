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

function! s:MacroExpandWorker(type, firstOnly)
    let server = vimpire#connection#ForBuffer()
    let nspace = b:vimpire_namespace

    let [ line, col, exp ] = vimpire#util#WithSavedPosition(
                \ function("vimpire#util#OpTextExtractor", [a:type]))

    call vimpire#connection#Action(
                \ server,
                \ ":vimpire/macro-expand",
                \ {":nspace": nspace,
                \  ":one?":   (a:firstOnly ? v:true : v:false),
                \  ":form":   exp},
                \ {"eval":    { val ->
                \    vimpire#ui#ShowClojureResult(val, nspace)
                \ }})
endfunction

function! vimpire#backend#macro#MacroExpand(type)
    call vimpire#ui#ProtectedPlug(
                \ function("vimpire#ui#CommandPlug"),
                \ function("s:MacroExpandWorker"),
                \ a:type, v:false)
endfunction

function! vimpire#backend#macro#MacroExpand1(type)
    call vimpire#ui#ProtectedPlug(
                \ function("vimpire#ui#CommandPlug"),
                \ function("s:MacroExpandWorker"),
                \ a:type, v:true)
endfunction

" Epilog
let &cpo = s:save_cpo
