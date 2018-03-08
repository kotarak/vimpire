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

function! vimpire#backend#Action(action, bindings, callback)
    let server = vimpire#connection#ForBuffer()

    let action = vimpire#connection#ExpandAction(
                \ server.actions[a:action],
                \ extend({":nspace": b:vimpire_namespace}, a:bindings))
    let code   = vimpire#edn#Write(action)

    call vimpire#connection#Eval(server, code, {"eval": a:callback})
endfunction

function! vimpire#backend#ShowClojureResultCallback(nspace)
    return { val -> vimpire#ui#ShowClojureResult(vimpire#edn#Write(val), a:nspace) }
endfunction

function! vimpire#backend#DocLookup(word)
    if a:word == ""
        return
    endif

    call vimpire#backend#Action(":vimpire.nails/doc-lookup",
                \ {":sym": a:word},
                \ function("vimpire#ui#ShowResult"))
endfunction

function! vimpire#backend#FindDoc()
    let pattern = input("Pattern to look for: ")

    call vimpire#backend#Action(":vimpire.nails/find-doc",
                \ {":query": pattern},
                \ function("vimpire#ui#ShowResult"))
endfunction

let s:DefaultJavadocPaths = {
            \ "java" : "http://java.sun.com/javase/8/docs/api/",
            \ "org/apache/commons/beanutils" : "http://commons.apache.org/beanutils/api/",
            \ "org/apache/commons/chain" : "http://commons.apache.org/chain/api-release/",
            \ "org/apache/commons/cli" : "http://commons.apache.org/cli/api-release/",
            \ "org/apache/commons/codec" : "http://commons.apache.org/codec/api-release/",
            \ "org/apache/commons/collections" : "http://commons.apache.org/collections/api-release/",
            \ "org/apache/commons/logging" : "http://commons.apache.org/logging/apidocs/",
            \ "org/apache/commons/mail" : "http://commons.apache.org/email/api-release/",
            \ "org/apache/commons/io" : "http://commons.apache.org/io/api-release/"
            \ }

if !exists("g:vimpire#JavadocPathMap")
    let vimpire#JavadocPathMap = {}
endif

for k in keys(s:DefaultJavadocPaths)
    if !has_key(vimpire#JavadocPathMap, k)
        let vimpire#JavadocPathMap[k] = s:DefaultJavadocPaths[k]
    endif
endfor

if !exists("g:vimpire#Browser")
    if has("win32") || has("win64")
        let vimpire#Browser = "start"
    elseif has("mac")
        let vimpire#Browser = "open"
    else
        " some freedesktop thing, whatever, issue #67
        let vimpire#Browser = "xdg-open"
    endif
endif

function! vimpire#backend#JavadocLookupCallback(path)
    let match = ""
    for pattern in keys(g:vimpire#JavadocPathMap)
        if a:path =~ "^" . pattern && len(match) < len(pattern)
            let match = pattern
        endif
    endfor

    if match == ""
        throw "Vimpire: No matching Javadoc URL found for " . a:path
    endif

    let url = g:vimpire#JavadocPathMap[match] . a:path
    call system(join([g:vimpire#Browser, url], " "))
endfunction

function! vimpire#backend#JavadocLookup(word)
    let word = substitute(a:word, "\\.$", "", "")

    call vimpire#backend#Action(":vimpire.nails/javadoc-path",
                \ {":sym": pattern},
                \ function("vimpire#backend#JavadocLookupCallback"))
endfunction

function! vimpire#backend#SourceLookup(word)
    let nspace = b:vimpire_namespace

    call vimpire#backend#Action(":vimpire.nails/source-lookup",
                \ {":sym": a:word},
                \ vimpire#backend#ShowClojureResultCallback(nspace))
endfunction

function! vimpire#backend#MetaLookup(word)
    let nspace = b:vimpire_namespace

    call vimpire#backend#Action(":vimpire.nails/meta-lookup",
                \ {":sym": a:word},
                \ vimpire#backend#ShowClojureResultCallback(nspace))
endfunction

" FIXME
function! vimpire#backend#GotoSourceCallBack(pos)
    if !filereadable(pos.value.file)
        let file = globpath(&path, pos.value.file)
        if file == ""
            throw "Vimpire: " . pos.value.file . " not found in 'path'"
        endif
        let pos.value.file = file
    endif

    execute "edit " . pos.value.file
    execute pos.value.line
endfunction

function! vimpire#backend#GotoSource(word)
    call vimpire#backend#Action(":vimpire.nails/source-location",
                \ {":sym": a:word},
                \ function("vimpire#backend#GotoSourceCallback"))
endfunction

" Evaluators
function! vimpire#backend#MacroExpand(firstOnly)
    let nspace = b:vimpire_namespace
    let [unused, sexp] = vimpire#util#ExtractSexpr(0)

    call vimpire#backend#Action(":vimpire.nails/source-location",
                \ {":one?": (a:firstOnly ? v:true : v:false),
                \  ":form": sexp},
                \ vimpire#backend#ShowClojureResultCallback(nspace))
endfunction

function! vimpire#backend#RequireFile(all)
    let nspace = b:vimpire_namespace
    let all = a:all ? "-all" : ""
    let require = "(require :reload" . all . " :verbose '". ns. ")"

    let server = vimpire#connection#ForBuffer()
    call vimpire#connection#Eval(server,
                \ require,
                \ {"eval": vimpire#backend#ShowClojureResultCallback(nspace)})
endfunction

function! vimpire#backend#RunTests(all)
    let nspace = b:vimpire_namespace

    call vimpire#backend#Action(":vimpire.nails/run-tests",
                \ {":all?": (a:all ? v:true : v:false)},
                \ vimpire#backend#ShowClojureResultCallback(nspace))
endfunction

function! vimpire#backend#EvalWithPosition(fname, line, column, f)
    call vimpire#backend#Action(":set-source",
                \ {":unrepl/sourcename": a:fname,
                \  ":unrepl/line":       a:line,
                \  ":unrepl/column":     a:column},
                \ { val -> val })

    call a:f()

    call vimpire#backend#Action(":set-source",
                \ {":unrepl/sourcename": "Tooling Repl",
                \  ":unrepl/line": 1,
                \  ":unrepl/column": 1},
                \ { val -> val })
endfunction

function! vimpire#backend#EvalFile()
    let server  = vimpire#connection#ForBuffer()
    let nspace  = b:vimpire_namespace
    let content = join(getbufline(bufnr("%"), 1, line("$")), "\n")
    let file    = vimpire#util#BufferName()

    call vimpire#backend#EvalWithPosition(file, 1, 1, { ->
                \ vimpire#connection#Eval(server,
                \   content,
                \   { "eval": vimpire#backend#ShowClojureResultCallback(nspace)})
                \ })
endfunction

function! vimpire#backend#EvalLine()
    let server  = vimpire#connection#ForBuffer()
    let nspace  = b:vimpire_namespace
    let theLine = line(".")
    let content = getline(theLine)
    let file    = vimpire#util#BufferName()

    call vimpire#backend#EvalWithPosition(file, theLine, 1, { ->
                \ vimpire#connection#Eval(server,
                \   content,
                \   { "eval": vimpire#backend#ShowClojureResultCallback(nspace)})
                \ })
