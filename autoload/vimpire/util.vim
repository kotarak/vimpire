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

function! vimpire#util#SynIdName()
    return synIDattr(synID(line("."), col("."), 0), "name")
endfunction

function! vimpire#util#WithSaved(f, save, restore)
    let v = a:save()
    try
        let r = a:f()
    finally
        call a:restore(v)
    endtry
    return r
endfunction

function! s:SavePosition()
    let [ _b, l, c, _o ] = getpos(".")
    let b = bufnr("%")
    return [b, l, c]
endfunction

function! s:RestorePosition(value)
    let [b, l, c] = a:value

    if bufnr("%") != b
        execute b "buffer!"
    endif
    call setpos(".", [0, l, c, 0])
endfunction

function! vimpire#util#WithSavedPosition(f)
    return vimpire#util#WithSaved(a:f,
                \ function("s:SavePosition"),
                \ function("s:RestorePosition"))
endfunction

function! s:SaveRegister(reg)
    return [a:reg, getreg(a:reg, 1), getregtype(a:reg)]
endfunction

function! s:SaveRegisters(reg)
    return map([a:reg, "", "/", "-",
                \ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"],
                \ "s:SaveRegister(v:val)")
endfunction

function! s:RestoreRegisters(registers)
    for register in a:registers
        call call(function("setreg"), register)
    endfor
endfunction

function! vimpire#util#WithSavedRegister(reg, f)
    return vimpire#util#WithSaved(a:f,
                \ function("s:SaveRegisters", [a:reg]),
                \ function("s:RestoreRegisters"))
endfunction

function! s:SaveOption(option)
    return eval("&" . a:option)
endfunction

function! s:RestoreOption(option, value)
    execute "let &" . a:option . " = a:value"
endfunction

function! vimpire#util#WithSavedOption(option, closure)
    return vimpire#util#WithSaved(a:closure
                \ function("s:SaveOption", [a:option]),
                \ function("s:RestoreOption, [a:option]))
endfunction

function! s:DoYank(reg, yank)
    silent execute a:yank
    return getreg(a:reg)
endfunction

function! vimpire#util#Yank(r, how)
    return vimpire#util#WithSavedRegister(a:r,
                \ function("s:DoYank", [a:r, a:how]))
endfunction

function! vimpire#util#MoveBackward()
    call search('\S', 'Wb')
endfunction

function! vimpire#util#MoveForward()
    call search('\S', 'W')
endfunction

function! vimpire#util#BufferName()
    let file = expand("%")
    if file == ""
        let file = "UNNAMED"
    endif
    return file
endfunction

function! s:ClojureExtractSexprWorker(flag)
    let pos = [0, 0]
    let start = getpos(".")

    if getline(start[1])[start[2] - 1] == "("
                \ && vimpire#util#SynIdName() =~ 'clojureParen\|level\d\+c'
        let pos = [start[1], start[2]]
    endif

    if pos == [0, 0]
        let pos = searchpairpos('(', '', ')', 'bW' . a:flag,
                    \ "vimpire#util#SynIdName() !~ 'clojureParen\\|level\\d\\+c'")
    endif

    if pos == [0, 0]
        throw "Error: Not in a s-expression!"
    endif

    return [pos, vimpire#util#Yank('l', 'normal! "ly%')]
endfunction

function! vimpire#util#ExtractSexpr(toplevel)
    let flag = a:toplevel ? "r" : ""
    return vimpire#util#WithSavedPosition(
                \ function("s:ClojureExtractSexprWorker", [flag]))
endfunction

" Epilog
let &cpo = s:save_cpo
