" Part of a Vim filetype plugin for Clojure
" Language:     Clojure
" Maintainer:   Meikel Brandmeyer <mb@kotka.de>

let s:save_cpo = &cpo
set cpo&vim

function! vimpire#backend#Connect(server, ...)
    if a:0 > 0
        let scope = a:1
    else
        let scope = "global"
    endif

    let server = vimpire#backend#server#New(a:server)
    if scope == "buffer"
        let b:vimpire_server = server
    elseif scope == "tab"
        let t:vimpire_server = server
    else
        let g:vimpire_server = server
    endif
endfunction

function! vimpire#backend#DocLookup(word)
    if a:word == ""
        return
    endif

    let server = vimpire#backend#server#Instance()

    let doc = vimpire#backend#server#Execute(server,
                \ {"op":     "doc-lookup",
                \  "sym":    a:word,
                \  "nspace": b:vimpire_namespace})

    call vimpire#ui#ShowResult(doc)
endfunction

function! vimpire#backend#FindDoc()
    let server = vimpire#backend#server#Instance()

    let pattern = input("Pattern to look for: ")
    let doc = vimpire#backend#server#Execute(server,
                \ {"op":    "find-doc",
                \  "query": pattern})
    call vimpire#ui#ShowResult(doc)
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

function! vimpire#backend#JavadocLookup(word)
    let server = vimpire#backend#server#Instance()

    let word = substitute(a:word, "\\.$", "", "")
    let path = vimpire#backend#server#Execute(server,
                \ {"op":     "javadoc-path",
                \  "sym":    word,
                \  "nspace": b:vimpire_namespace})

    if path.stderr != ""
        call vimpire#ui#ShowResult(path)
        return
    endif

    let match = ""
    for pattern in keys(g:vimpire#JavadocPathMap)
        if path.value =~ "^" . pattern && len(match) < len(pattern)
            let match = pattern
        endif
    endfor

    if match == ""
        throw "Vimpire: No matching Javadoc URL found for " . path.value
    endif

    let url = g:vimpire#JavadocPathMap[match] . path.value
    call system(join([g:vimpire#Browser, url], " "))
endfunction

function! vimpire#backend#SourceLookup(word)
    let server = vimpire#backend#server#Instance()

    let source = vimpire#backend#server#Execute(server,
                \ {"op":     "source-lookup",
                \  "sym":    a:word,
                \  "nspace": b:vimpire_namespace})
    call vimpire#ui#ShowClojureResult(source, b:vimpire_namespace)
endfunction

function! vimpire#backend#MetaLookup(word)
    let server = vimpire#backend#server#Instance()

    let meta = vimpire#backend#server#Execute(server,
                \ {"op":     "meta-lookup",
                \  "sym":    a:word,
                \  "nspace": b:vimpire_namespace})
    call vimpire#ui#ShowClojureResult(meta, b:vimpire_namespace)
endfunction

function! vimpire#backend#GotoSource(word)
    let server = vimpire#backend#server#Instance()

    let meta = vimpire#backend#server#Execute(server,
                \ {"op":     "source-location",
                \  "sym":    a:word,
                \  "nspace": b:vimpire_namespace})

    if pos.stderr != ""
        call vimpire#ui#ShowResult(pos)
        return
    endif

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

" Evaluators
function! vimpire#backend#MacroExpand(firstOnly)
    let server = vimpire#backend#server#Instance()

    let [unused, sexp] = vimpire#util#ExtractSexpr(0)
    let expanded = vimpire#backend#server#Execute(server,
                \ {"op":     "macro-expand",
                \  "one?":   (a:firstOnly ? v:true : v:false),
                \  "nspace": b:vimpire_namespace,
                \  "stdin":  sexp})
    call vimpire#ui#ShowClojureResult(expanded, b:vimpire_namespace)
endfunction

function! vimpire#backend#RequireFile(all)
    let server = vimpire#backend#server#Instance()

    let ns = b:vimpire_namespace
    let all = a:all ? "-all" : ""
    let require = "(require :reload" . all . " :verbose '". ns. ")"


    let result = vimpire#backend#server#Execute(server,
                \ {"op":     "repl",
                \  "stdin":  require})

    call vimpire#ui#ShowClojureResult(result, ns)
