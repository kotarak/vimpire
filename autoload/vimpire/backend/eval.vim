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

" Evaluators
function! s:ShowClojureResultCallback(nspace, results)
    let text = []
    for unit in a:results
        if len(unit.output) > 0
            for [event_, output] in unit.output
                call extend(text, map(output, '"; " . v:val'))
            endfor
        endif
        if unit.result[0] == "exception"
            let ex      = vimpire#exc#ReadResponse(unit.result[1])
            let toPrint = vimpire#exc#PPrintException(ex)
            call extend(text, split(toPrint, '\r\?\n'))
        else
            call extend(text, split(vimpire#edn#Write(unit.result[1]), '\r\?\n'))
        endif
    endfor

    call vimpire#ui#ShowClojureResult(text, a:nspace)
endfunction

function! vimpire#backend#eval#RequireFile(all)
    let nspace = b:vimpire_namespace
    let cmd = vimpire#edn#List(
                \ [vimpire#edn#Symbol("clojure.core", "require"),
                \  vimpire#edn#Keyword(a:all ? "reload-all" : "reload"),
                \  vimpire#edn#Keyword("verbose"),
                \  vimpire#edn#List(
                \   [vimpire#edn#Symbol("clojure.core", "symbol"), nspace])])

    let server = vimpire#connection#ForBuffer()

    call vimpire#connection#Eval(server,
                \ vimpire#edn#Write(cmd),
                \ {"result":
                \  function("s:ShowClojureResultCallback",
                \    [nspace])
                \ })
endfunction

function! vimpire#backend#eval#EvalWithPosition(server, fname, line, column,
            \ nspace, code, handlers)
    let nspace = a:server.namespace

    call vimpire#connection#Eval(a:server,
                \ vimpire#edn#Write(vimpire#edn#List(
                \   [vimpire#edn#Symbol("clojure.core", "in-ns"),
                \    vimpire#edn#List(
                \      [vimpire#edn#Symbol("clojure.core", "symbol"),
                \       a:nspace])])),
                \ {})
    call vimpire#connection#Action(
                \ a:server,
                \ ":set-source",
                \ {":unrepl/sourcename": a:fname,
                \  ":unrepl/line":       a:line - 1,
                \  ":unrepl/column":     a:column},
                \ {})

    call vimpire#connection#Eval(a:server, a:code, a:handlers)

    call vimpire#connection#Eval(a:server,
                \ vimpire#edn#Write(vimpire#edn#List(
                \   [vimpire#edn#Symbol("clojure.core", "in-ns"),
                \    vimpire#edn#List(
                \      [vimpire#edn#Symbol("clojure.core", "symbol"),
                \       nspace])])),
                \ {})
    call vimpire#connection#Action(
                \ a:server,
                \ ":set-source",
                \ {":unrepl/sourcename": "Tooling Repl",
                \  ":unrepl/line": 1,
                \  ":unrepl/column": 1},
                \ {})
endfunction

function! s:EvalOperatorWorker(type)
    let server = vimpire#connection#ForBuffer()

    let nspace = b:vimpire_namespace
    let file   = vimpire#util#BufferName()

    let [ line, col, exp ] = vimpire#util#WithSavedPosition(
                \ function("vimpire#util#OpTextExtractor", [a:type]))

    call vimpire#connection#Action(
                \ server,
                \ ":vimpire/check-syntax",
                \ {":nspace":  nspace, ":content": exp},
                \ {"eval": function("s:EvalOperatorSyntaxChecked",
                \   [server, file, line, col, nspace, exp])})
endfunction

function! s:EvalOperatorSyntaxChecked(server, file, line, col, nspace,
            \ exp, validSyntax)
    if a:validSyntax
        call vimpire#backend#eval#EvalWithPosition(a:server,
                    \ a:file, a:line, a:col, a:nspace,
                    \ a:exp,
                    \ {"result":
                    \  function("s:ShowClojureResultCallback",
                    \    [a:nspace])
                    \ })
    else
        call vimpire#ui#ReportError("Syntax check failed:\n\n" . a:exp)
    endif
endfunction

" We have to inline this, operatorfunc cannot take functions.
function! vimpire#backend#eval#EvalOperator(type)
    call vimpire#ui#ProtectedPlug(
                \ function("vimpire#ui#CommandPlug"),
                \ function("s:EvalOperatorWorker"),
                \ a:type)
endfunction

" Epilog
let &cpo = s:save_cpo
