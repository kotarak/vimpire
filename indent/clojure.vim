" Vim indent file
" Language:      Clojure
" Maintainer:    Meikel Brandmeyer <mb@kotka.de>
" Last Change:   2008 Aug 16

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
	finish
endif
let b:did_indent = 1

let s:save_cpo = &cpo
set cpo&vim

let b:undo_indent = "setlocal ai< si< lw< et< sts< sw< inde<"

setlocal autoindent expandtab nosmartindent

setlocal softtabstop=2
setlocal shiftwidth=2

function! s:MatchPairs(open, close, stopat)
	let c = getpos(".")

	" Stop only on vector and map [ resp. {. Ignore the ones in strings and
	" comments.
	let nc = searchpairpos(a:open, '', a:close, 'bW',
				\ 'synIDattr(synID(line("."), col("."), 0), "name") != "Delimiter"',
				\ a:stopat)

	call setpos(".", c)
	return nc
endfunction

function! GetClojureIndent()
	" Find the next enclosing [ or {. We can limit the second search
	" to the line, where the [ was found. If no [ was there this is
	" zero and we search for an enclosing {.
	let bracket = s:MatchPairs('\[', '\]', 0)
	let curly = s:MatchPairs('{', '}', bracket[0])

	" In case the curly brace is on a line later then the [ or - in
	" case they are on the same line - in a higher column, we take the
	" curly indent.
	if curly[0] > bracket[0] || curly[1] > bracket[1]
		return curly[1]
	endif

	" If the curly was not chosen, we take the bracket indent - if
	" there was one.
	if bracket[1] > 0
		return bracket[1]
	endif

	" Fallback to normal lispindent.
	return lispindent(".")
endfunction
setlocal indentexpr=GetClojureIndent()

" Defintions:
setlocal lispwords=def,defn,defn-,defmacro,defmethod,let,fn,binding,proxy

" Conditionals and Loops:
setlocal lispwords+=if,when,when-not,when-let,when-first,cond,loop,dotimes,for

" Blocks:
setlocal lispwords+=do,doto,try,catch,locking,with-out-str,with-open
setlocal lispwords+=dosync,with-local-vars,doseq

let &cpo = s:save_cpo
