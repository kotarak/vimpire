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
" Vim syntax file

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
