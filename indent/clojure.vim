" Vim indent file
" Language:      Clojure
" Maintainer:    Meikel Brandmeyer <mb@kotka.de>
" Last Change:   2008 Aug 24
" URL:           http://kotka.de/projects/clojure/vimclojure.html

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
	finish
endif
let b:did_indent = 1

let s:save_cpo = &cpo
set cpo&vim

let b:undo_indent = "setlocal ai< si< lw< et< sts< sw< inde< indk<"

setlocal autoindent expandtab nosmartindent

setlocal softtabstop=2
setlocal shiftwidth=2

setlocal indentkeys=!,o,O

if exists("*searchpairpos")

function! s:Yank(how)
	let save_l = @l
	execute a:how
	let text = @l
	let @l = save_l
	return text
endfunction

function! s:SynItem()
	return synIDattr(synID(line("."), col("."), 0), "name")
endfunction

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

function! s:CheckForString(pos)
	" We have to apply some heuristics here to figure out, whether to use
	" normal lisp indenting or not.
	"
	" Check whether there is the last character of the previous line is
	" highlighted as a string. If so, we check whether it's a ". In this
	" case we have to check also the previous character. The " might be the
	" closing one.
	let nb = prevnonblank(a:pos[1] - 1)

	execute ":" . nb
	normal $
	if s:SynItem() != "clojureString"
		call setpos(".", a:pos)
		return -1
	endif

	if s:Yank('normal "lyl') == '"'
		normal h
		if s:Yank('normal "lyl') != '\' && s:SynItem() == "clojureString"
			call setpos(".", a:pos)
			return -1
		endif
	endif

	let p = getpos(".")
	silent! normal F"

	let p2 = getpos(".")
	call setpos(".", a:pos)
	if p != p2
		return p2[2] - 1
	else
		return indent(".")
	endif
endfunction

function! GetClojureIndent()
	let c = getpos(".")

	let i = s:CheckForString(c)
	if i > -1
		return i
	endif

	normal ^

	" Find the next enclosing [ or {. We can limit the second search
	" to the line, where the [ was found. If no [ was there this is
	" zero and we search for an enclosing {.
	let paren = s:MatchPairs('(', ')', 0)
	let bracket = s:MatchPairs('\[', '\]', paren[0])
	let curly = s:MatchPairs('{', '}', bracket[0])

	" In case the curly brace is on a line later then the [ or - in
	" case they are on the same line - in a higher column, we take the
	" curly indent.
	if curly[0] > bracket[0] || curly[1] > bracket[1]
		if curly[0] > paren[0] || curly[1] > paren[1]
			return curly[1]
		endif
	endif

	" If the curly was not chosen, we take the bracket indent - if
	" there was one.
	if bracket[0] > paren[0] || bracket[1] > paren[1]
		return bracket[1]
	endif

	" Fallback to normal lispindent.
	let ind = lispindent(".")

	call setpos(".", c)

	return ind
endfunction

setlocal indentexpr=GetClojureIndent()

else

	" In case we have searchpairpos not available we fall back to
	" normal lisp indenting.
	setlocal indentexpr=
	setlocal lisp
	let b:undo_indent = b:undo_indent . " lisp<"

endif

" Defintions:
setlocal lispwords=def,defn,defn-,defmacro,defmethod,let,fn,binding,proxy

" Conditionals and Loops:
setlocal lispwords+=if,if-let,when,when-not,when-let,when-first
setlocal lispwords+=cond,loop,dotimes,for

" Blocks:
setlocal lispwords+=do,doto,try,catch,locking,with-in-str,with-out-str,with-open
setlocal lispwords+=dosync,with-local-vars,doseq

let &cpo = s:save_cpo
