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

let vimpire_loaded = "3.0.0-SNAPSHOT"

let s:cpo_save = &cpo
set cpo&vim

command! -nargs=? VimpireRepl call vimpire#repl#StartRepl(<f-args>)
command! -nargs=* VimpireBite call vimpire#backend#Connect(<f-args>)

call vimpire#ui#MakeCommandPlug("n", "DocLookupWord", "vimpire#backend#DocLookup", "expand(\"<cword>\")")
call vimpire#ui#MakeCommandPlug("n", "DocLookupInteractive", "vimpire#backend#DocLookup", "input(\"Symbol to look up: \")")
call vimpire#ui#MakeCommandPlug("n", "JavadocLookupWord", "vimpire#backend#JavadocLookup", "expand(\"<cword>\")")
call vimpire#ui#MakeCommandPlug("n", "JavadocLookupInteractive", "vimpire#backend#JavadocLookup", "input(\"Class to lookup: \")")
call vimpire#ui#MakeCommandPlug("n", "FindDoc", "vimpire#backend#FindDoc", "")

call vimpire#ui#MakeCommandPlug("n", "MetaLookupWord", "vimpire#backend#MetaLookup", "expand(\"<cword>\")")
call vimpire#ui#MakeCommandPlug("n", "MetaLookupInteractive", "vimpire#backend#MetaLookup", "input(\"Symbol to look up: \")")

call vimpire#ui#MakeCommandPlug("n", "SourceLookupWord", "vimpire#backend#SourceLookup", "expand(\"<cword>\")")
call vimpire#ui#MakeCommandPlug("n", "SourceLookupInteractive", "vimpire#backend#SourceLookup", "input(\"Symbol to look up: \")")

call vimpire#ui#MakeCommandPlug("n", "GotoSourceWord", "vimpire#backend#GotoSource", "expand(\"<cword>\")")
call vimpire#ui#MakeCommandPlug("n", "GotoSourceInteractive", "vimpire#backend#GotoSource", "input(\"Symbol to go to: \")")

call vimpire#ui#MakeCommandPlug("n", "RequireFile", "vimpire#backend#RequireFile", "0")
call vimpire#ui#MakeCommandPlug("n", "RequireFileAll", "vimpire#backend#RequireFile", "1")

call vimpire#ui#MakeCommandPlug("n", "RunTests", "vimpire#backend#RunTests", "0")

call vimpire#ui#MakeCommandPlug("n", "MacroExpand",  "vimpire#backend#MacroExpand", "0")
call vimpire#ui#MakeCommandPlug("n", "MacroExpand1", "vimpire#backend#MacroExpand", "1")

call vimpire#ui#MakeCommandPlug("n", "EvalFile",      "vimpire#backend#EvalFile", "")
call vimpire#ui#MakeCommandPlug("n", "EvalLine",      "vimpire#backend#EvalLine", "")
call vimpire#ui#MakeCommandPlug("v", "EvalBlock",     "vimpire#backend#EvalBlock", "")
call vimpire#ui#MakeCommandPlug("n", "EvalToplevel",  "vimpire#backend#EvalToplevel", "")
call vimpire#ui#MakeCommandPlug("n", "EvalParagraph", "vimpire#backend#EvalParagraph", "")

inoremap <Plug>VimpireReplEnterHook. <Esc>:call vimpire#repl#EnterHook(b:vimpire_repl)<CR>
inoremap <Plug>VimpireReplEvaluate. <Esc>G$:call vimpire#repl#EnterHook(b:vimpire_repl)<CR>
nnoremap <Plug>VimpireReplHatHook. :call vimpire#repl#HatHook(b:vimpire_repl)<CR>
inoremap <Plug>VimpireReplUpHistory. <C-O>:call vimpire#repl#UpHistory(b:vimpire_repl)<CR>
inoremap <Plug>VimpireReplDownHistory. <C-O>:call vimpire#repl#DownHistory(b:vimpire_repl)<CR>

nnoremap <Plug>VimpireCloseResultBuffer. :call vimpire#window#resultwindow#CloseWindow()<CR>

let &cpo = s:cpo_save
