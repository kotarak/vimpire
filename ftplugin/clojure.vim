" Vim filetype plugin file
" Language:     Clojure
" Maintainer:   Meikel Brandmeyer <mb@kotka.de>
" Last Change:  2008 Jun 21

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
	finish
endif

let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setlocal fo< com< cms<"

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal formatoptions-=t formatoptions+=croql
setlocal commentstring=;%s

" Set 'comments' to format dashed lists in comments.
setlocal comments=sO:;\ -,mO:;\ \ ,n:;

" When the matchit plugin is loaded, this makes the % command skip parens and
" braces in comments.
let b:match_words = &matchpairs
let b:match_skip = 's:comment\|string\|character'

" Win32 can filter files in the browse dialog
if has("gui_win32") && !exists("b:browsefilter")
	let b:browsefilter = "Clojure Source Files (*.clj)\t*.clj\n" .
				\ "Jave Source Files (*.java)\t*.java\n" .
				\ "All Files (*.*)\t*.*\n"
endif

let &cpo = s:cpo_save
unlet s:cpo_save
