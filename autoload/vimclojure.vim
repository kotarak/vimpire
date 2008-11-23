" Part of Vim filetype plugin for Clojure
" Language:     Clojure
" Maintainer:   Meikel Brandmeyer <mb@kotka.de>
" Last Change:  2008 Nov 23

function! vimclojure#AddPathToOption(path, option)
		if exists("*fnameescape")
			let path = fnameescape(a:path)
		else
			let path = escape(a:path, '\ ')
		endif

		execute "setlocal " . a:option . "+=" . path
endfunction

function! vimclojure#AddCompletions(ns)
	let completions = split(globpath(&rtp, "ftplugin/clojure/completions-" . a:ns . ".txt"), '\n')
	if completions != []
		call vimclojure#AddPathToOption('k' . completions[0], 'complete')
	endif
endfunction
