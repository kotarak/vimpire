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

function! s:WithSaved(closure)
	let v = a:closure.get(a:closure.tosafe)
	let r = a:closure.f()
	call a:closure.set(a:closure.tosafe, v)
	return r
endfunction

function! s:WithSavedRegister(closure)
	let a:closure['get'] = function("getreg")
	let a:closure['set'] = function("setreg")
	return s:WithSaved(a:closure)
endfunction

function! s:Yank(r, how)
	let closure = {'tosafe': a:r, 'yank': a:how}

	function closure.f() dict
		execute self.yank
		return getreg(self.tosafe)
	endfunction

	return s:WithSavedRegister(closure)
endfunction

function! s:SynItem()
	return synIDattr(synID(line("."), col("."), 0), "name")
endfunction

function! s:WithSavedPosition(closure)
	let a:closure['tosafe'] = "."
	let a:closure['get'] = function("getpos")
	let a:closure['set'] = function("setpos")
	return s:WithSaved(a:closure)
endfunction

function! s:MatchPairs(open, close, stopat)
	let closure = { 'open': a:open, 'close': a:close, 'stopat': a:stopat }

	function closure.f() dict
		" Stop only on vector and map [ resp. {. Ignore the ones in strings and
		" comments.
		return searchpairpos(self.open, '', self.close, 'bW',
				\ 'synIDattr(synID(line("."), col("."), 0), "name") != "Delimiter"',
				\ self.stopat)
	endfunction

	return s:WithSavedPosition(closure)
endfunction

function! s:CheckForString()
	let closure = {}

	function closure.f() dict
		" Check whether there is the last character of the previous line is
		" highlighted as a string. If so, we check whether it's a ". In this
		" case we have to check also the previous character. The " might be the
		" closing one. In case the we are still in the string, we search for the
		" opening ". If this is not found we take the indent of the line.
		let nb = prevnonblank(v:lnum - 1)

		if nb == 0
			return 0
		endif

		call cursor(nb, col([nb, "$"]) - 1)
		if s:SynItem() != "clojureString"
			return -1
		endif

		if s:Yank('l', 'normal! "lyl') == '"'
			call cursor(0, col("$") - 2)
			if s:Yank('l', 'normal "lyl') != '\\' && s:SynItem() == "clojureString"
				return -1
			endif
			call cursor(0, col("$") - 1)
		endif

		let p = searchpos('\(^\|[^\\]\)\zs"', 'bW')

		if p != [0, 0]
			return p[1] - 1
		endif

		return indent(".")
	endfunction

	return s:WithSavedPosition(closure)
endfunction

function! GetClojureIndent()
	" Get rid of special case.
	if line(".") == 1
		return 0
	endif

	" We have to apply some heuristics here to figure out, whether to use
	" normal lisp indenting or not.
	let i = s:CheckForString()
	if i > -1
		return i
	endif

	let closure = {}
	function closure.f() dict
		call cursor(0, 1)

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
		return lispindent(".")
	endfunction

	return s:WithSavedPosition(closure)
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
