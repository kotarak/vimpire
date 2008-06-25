" Vim indent file
" Language:      Clojure
" Maintainer:    Meikel Brandmeyer <mb@kotka.de>
" Last Change:   2008 Jun 21

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
	finish
endif
let b:did_indent = 1

let b:undo_indent = "setlocal ai< si< lisp< lw< et<"
setlocal autoindent lisp expandtab nosmartindent

" Defintions:
setlocal lispwords=def,defn,defn-,defmacro,defmethod,let,fn,binding

" Conditionals and Loops:
setlocal lispwords+=if,when,when-not,when-first,cond,loop,dotimes,for

" Blocks:
setlocal lispwords+=do,doto,try,catch,locking,with-out-str,with-open
setlocal lispwords+=dosync,with-local-vars,doseq
