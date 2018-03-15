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

if !exists("g:vimpire_window_split_pos")
    let g:vimpire_window_split_pos = "top"
endif

if !exists("g:vimpire_window_split_size")
    let g:vimpire_window_split_size = ""
endif

function! vimpire#window#New(bufCtor)
    let this = {}

    if g:vimpire_window_split_pos == "left" || g:vimpire_window_split_pos == "right"
        let o_sr = &splitright
        if g:vimpire_window_split_pos == "left"
            set nosplitright
        else
            set splitright
        end
        execute printf("%svsplit", g:vimpire_window_split_size)
        let &splitright = o_sr
    else
        let o_sb = &splitbelow
        if g:vimpire_window_split_pos == "bottom"
            set splitbelow
        else
            set nosplitbelow
        end
        execute printf("%ssplit", g:vimpire_window_split_size)
        let &splitbelow = o_sb
    endif

    let this.buffer = call(a:bufCtor, [])
    let w:vimpire_window = this

    return this
endfunction

function! vimpire#window#GoHere(this)
    let wn = vimpire#window#FindThis(a:this)
    if wn == -1
        throw 'Vimpire: A crisis has arisen! Cannot find my window.'
    endif
    execute wn . "wincmd w"
    call vimpire#buffer#GoHere(a:this.buffer)
endfunction

function! vimpire#window#Resize(this)
    call vimpire#window#GoHere(a:this)
    let size = line("$")
    if size < 3
        let size = 3
    endif
    execute "resize " . size
endfunction

function! vimpire#window#ShowText(this, text)
    call vimpire#window#GoHere(a:this)
    call vimpire#buffer#ShowText(a:this.buffer, a:text)
endfunction

function! vimpire#window#Clear(this)
    call vimpire#window#GoHere(a:this)
    call vimpire#buffer#Clear(a:this.buffer)
endfunction

function! vimpire#window#Close(this)
    call vimpire#buffer#Close(a:this.buffer)
endfunction

function! vimpire#window#FindThis(this)
    for w in range(1, winnr("$"))
        if type(getwinvar(w, "vimpire_window")) == type({})
            if getwinvar(w, "vimpire_window") == a:this
                return w
            endif
        endif
    endfor

    return -1
endfunction

" Epilog
let &cpo = s:save_cpo