endfunction

function! vimpire#backend#RunTests(all)
    let server = vimpire#backend#server#Instance()

    let ns = b:vimpire_namespace

    let result = vimpire#backend#server#Execute(server,
                \ {"op":     "run-tests",
                \  "all?":   (a:all ? v:true : v:false)
                \  "nspace": ns})
    call vimpire#ui#ShowClojureResult(result, ns)
endfunction

function! vimpire#backend#EvalFile()
    let server = vimpire#backend#server#Instance()

    let content = getbufline(bufnr("%"), 1, line("$"))
    let file = vimpire#util#BufferName()
    let ns = b:vimpire_namespace

    let result = vimpire#backend#server#Execute(server,
                \ {"op":     "repl",
                \  "file":   file,
                \  "nspace": ns,
                \  "stdin":  join(content, "\n")})

    call vimpire#ui#ShowClojureResult(result, ns)
endfunction

function! vimpire#backend#EvalLine()
    let server = vimpire#backend#server#Instance()

    let theLine = line(".")
    let content = getline(theLine)
    let file = vimpire#util#BufferName()
    let ns = b:vimpire_namespace

    let result = vimpire#backend#server#Execute(server,
                \ {"op":     "repl",
                \  "file":   file,
                \  "line":   theLine,
                \  "nspace": ns,
                \  "stdin":  content})

    call vimpire#ui#ShowClojureResult(result, ns)
endfunction

function! vimpire#backend#EvalBlock()
    let server = vimpire#backend#server#Instance()

    let file = vimpire#util#BufferName()
    let ns = b:vimpire_namespace

    let content = vimpire#util#Yank("l", 'normal! gv"ly')
    let result = vimpire#backend#server#Execute(server,
                \ {"op":     "repl",
                \  "file":   file,
                \  "line":   line("'<") - 1,
                \  "nspace": ns,
                \  "stdin":  content})

    call vimpire#ui#ShowClojureResult(result, ns)
endfunction

function! vimpire#backend#EvalToplevel()
    let server = vimpire#backend#server#Instance()

    let file = vimpire#util#BufferName()
    let ns = b:vimpire_namespace
    let [pos, expr] = vimpire#util#ExtractSexpr(1)

    let result = vimpire#backend#server#Execute(server,
                \ {"op":     "repl",
                \  "file":   file,
                \  "line":   pos[0] - 1,
                \  "nspace": ns,
                \  "stdin":  expr})

    call vimpire#ui#ShowClojureResult(result, ns)
endfunction

function! VimpireEvalParagraphWorker() dict
    normal! }
    return line(".")
endfunction

function! vimpire#backend#EvalParagraph()
    let server = vimpire#backend#server#Instance()

    let file = vimpire#util#BufferName()
    let ns = b:vimpire_namespace
    let startPosition = line(".")

    let closure = { 'f' : function("VimpireEvalParagraphWorker") }

    let endPosition = vimpire#util#WithSavedPosition(closure)

    let content = getbufline(bufnr("%"), startPosition, endPosition)
    let result = vimpire#backend#server#Execute(server,
                \ {"op":     "repl",
                \  "file":   file,
                \  "line":   startPosition - 1,
                \  "nspace": ns,
                \  "stdin":  join(content, "\n")})

    call vimpire#ui#ShowClojureResult(result, ns)
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
        " Get the namespace of the buffer.
        if &previewwindow
            let b:vimpire_namespace = "user"
        else
            try
                let server = vimpire#backend#server#Instance()
                let content = getbufline(bufnr("%"), 1, line("$"))
                let namespace = vimpire#backend#server#Execute(server,
                            \ {"op": "namespace-of-file",
                            \  "stdin": join(content, "\n")})
                if namespace.stderr != ""
                    throw namespace.stderr
                endif
                let b:vimpire_namespace = namespace.value
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
