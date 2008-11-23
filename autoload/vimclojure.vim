" Part of Vim filetype plugin for Clojure
" Language:     Clojure
" Maintainer:   Meikel Brandmeyer <mb@kotka.de>
" Last Change:  2008 Nov 23

function! vimclojure#AddCompletions(ns)
	let completions = split(globpath(&rtp, "ftplugin/clojure/completions-" . a:ns . ".txt"), '\n')
	if completions != []
		if exists("*fnameescape")
			let dictionary = fnameescape(completions[0])
		else
			let dictionary = escape(completions[0], '\ ')
		endif

		execute "setlocal complete+=k" . dictionary
	endif
endfunction
