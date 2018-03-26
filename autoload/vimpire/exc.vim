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

" Taken from clj-stacktrace: https://github.com/mmcgrana/clj-stacktrace
" Returns true if the filename is non-null and indicates a clj source file.
function! s:IsClojureCode(className, file)
    return a:className =~ '^user'
                \ || a:file == "NO_SOURE_FILE"
                \ || a:file == "unrepl-session"
                \ || a:file =~ "\.clj$"
endfunction

" Returns the clojure namespace name implied by the bytecode class name.
function! s:ClojureNspace(className)
    let nspace = matchstr(a:className, '[^$]\+\$\@=')
    if nspace == ""
        let nspace = matchlist(a:className, '\(.\+\)\.[^.]\+$')[1]
    endif

    return substitute(nspace, "_", "-", "g")
endfunction

" drop everything before and including the first $
" drop everything after and including and the second $
" drop any __xyz suffixes
" sub _PLACEHOLDER_ for the corresponding char
let s:ClojureFnSubs = [
            \ ['^[^$]*\$', ''],
            \ ['\$.*',     ''],
            \ ['__\d\+.*', ''],
            \ ['_QMARK_',  '?'],
            \ ['_BANG_',   '!'],
            \ ['_PLUS_',   '+'],
            \ ['_GT_',     '>'],
            \ ['_LT_',     '<'],
            \ ['_EQ_',     '='],
            \ ['_STAR_',   '*'],
            \ ['_SLASH_',  '/'],
            \ ['_',        '-']]

" Returns the clojure function name implied by the bytecode class name.
function! s:ClojureFn(className)
    let className = a:className
    for [ pattern, replacement ] in s:ClojureFnSubs
        let className = substitute(className, pattern, replacement, '')
    endfor
    return className
endfunction

" Returns true if the bytecode class name implies an anonymous inner fn.
function! s:IsClojureAnonFn(className)
    return a:className =~ '\$.*\$'
endfunction

" Returns a map of information about the java trace element.
" All returned maps have the keys:
"   file      String of source file name.
"   line      Number of source line number of the enclosing form.
"   type      Indicating a clojure or java elem.
" Additionally for elements from Java code:
"   class     String of the name of the class to which the method belongs.
"   method    String of the name of the method.
" Additionally for elements from Clojure code:
"   nspace    String representing the namespace of the function.
"   fn        String representing the name of the enclosing var for
"             the function.
"   anonFn    v:true iff the function is an anonymous inner fn.
function! s:ParseTraceElement(traceElem)
    let [ className, method, file, line ] = a:traceElem

    let parsed = {"file": file, "line": line}
    if s:IsClojureCode(className, file)
        let parsed.type    = "clojure"
        let parsed.nspace  = s:ClojureNspace(className)
        let parsed.fn      = s:ClojureFn(className)
        let parsed.anonFn  = s:IsClojureAnonFn(className)
    else
        let parsed.type    = "java"
        let parsed.class   = className
        let parsed.method  = method
    endif

    return parsed
endfunction

function! s:ClojureMethodString(parsed)
    return a:parsed.nspace . "/" . a:parsed.fn
                \ . (a:parsed.anonFn ? "[fn]" : "")
endfunction

function! s:JavaMethodString(parsed)
    return a:parsed.class . "." . a:parsed.method
endfunction

function! s:MethodString(parsed)
    if a:parsed.type == "java"
        return s:JavaMethodString(a:parsed)
    else
        return s:ClojureMethodString(a:parsed)
    endif
endfunction

function! s:SourceString(parsed)
    return "(" . a:parsed.file . ":" . a:parsed.line . ")"
endfunction

function! s:PrintTraceElement(parsed)
    return s:MethodString(a:parsed) . " " . s:SourceString(a:parsed)
endfunction

function! vimpire#exc#PPrintException(error)
    let output = ["Cause: " . a:error.cause]
    if len(a:error.trace) == 0
        call add(output, " at [empty stack trace]")
    else
        let [ first; rest ] = map(copy(a:error.trace),
                    \ 's:ParseTraceElement(v:val)')
        call add(output, " at " . s:PrintTraceElement(first))
        call extend(output, map(rest, '"    " . s:PrintTraceElement(v:val)'))
    endif

    if a:error.incomplete
        call add(output, "    …")
    endif

    return join(output, "\n")
endfunction

let s:ElisionSymbol = vimpire#edn#Symbol("unrepl", "...")

function! vimpire#exc#ReadResponse(response)
    " Exceptions are tagged as #error.
    let ex = vimpire#edn#SimplifyMap(a:response)[":ex"]["edn/value"]
    let ex = vimpire#edn#SimplifyMap(ex)

    let stackTrace = []
    let incomplete = v:false
    for elem in ex[":trace"]
        if vimpire#edn#IsTaggedLiteral(elem, s:ElisionSymbol)
            let incomplete = v:true
            break
        endif

        call add(stackTrace, vimpire#edn#Simplify(elem))
    endfor
    return {"cause": ex[":cause"],
                \ "trace": stackTrace, "incomplete": incomplete}
endfunction

" Epilog
let &cpo = s:save_cpo
