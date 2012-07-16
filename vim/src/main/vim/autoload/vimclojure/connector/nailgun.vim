" Part of Vim filetype plugin for Clojure
" Language:     Clojure
" Maintainer:   Meikel Brandmeyer <mb@kotka.de>

let s:save_cpo = &cpo
set cpo&vim

if !exists("g:vimclojure#connector#nailgun#Client")
	let vimclojure#connector#nailgun#Client = "ng"
endif

if !exists("g:vimclojure#connector#nailgun#Server")
	let vimclojure#connector#nailgun#Server = "127.0.0.1"
endif

if !exists("g:vimclojure#connector#nailgun#Port")
	let vimclojure#connector#nailgun#Port = "2113"
endif

function! vimclojure#connector#nailgun#Execute(nail, input, ...)
	if type(a:input) == type("")
		let input = split(a:input, '\n', 1)
	else
		let input = a:input
	endif

	let inputfile = tempname()
	try
		call writefile(input, inputfile)

		let cmdline = vimclojure#util#ShellEscapeArguments(
					\ [g:vimclojure#connector#nailgun#Client,
					\   '--nailgun-server',
					\   g:vimclojure#connector#nailgun#Server,
					\   '--nailgun-port',
					\   g:vimclojure#connector#nailgun#Port,
					\   'vimclojure.Nail', a:nail]
					\ + a:000)
		let cmd = join(cmdline, " ") . " <" . inputfile
		" Add hardcore quoting for Windows
		if has("win32") || has("win64")
			let cmd = '"' . cmd . '"'
		endif

		let output = system(cmd)

		if v:shell_error
			throw "Error executing Nail! (" . v:shell_error . ")\n" . output
		endif
	finally
		call delete(inputfile)
	endtry

	execute "let result = " . substitute(output, '\n$', '', '')
	return result
endfunction

function! vimclojure#connector#nailgun#Connector()
	return {
				\ 'execute': function("vimclojure#connector#nailgun#Execute")
				\ }
endfunction

let &cpo = s:save_cpo
