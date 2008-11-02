"-
" Copyright 2008 (c) Meikel Brandmeyer.
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
if !has("ruby")
    finish
endif

try
    if !gatekeeper#Guard("b:clojure_gorilla", "1.0.0")
        finish
    endif
catch /^Vim\%((\a\+)\)\=:E117/
    if exists("b:clojure_gorilla_loaded")
        finish
    endif
    let b:clojure_gorilla_loaded = "1.0.0"
endtry

let s:save_cpo = &cpo
set cpo&vim

function! s:MakePlug(mode, plug, f)
    execute a:mode . "noremap <Plug>ClojureGorilla" . a:plug
                \ . " :call <SID>" . a:f . "<CR>"
endfunction

function! s:MapPlug(mode, keys, plug)
    if !hasmapto("<Plug>ClojureGorilla" . a:plug)
        execute a:mode . "map <buffer> <unique> <silent> <LocalLeader>" . a:keys
                    \ . " <Plug>ClojureGorilla" . a:plug
    endif
endfunction

function! s:SynItem()
    return synIDattr(synID(line("."), col("."), 0), "name")
endfunction

function! s:WithSaved(closure)
    let v = a:closure.get(a:closure.tosafe)
    let r = a:closure.f()
    call a:closure.set(a:closure.tosafe, v)
    return r
endfunction

function! s:WithSavedRegister(reg, closure)
    let a:closure['tosafe'] = a:reg
    let a:closure['get'] = function("getreg")
    let a:closure['set'] = function("setreg")
    return s:WithSaved(a:closure)
endfunction

function! s:WithSavedPosition(closure)
    let a:closure['tosafe'] = "."
    let a:closure['get'] = function("getpos")
    let a:closure['set'] = function("setpos")
    return s:WithSaved(a:closure)
endfunction

function! s:Yank(reg, how)
    let closure = {'register': a:reg, 'yank': a:how}

    function closure.f() dict
        execute self.yank
        return getreg(self.register)
    endfunction

    return s:WithSavedRegister(a:reg, closure)
endfunction

function! s:ExtractSexpr(flags)
    if searchpairpos('(', '', ')', 'bW' . a:flags,
                \ 's:SynItem() !~ "clojureParen\\d"') != [0, 0]
        return s:Yank('l', 'normal "ly%')
    end
    return ""
endfunction

function! s:SendSexp() dict
    let sexp = s:ExtractSexpr(self.flags)
    if sexp != ""
        ruby <<
        sexp = VIM.evaluate("sexp")
        Gorilla.show_result(Gorilla.command(sexp))
.
    endif
endfunction

function! s:EvalInnerSexp()
    call s:WithSavedPosition({'f': function("s:SendSexp"), 'flags': ''})
endfunction

function! s:EvalTopSexp()
    call s:WithSavedPosition({'f': function("s:SendSexp"), 'flags': 'r'})
endfunction

" Lookup Documentation
function! s:LookupDocumentation(word)
    let w =
                \ a:word == ""
                \ ? input("Which word to look up? ")
                \ : a:word
    ruby <<
    Gorilla.show_result(Gorilla.doc(VIM.evaluate("w")))
.
endfunction

" Keyboard Mappings
if !exists("no_plugin_maps") && !exists("no_clojure_gorilla_maps")
    call s:MakePlug('n', 'EvalInnerSexp', 'EvalInnerSexp()')
    call s:MakePlug('n', 'EvalTopSexp', 'EvalTopSexp()')
    call s:MakePlug('n', 'DocForWord', 'LookupDocumentation(expand("<cword>"))')
    call s:MakePlug('n', 'LookupDoc', 'LookupDocumentation("")')

    call s:MapPlug('n', 'es', 'EvalInnerSexp')
    call s:MapPlug('n', 'et', 'EvalTopSexp')
    call s:MapPlug('n', 'lw', 'DocForWord')
    call s:MapPlug('n', 'ld', 'LookupDoc')
endif

" Epilog
let &cpo = s:save_cpo
