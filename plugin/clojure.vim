" Vim filetype plugin file
" Language:     Clojure
" Maintainer:   Meikel Brandmeyer <mb@kotka.de>

" Only do this when not done yet for this buffer
if exists("clojure_loaded")
	finish
endif

let clojure_loaded = "2.2.0-SNAPSHOT"

let s:cpo_save = &cpo
set cpo&vim

command -nargs=0 ClojureRepl call vimclojure#StartRepl()

call vimclojure#MakePlug("n", "AddToLispWords", 'vimclojure#AddToLispWords(expand("<cword>"))')

call vimclojure#MakePlug("n", "DocLookupWord", 'vimclojure#DocLookup(expand("<cword>"))')
call vimclojure#MakePlug("n", "DocLookupInteractive", 'vimclojure#DocLookup(input("Symbol to look up: "))')
call vimclojure#MakePlug("n", "JavadocLookupWord", 'vimclojure#JavadocLookup(expand("<cword>"))')
call vimclojure#MakePlug("n", "JavadocLookupInteractive", 'vimclojure#JavadocLookup(input("Class to lookup: "))')
call vimclojure#MakePlug("n", "FindDoc", 'vimclojure#FindDoc())')

call vimclojure#MakePlug("n", "MetaLookupWord", 'vimclojure#MetaLookup(expand("<cword>"))')
call vimclojure#MakePlug("n", "MetaLookupInteractive", 'vimclojure#MetaLookup(input("Symbol to look up: "))')

call vimclojure#MakePlug("n", "SourceLookupWord", 'vimclojure#SourceLookup(expand("<cword>"))')
call vimclojure#MakePlug("n", "SourceLookupInteractive", 'vimclojure#SourceLookup(input("Symbol to look up: "))')

call vimclojure#MakePlug("n", "GotoSourceWord", 'vimclojure#GotoSource(expand("<cword>"))')
call vimclojure#MakePlug("n", "GotoSourceInteractive", 'vimclojure#GotoSource(input("Symbol to go to: "))')

call vimclojure#MakePlug("n", "RequireFile", 'vimclojure#RequireFile(0)')
call vimclojure#MakePlug("n", "RequireFileAll", 'vimclojure#RequireFile(1)')

call vimclojure#MakePlug("n", "RunTests", 'vimclojure#RunTests(0)')

call vimclojure#MakePlug("n", "MacroExpand",  'vimclojure#MacroExpand(0)')
call vimclojure#MakePlug("n", "MacroExpand1", 'vimclojure#MacroExpand(1)')

call vimclojure#MakePlug("n", "EvalFile",      'vimclojure#EvalFile()')
call vimclojure#MakePlug("n", "EvalLine",      'vimclojure#EvalLine()')
call vimclojure#MakePlug("v", "EvalBlock",     'vimclojure#EvalBlock()')
call vimclojure#MakePlug("n", "EvalToplevel",  'vimclojure#EvalToplevel()')
call vimclojure#MakePlug("n", "EvalParagraph", 'vimclojure#EvalParagraph()')

call vimclojure#MakePlug("n", "StartRepl", 'vimclojure#Repl.New("user")')
call vimclojure#MakePlug("n", "StartLocalRepl", 'vimclojure#Repl.New(b:vimclojure_namespace)')

inoremap <Plug>ClojureReplEnterHook <Esc>:call b:vimclojure_repl.enterHook()<CR>
inoremap <Plug>ClojureReplUpHistory <C-O>:call b:vimclojure_repl.upHistory()<CR>
inoremap <Plug>ClojureReplDownHistory <C-O>:call b:vimclojure_repl.downHistory()<CR>

nnoremap <Plug>ClojureCloseResultBuffer :call vimclojure#ResultBuffer.CloseBuffer()<CR>

let &cpo = s:cpo_save
