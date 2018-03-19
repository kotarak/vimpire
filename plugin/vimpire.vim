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

" Only do this when not done yet
if exists("vimpire_loaded")
    finish
endif

let vimpire_loaded = "3.0.0"

" Prolog
let s:cpo_save = &cpo
set cpo&vim

let g:vimpire#Nil = []

command! -nargs=? VimpireRepl call vimpire#repl#StartRepl(vimpire#connection#ForBuffer(), <f-args>)
command! -nargs=* VimpireBite call vimpire#connection#RegisterPrefix(getcwd(), <f-args>)

call vimpire#ui#MakeCommandPlug("n", "doc_lookup_word", "vimpire#backend#DocLookup", "expand(\"<cword>\")")
call vimpire#ui#MakeCommandPlug("n", "doc_lookup_interactive", "vimpire#backend#DocLookup", "input(\"Symbol to look up: \")")
call vimpire#ui#MakeCommandPlug("n", "javadoc_look_word", "vimpire#backend#JavadocLookup", "expand(\"<cword>\")")
call vimpire#ui#MakeCommandPlug("n", "javadoc_look_interactive", "vimpire#backend#JavadocLookup", "input(\"Class to lookup: \")")
call vimpire#ui#MakeCommandPlug("n", "find_doc", "vimpire#backend#FindDoc", "")

call vimpire#ui#MakeCommandPlug("n", "source_lookup_word", "vimpire#backend#SourceLookup", "expand(\"<cword>\")")
call vimpire#ui#MakeCommandPlug("n", "source_lookup_interactive", "vimpire#backend#SourceLookup", "input(\"Symbol to look up: \")")

call vimpire#ui#MakeCommandPlug("n", "goto_source_word", "vimpire#backend#GotoSource", "expand(\"<cword>\")")
call vimpire#ui#MakeCommandPlug("n", "goto_source_interactive", "vimpire#backend#GotoSource", "input(\"Symbol to go to: \")")

call vimpire#ui#MakeCommandPlug("n", "require_file", "vimpire#backend#RequireFile", "0")
call vimpire#ui#MakeCommandPlug("n", "require_file_all", "vimpire#backend#RequireFile", "1")

call vimpire#ui#MakeCommandPlug("n", "run_tests", "vimpire#backend#RunTests", "0")

" Operators
nnoremap <Plug>(vimpire_eval) :set operatorfunc=vimpire#backend#EvalOperator<CR>g@
nnoremap <Plug>(vimpire_macro_expand) :set operatorfunc=vimpire#backend#MacroExpand<CR>g@
nnoremap <Plug>(vimpire_macro_expand1) :set operatorfunc=vimpire#backend#MacroExpand1<CR>g@

inoremap <Plug>(vimpire_repl_enter_hook) <Esc>:call vimpire#repl#EnterHook(b:vimpire_repl)<CR>
inoremap <Plug>(vimpire_repl_evaluate) <Esc>G$:call vimpire#repl#EnterHook(b:vimpire_repl)<CR>
nnoremap <Plug>(vimpire_repl_hat_hook) :call vimpire#repl#HatHook(b:vimpire_repl)<CR>
inoremap <Plug>(vimpire_repl_up_history) <C-O>:call vimpire#repl#UpHistory(b:vimpire_repl)<CR>
inoremap <Plug>(vimpire_repl_down_history) <C-O>:call vimpire#repl#DownHistory(b:vimpire_repl)<CR>

nnoremap <Plug>(vimpire_close_result_buffer) :call vimpire#window#resultwindow#CloseWindow()<CR>

let s:Here = expand("<sfile>:p:h:h")

call vimpire#venom#Register(
            \ vimpire#sunscreen#Apply(
            \   "vimpire",
            \   [s:Here . "/server/"],
            \   ["vimpire.util"],
            \   ["vimpire.nails", "vimpire.backend", "vimpire.pprint"],
            \   s:Here . "/actions.clj"))

call vimpire#venom#Register(
            \ vimpire#sunscreen#Apply(
            \   "vimpire-complete",
            \   [s:Here . "/venom/complete/src/"],
            \   ["vimpire.complete"],
            \   ["complete.core"],
            \   s:Here . "/venom/complete/actions.clj"))

" Epilog
let &cpo = s:cpo_save
