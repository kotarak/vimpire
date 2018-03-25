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

function! s:DynamicHighlightingCallback(this, nspace, highlights)
    let a:this.dynamicHighlightingCache[a:nspace] = a:highlights

    for [category, words] in items(a:highlights)
        if len(words) > 0
            execute "syntax keyword clojure" . category . " " . join(words, " ")
        endif
    endfor
endfunction

function! vimpire#backend#dynhighlight#DynamicHighlighting()
    let server = vimpire#connection#ForBuffer()
    let nspace = b:vimpire_namespace

    if !has_key(server, "dynamicHighlightingCache")
        let server.dynamicHighlightingCache = {}
    endif

    if has_key(server.dynamicHighlightingCache, nspace)
        return server.dynamicHighlightingCache[nspace]
    endif

    call vimpire#connection#Action(
                \ server,
                \ ":vimpire/dynamic-highlighting",
                \ {":nspace": b:vimpire_namespace},
                \ {"eval":
                \  function("s:DynamicHighlightingCallback", [server, nspace])})
endfunction

" Epilog
let &cpo = s:save_cpo
