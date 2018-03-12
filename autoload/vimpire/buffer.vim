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

" A Buffer...
let s:BufferNr = 0

function! vimpire#buffer#New()
    let this = {}

    let nr = s:BufferNr
    let bufname = printf("vimpire_buffer_%06d", s:BufferNr)
    let s:BufferNr += 1

    execute "badd" bufname
    execute "buffer!" bufname

    let this.bufnr = bufnr("%")
    let b:vimpire_buffer = this

    return this
endfunction

function! vimpire#buffer#ShowText(this, text)
    call vimpire#buffer#GoHere(a:this)

    if type(a:text) == type("")
        " XXX: Opening the box of the pandora.
        " 2012-01-09: Adding Carriage Returns here.
        let text = split(a:text, '\r\?\n')
    else
        let text = a:text
    endif
    call append(line("$"), text)
endfunction

function! vimpire#buffer#Clear(this)
    call vimpire#buffer#GoHere(a:this)

    1
    normal! "_dG
endfunction

function! vimpire#buffer#GoHere(this)
    if bufnr("%") != a:this.bufnr
        execute "buffer!" a:this.bufnr
    endif
endfunction

function! vimpire#buffer#Close(this)
    execute "bdelete!" a:this.bufnr
endfunction

function! vimpire#buffer#NewResultBuffer()
    let this = vimpire#buffer#New()

    setlocal noswapfile
    setlocal buftype=nofile
    setlocal bufhidden=wipe

    if !hasmapto("<Plug>(vimpire_close_result_buffer)", "n")
        nmap <buffer> <silent> <LocalLeader>q <Plug>(vimpire_close_result_buffer)
    endif

    call vimpire#buffer#Clear(this)

    return this
endfunction

function! vimpire#buffer#NewClojureResultBuffer()
    let this = vimpire#buffer#NewResultBuffer()

    if a:0 == 1
        let b:vimpire_namespace = a:1
    else
        let b:vimpire_namespace = "user"
    endif
    set filetype=vimpire.clojure

    return this
endfunction

" Epilog
let &cpo = s:save_cpo
