" Part of a Vim filetype plugin file
" Language:     Clojure
" Maintainer:   Meikel Brandmeyer <mb@kotka.de>

let s:cpo_save = &cpo
set cpo&vim

try
    call vimpire#backend#InitBuffer()
catch /.*/
    " We swallow a failure here. It means most likely that the
    " server is not running.
    echohl WarningMsg
    echomsg v:exception
    echohl None
endtry

if exists("b:vimpire_namespace")
    setlocal omnifunc=vimpire#backend#OmniCompletion

    augroup Vimpire
        au!
        autocmd CursorMovedI <buffer> if pumvisible() == 0 | pclose | endif
    augroup END
endif

let &cpo = s:cpo_save
