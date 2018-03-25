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

function! vimpire#backend#doc#DocLookup(word)
    if a:word == ""
        return
    endif

    let server = vimpire#connection#ForBuffer()
    call vimpire#connection#Action(
                \ server,
                \ ":vimpire/doc-lookup",
                \ {":nspace": b:vimpire_namespace, ":sym": a:word},
                \ {"eval": function("vimpire#ui#ShowResult")})
endfunction

function! vimpire#backend#doc#FindDoc()
    let pattern = input("Pattern to look for: ")

    let server = vimpire#connection#ForBuffer()
    call vimpire#connection#Action(
                \ server,
                \ ":vimpire/find-doc",
                \ {":query": pattern},
                \ {"eval": function("vimpire#ui#ShowResult")})
endfunction

let s:DefaultJavadocPaths = {
            \ "java" : "https://docs.oracle.com/javase/8/docs/api/",
            \ "org/apache/commons/beanutils" : "http://commons.apache.org/beanutils/api/",
            \ "org/apache/commons/chain" : "http://commons.apache.org/chain/api-release/",
            \ "org/apache/commons/cli" : "http://commons.apache.org/cli/api-release/",
            \ "org/apache/commons/codec" : "http://commons.apache.org/codec/api-release/",
            \ "org/apache/commons/collections" : "http://commons.apache.org/collections/api-release/",
            \ "org/apache/commons/logging" : "http://commons.apache.org/logging/apidocs/",
            \ "org/apache/commons/mail" : "http://commons.apache.org/email/api-release/",
            \ "org/apache/commons/io" : "http://commons.apache.org/io/api-release/"
            \ }

if !exists("g:vimpire_javadoc_path_map")
    let g:vimpire_javadoc_path_map = {}
endif

call extend(g:vimpire_javadoc_path_map, s:DefaultJavadocPaths, "keep")

if !exists("g:vimpire_browser")
    if has("win32") || has("win64")
        let g:vimpire_browser = "start"
    elseif has("mac")
        let g:vimpire_browser = "open"
    else
        " some freedesktop thing, whatever, issue #67
        let g:vimpire_browser = "xdg-open"
    endif
endif

function! s:JavadocLookupCallback(path)
    let match = ""
    for pattern in keys(g:vimpire_javadoc_path_map)
        if a:path =~ "^" . pattern && len(match) < len(pattern)
            let match = pattern
        endif
    endfor

    if match == ""
        call vimpire#ui#ReportError("Vimpire: "
                    \ . "No matching Javadoc URL found for " . a:path)
        return
    endif

    let url = g:vimpire_javadoc_path_map[match] . a:path
    call system(g:vimpire_browser . " " . url)
endfunction

function! vimpire#backend#doc#JavadocLookup(word)
    let word = substitute(a:word, "\\.$", "", "")

    let server = vimpire#connection#ForBuffer()
    call vimpire#connection#Action(
                \ server,
                \ ":vimpire/javadoc-path",
                \ {":nspace": b:vimpire_namespace, ":sym": word},
                \ {"eval": function("s:JavadocLookupCallback")})
endfunction

function! vimpire#backend#doc#SourceLookup(word)
    let nspace = b:vimpire_namespace

    let server = vimpire#connection#ForBuffer()
    call vimpire#connection#Action(
                \ server,
                \ ":vimpire/source-lookup",
                \ {":nspace": b:vimpire_namespace, ":sym": a:word},
                \ {"eval": { val ->
                \     vimpire#ui#ShowClojureResult(val, nspace)
                \ }})
endfunction

" Epilog
let &cpo = s:save_cpo
