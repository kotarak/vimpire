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

function! vimpire#backend#ShowClojureResultCallback(nspace)
    return { val -> vimpire#ui#ShowClojureResult(vimpire#edn#Write(val), a:nspace) }
endfunction

function! vimpire#backend#DocLookup(word)
    if a:word == ""
        return
    endif

    let server = vimpire#connection#ForBuffer()
    call vimpire#connection#Action(
                \ server,
                \ ":vimpire.nails/doc-lookup",
                \ {":nspace": b:vimpire_namespace, ":sym": a:word},
                \ {"eval": function("vimpire#ui#ShowResult")})
endfunction

function! vimpire#backend#FindDoc()
    let pattern = input("Pattern to look for: ")

    let server = vimpire#connection#ForBuffer()
    call vimpire#connection#Action(
                \ server,
                \ ":vimpire.nails/find-doc",
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

function! vimpire#backend#JavadocLookupCallback(path)
    let match = ""
    for pattern in keys(g:vimpire_javadoc_path_map)
        if a:path =~ "^" . pattern && len(match) < len(pattern)
            let match = pattern
        endif
    endfor

    if match == ""
        call vimpire#ui#ReportError("Vimpire: No matching Javadoc URL found for " . a:path)
        return
    endif

    let url = g:vimpire_javadoc_path_map[match] . a:path
    call system(g:vimpire_browser . " " . url)
endfunction

function! vimpire#backend#JavadocLookup(word)
    let word = substitute(a:word, "\\.$", "", "")

    let server = vimpire#connection#ForBuffer()
    call vimpire#connection#Action(
                \ server,
                \ ":vimpire.nails/javadoc-path",
                \ {":nspace": b:vimpire_namespace, ":sym": word},
                \ {"eval": function("vimpire#backend#JavadocLookupCallback")})
endfunction

function! vimpire#backend#SourceLookup(word)
    let nspace = b:vimpire_namespace

    let server = vimpire#connection#ForBuffer()
    call vimpire#connection#Action(
                \ server,
                \ ":vimpire.nails/source-lookup",
                \ {":nspace": b:vimpire_namespace, ":sym": a:word},
                \ {"eval": { val ->
                \     vimpire#ui#ShowClojureResult(val, nspace)
                \ }})
endfunction

function! vimpire#backend#GotoSourceCallback(pos)
    let pos = vimpire#edn#Simplify(a:pos)

    if !filereadable(pos[":file"])
        let file = globpath(&path, pos[":file"])
        if file == ""
            call vimpire#ui#ReportError("Vimpire: " . pos[":file"] . " not found in 'path'")
            return
        endif
        let pos[":file"] = file
    endif

    execute "edit " . pos[":file"]
    execute pos[":line"]
endfunction

function! vimpire#backend#GotoSource(word)
    let server = vimpire#connection#ForBuffer()
    call vimpire#connection#Action(
                \ server,
                \ ":vimpire.nails/source-location",
                \ {":nspace": b:vimpire_namespace, ":sym": a:word},
                \ {"eval": function("vimpire#backend#GotoSourceCallback")})
endfunction

" Evaluators
function! s:RequireFileCallback(nspace, x, value)
    let value = vimpire#edn#Write(a:value)
    let text = a:x.output . "\n" . value

    call vimpire#ui#ShowClojureResult(text, a:nspace)
endfunction

function! vimpire#backend#RequireFile(all)
    let nspace = b:vimpire_namespace
    let cmd = vimpire#edn#List(
                \ [vimpire#edn#Symbol("require"),
                \  vimpire#edn#Keyword(a:all ? ":reload-all" : ":reload"),
                \  vimpire#edn#Keyword(":verbose"),
                \  vimpire#edn#List(
                \   [vimpire#edn#Symbol("quote"),
                \    vimpire#edn#Symbol(nspace)])])

    let server = vimpire#connection#ForBuffer()

    let x = {"output" : ""}
    call vimpire#connection#Eval(server,
                \ vimpire#edn#Write(cmd),
                \ {"eval": function("s:RequireFileCallback", [nspace, x]),
                \  "out":  {val -> extend(x, {"output": x.output . val})}})
endfunction

function! vimpire#backend#RunTests(all)
    let nspace = b:vimpire_namespace

    let server = vimpire#connection#ForBuffer()
    call vimpire#connection#Action(
                \ server,
                \ ":vimpire.nails/run-tests",
                \ {":nspace": b:vimpire_namespace,
                \  ":all?":   (a:all ? v:true : v:false)},
                \ {"eval": { val -> vimpire#ui#ShowResult(val) }})
endfunction

function! vimpire#backend#EvalWithPosition(server, fname, line, column, nspace,
            \ code, handlers)
    let nspace = a:server.namespace

    call vimpire#connection#Eval(a:server, "(in-ns '" . a:nspace . ")", {})
    call vimpire#connection#Action(
                \ a:server,
                \ ":set-source",
                \ {":unrepl/sourcename": a:fname,
                \  ":unrepl/line":       a:line - 1,
                \  ":unrepl/column":     a:column},
                \ {})

    call vimpire#connection#Eval(a:server, a:code, a:handlers)

    call vimpire#connection#Eval(a:server, "(in-ns '" . nspace . ")", {})
    call vimpire#connection#Action(
                \ a:server,
                \ ":set-source",
                \ {":unrepl/sourcename": "Tooling Repl",
                \  ":unrepl/line": 1,
                \  ":unrepl/column": 1},
                \ {})
endfunction

function! s:SexpExtractor(type)
    if a:type == "line"
        normal! '[
        return [line("."), col("."), vimpire#util#Yank("l", "normal! V']\"ly")]
    else
        normal! `[
        return [line("."), col("."), vimpire#util#Yank("l", "normal! v`]\"ly")]
    endif