endfunction

function! vimpire#backend#EvalBlock()
    let server  = vimpire#connection#ForBuffer()
    let nspace  = b:vimpire_namespace
    let file    = vimpire#util#BufferName()
    let content = vimpire#util#Yank("l", 'normal! gv"ly')

    call vimpire#backend#EvalWithPosition(file, line("'<") - 1, 1, { ->
                \ vimpire#connection#Eval(server,
                \   content,
                \   { "eval": vimpire#backend#ShowClojureResultCallback(nspace)})
                \ })
endfunction

function! vimpire#backend#EvalToplevel()
    let server  = vimpire#connection#ForBuffer()
    let nspace  = b:vimpire_namespace
    let file    = vimpire#util#BufferName()
    let [pos, expr] = vimpire#util#ExtractSexpr(1)

    call vimpire#backend#EvalWithPosition(file, pos[0] - 1, 1, { ->
                \ vimpire#connection#Eval(server,
                \   expr,
                \   { "eval": vimpire#backend#ShowClojureResultCallback(nspace)})
                \ })
endfunction

function! VimpireEvalParagraphWorker() dict
    normal! }
    return line(".")
endfunction

function! vimpire#backend#EvalParagraph()
    let server = vimpire#connection#ForBuffer()
    let nspace = b:vimpire_namespace
    let file   = vimpire#util#BufferName()
    let startPosition = line(".")

    let endPosition = vimpire#util#WithSavedPosition(
                \ function("VimpireEvalParagraphWorker"))

    let content = join(getbufline(bufnr("%"), startPosition, endPosition), "\n")

    call vimpire#backend#EvalWithPosition(file, startPosition - 1, 1, { ->
                \ vimpire#connection#Eval(server,
                \ content,
                \   { "eval": vimpire#backend#ShowClojureResultCallback(nspace)})
                \ })
endfunction

" Omni Completion
function! vimpire#backend#OmniCompletion(findstart, base)
    if a:findstart == 1
        let line = getline(".")
        let start = col(".") - 1

        while start > 0 && line[start - 1] =~ '\w\|-\|\.\|+\|*\|/'
            let start -= 1
        endwhile

        return start
    else
        let slash = stridx(a:base, '/')
        if slash > -1
            let prefix = strpart(a:base, 0, slash)
            let base = strpart(a:base, slash + 1)
        else
            let prefix = ""
            let base = a:base
        endif

        if prefix == "" && base == ""
            return []
        endif

        let server = vimpire#backend#server#Instance()

        let completions = vimpire#backend#server#Execute(server,
                    \ {"op":     "complete",
                    \  "prefix": prefix,
                    \  "base":   base,
                    \  "nspace": b:vimpire_namespace})
        return completions.value
    endif
endfunction

function! vimpire#backend#InitBuffer(...)
    if !exists("b:vimpire_namespace")
        let b:vimpire_namespace = "user"

        " Get the namespace of the buffer.
        if !&previewwindow
            try
                let buffer  = bufnr("%")
                let content = join(getbufline(buffer, 1, line("$")), "\n")
                call vimpire#backend#Action(":vimpire.nails/namespace-of-file",
                            \ {":content": content},
                            \ { val -> setbufvar(buffer, "vimpire_namespace", val) })
            catch /Vimpire: No backend server found/
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
    endif
endfunction

" Epilog
let &cpo = s:save_cpo
