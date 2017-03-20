" Vim syntax file
" Language:    Clojure
" Maintainer:  Meikel Brandmeyer <mb@kotka.de>
" URL:         https://bitbucket.org/kotarak/vimpire

" Special case for Windows.
try
    call vimpire#backend#InitBuffer()
catch /.*/
    " We swallow a failure here. It means most likely that the
    " server is not running.
    echohl WarningMsg
    echomsg v:exception
    echohl None
endtry

if !exists("*s:ColorNamespace")
    function s:ColorNamespace(highlights)
        for [category, words] in items(a:highlights)
            if words != []
                execute "syntax keyword clojure" . category . " " . join(words, " ")
            endif
        endfor
    endfunction
endif

if exists("b:vimpire_namespace")
    try
        let s:server = vimpire#backend#server#Instance()
        let s:result = vimpire#backend#server#Execute(s:server,
                    \ {"op":     "dynamic-highlighting",
                    \  "nspace": b:vimpire_namespace})
        if s:result.stderr == ""
            call s:ColorNamespace(s:result.value)
        endif
        unlet s:result
        unlet s:server
    catch /.*/
        " We ignore errors here. If the file is messed up, we at least get
        " the basic syntax highlighting.
    endtry
endif