endfunction

function! s:EvalOperatorWorker(type)
    let server = vimpire#connection#ForBuffer()

    let nspace = b:vimpire_namespace
    let file   = vimpire#util#BufferName()

    let [ line, col, exp ] = vimpire#util#WithSavedPosition(
                \ function("s:SexpExtractor", [a:type]))

    call vimpire#connection#Action(
                \ server,
                \ ":vimpire.nails/check-syntax",
                \ {":nspace":  nspace, ":content": exp},
                \ {"eval": function("s:EvalOperatorSyntaxChecked",
                \   [server, file, line, col, nspace, exp])})
endfunction

function! s:EvalOperatorSyntaxChecked(server, file, line, col, nspace,
            \ exp, validSyntax)
    if a:validSyntax
        call vimpire#backend#EvalWithPosition(a:server,
                    \ a:file, a:line, a:col, a:nspace,
                    \ a:exp,
                    \ {"eval":
                    \  vimpire#backend#ShowClojureResultCallback(a:nspace)})
    else
        call vimpire#ui#ReportError("Syntax check failed:\n\n" . a:exp)
    endif
endfunction

" We have to inline this, operatorfunc cannot take functions.
function! vimpire#backend#EvalOperator(type)
    call vimpire#ui#ProtectedPlug(
                \ function("vimpire#ui#CommandPlug"),
                \ function("s:EvalOperatorWorker"),
                \ a:type)
endfunction

function! s:MacroExpandWorker(type, firstOnly)
    let server = vimpire#connection#ForBuffer()
    let nspace = b:vimpire_namespace

    let [ line, col, exp ] = vimpire#util#WithSavedPosition(
                \ function("s:SexpExtractor", [a:type]))

    call vimpire#connection#Action(
                \ server,
                \ ":vimpire.nails/macro-expand",
                \ {":nspace": nspace,
                \  ":one?":   (a:firstOnly ? v:true : v:false),
                \  ":form":   exp},
                \ {"eval":    { val ->
                \    vimpire#ui#ShowClojureResult(val, nspace)
                \ }})
endfunction

function! vimpire#backend#MacroExpand(type)
    call vimpire#ui#ProtectedPlug(
                \ function("vimpire#ui#CommandPlug"),
                \ function("s:MacroExpandWorker"),
                \ a:type, v:false)
endfunction

function! vimpire#backend#MacroExpand1(type)
    call vimpire#ui#ProtectedPlug(
                \ function("vimpire#ui#CommandPlug"),
                \ function("s:MacroExpandWorker"),
                \ a:type, v:true)
endfunction

" Async Completion
function! vimpire#backend#AsyncComplete(line, col, cont)
    let start = a:col

    let base = matchstr(a:line, '\(\w\|[/_*<>=+-]\)\+$')
    if base == ""
        return
    endif

    let start  = a:col - strlen(base) + 1

    let prefix = ""
    let slash = stridx(base, '/')
    if slash > -1
        let prefix = strpart(base, 0, slash)
        let base   = strpart(base, slash + 1)
    endif

    let server = vimpire#connection#ForBuffer()
    call vimpire#connection#Action(
                \ server,
                \ ":vimpire.nails/complete",
                \ {":nspace": b:vimpire_namespace,
                \  ":prefix": prefix,
                \   ":base":  base},
                \ {"eval": function(a:cont, [start])})
endfunction

if !exists("g:vimpire_dynamic_highlighting")
    let g:vimpire_dynamic_highlighting = v:true
endif

function! s:DynamicHighlightingCallback(this, nspace, highlights)
    let a:this.dynamicHighlightingCache[a:nspace] = a:highlights

    for [category, words] in items(a:highlights)
        if len(words) > 0
            execute "syntax keyword clojure" . category . " " . join(words, " ")
        endif
    endfor
endfunction

function! vimpire#backend#DynamicHighlighting()
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
                \ ":vimpire.nails/dynamic-highlighting",
                \ {":nspace": b:vimpire_namespace},
                \ {"eval":
                \  function("s:DynamicHighlightingCallback", [server, nspace])})
endfunction

function! s:InitBufferCallback(buffer, nspace)
    call setbufvar(a:buffer, "vimpire_namespace", a:nspace)
    if exists("g:vimpire_dynamic_highlighting")
                \ && g:vimpire_dynamic_highlighting
        call vimpire#backend#DynamicHighlighting()
    endif
endfunction

function! vimpire#backend#InitBuffer(...)
    if exists("b:vimpire_namespace")
        return
    endif

    if !&previewwindow
        " Get the namespace of the buffer.
        try
            let buffer  = bufnr("%")
            let content = join(getbufline(buffer, 1, line("$")), "\n")
            let server  = vimpire#connection#ForBuffer()
            call vimpire#connection#Action(
                        \ server,
                        \ ":vimpire.nails/namespace-of-file",
                        \ {":content": content},
                        \ {"eval": function("s:InitBufferCallback", [buffer])})
        catch /Vimpire: No connection found/
            " Do nothing. Fail silently in this case.
        catch /.*/
            if a:000 == []
                call vimpire#ui#ReportError(
                            \ "Could not determine the Namespace of the file.\n\n"
                            \ . "This might have different reasons. Please check, that the server\n"
                            \ . "is running and that the file does not contain syntax errors. The\n"
                            \ . "interactive features will not be enabled.\n"
                            \ . "\nReason:\n" . v:exception)
            endif
        endtry
    endif
endfunction

" Epilog
let &cpo = s:save_cpo
