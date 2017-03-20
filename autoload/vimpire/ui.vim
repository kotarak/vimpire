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

let s:save_cpo = &cpo
set cpo&vim

if !exists("g:vimpire#ui#UseErrorBuffer")
    let vimpire#ui#UseErrorBuffer = 1
endif

function! vimpire#ui#ReportError(msg)
    if g:vimpire#ui#UseErrorBuffer
        let buf = vimpire#window#resultwindow#New("vimpire#buffer#NewResultBuffer")
        call vimpire#window#ShowText(buf, a:msg)
        wincmd p
    else
        throw "Vimpire: A crisis has arisen! " . substitute(a:msg, '\n\(\t\?\)', ' ', 'g')
    endif
endfunction

function! vimpire#ui#ShowResult(result)
    let buf = vimpire#window#resultwindow#New("vimpire#buffer#NewResultBuffer")
    call vimpire#window#ShowOutput(buf, a:result)
    wincmd p
endfunction

function! vimpire#ui#ShowClojureResult(result, nspace)
    let buf = vimpire#window#resultwindow#New("vimpire#buffer#NewClojureResultBuffer")
    let b:vimpire_namespace = a:nspace
    call vimpire#window#ShowOutput(buf, a:result)
    wincmd p
endfunction

" Key mappings and Plugs
function! vimpire#ui#MakeProtectedPlug(mode, plug, f, args)
    execute a:mode . "noremap <Plug>Vimpire" . a:plug . "."
                \ . " :<C-U>call vimpire#ui#ProtectedPlug("
                \ . "\"" . a:f . "\", " . a:args . ")<CR>"
endfunction

function! vimpire#ui#MakeCommandPlug(mode, plug, f, args)
    execute a:mode . "noremap <Plug>Vimpire" . a:plug . "."
                \ . " :<C-U>call vimpire#ui#ProtectedPlug("
                \ . " \"vimpire#ui#CommandPlug\", "
                \ . " \"" . a:f . "\", " . a:args . ")<CR>"
endfunction

function! vimpire#ui#CommandPlug(f, ...)
    if exists("b:vimpire_namespace")
        call call(a:f, a:000)
    else
        let msg = "Vimpire could not initialise the server connection.\n"
                    \ . "That means you will not be able to use the interactive features.\n"
                    \ . "Reasons might be that the server is not running.\n\n"
                    \ . "Vimpire will *not* start the server for you or handle the classpath.\n"
                    \ . "There is a plethora of tools like ivy, maven, gradle and leiningen,\n"
                    \ . "which do this better than Vimpire could ever do it."
        throw msg
    endif
endfunction

function! vimpire#ui#ProtectedPlug(f, ...)
    try
        return call(a:f, a:000)
    catch /.*/
        call vimpire#ui#ReportError(v:exception)
    endtry
endfunction

" Epilog
let &cpo = s:save_cpo
