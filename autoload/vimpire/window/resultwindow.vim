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

function! vimpire#window#resultwindow#New(bufCtor)
    if exists("t:vimpire_result_window")
        " Otherwise the result window was closed.
        if vimpire#window#FindThis(t:vimpire_result_window) != -1
            call vimpire#window#GoHere(t:vimpire_result_window)

            let t:vimpire_result_window.buffer = call(a:bufCtor, [])
            return t:vimpire_result_window
        else
            unlet t:vimpire_result_window
        endif
    endif

    let this = vimpire#window#New(a:bufCtor)

    let b:vimpire_result_buffer = 1
    let t:vimpire_result_window = this

    augroup VimpireResultWindow
        autocmd!
        autocmd BufDelete <buffer> call vimpire#window#resultwindow#Demote(
                    \ getbufvar(eval(expand("<abuf>")), "vimpire_buffer"))
    augroup END

    return this
endfunction

" Remove the buffer object from the window. The buffer is removed
" automatically by Vim, when it is removed from the window.
function! vimpire#window#resultwindow#Demote(buffer)
    if exists("t:vimpire_result_window")
        if t:vimpire_result_window.buffer is a:buffer
            let t:vimpire_result_window.buffer = v:none
        endif
    endif
endfunction

function! vimpire#window#resultwindow#CloseWindow()
    if exists("t:vimpire_result_window")
        call vimpire#window#Close(t:vimpire_result_window)
        unlet t:vimpire_result_window
    endif
endfunction

" Epilog
let &cpo = s:save_cpo
