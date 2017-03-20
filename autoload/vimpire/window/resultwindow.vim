" Part of a Vim filetype plugin for Clojure
" Language:     Clojure
" Maintainer:   Meikel Brandmeyer <mb@kotka.de>

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
