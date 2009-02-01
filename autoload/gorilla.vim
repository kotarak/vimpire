"-
" Copyright 2009 (c) Meikel Brandmeyer.
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

let s:save_cpo = &cpo
set cpo&vim

" Helpers
function! gorilla#SynItem()
	return synIDattr(synID(line("."), col("."), 0), "name")
endfunction

function! gorilla#ExtractSexpr(toplevel)
	let closure = { "flag" : (a:toplevel ? "r" : "") }

	function closure.f() dict
		if searchpairpos('(', '', ')', 'bW' . self.flag,
					\ 'gorilla#SynItem() !~ "clojureParen\\d"') != [0, 0]
			return vimclojure#Yank('l', 'normal "ly%')
		end
		return ""
	endfunction

	return vimclojure#WithSavedPosition(closure)
endfunction

" Key mappings and Plugs
function! gorilla#MakePlug(mode, plug, f)
	execute a:mode . "noremap <Plug>ClojureChimp" . a:plug
				\ . " :call " . a:f . "<CR>"
endfunction

function! gorilla#MapPlug(mode, keys, plug)
	if !hasmapto("<Plug>ClojureChimp" . a:plug)
		execute a:mode . "map <buffer> <unique> <silent> <LocalLeader>" . a:keys
					\ . " <Plug>ClojureChimp" . a:plug
	endif
endfunction

" A Buffer...
let gorilla#Buffer = {}

function! gorilla#Buffer.goHere() dict
	execute "buffer! " . self._buffer
endfunction

function! gorilla#Buffer.resize() dict
	call self.goHere()
	let size = line("$")
	if size < 3
		let size = 3
	endif
	execute "resize " . size
endfunction

function! gorilla#Buffer.showText(text) dict
	call self.goHere()
	call append(line("$"), split(a:text, '\n'))
	call self.resize()
endfunction

" The transient buffer, used to display results.
let gorilla#TransientBuffer = copy(gorilla#Buffer)

function! gorilla#TransientBuffer.New() dict
	let instance = copy(self)

	new
	let instance._buffer = bufnr("%")

	setlocal noswapfile
	setlocal buftype=nofile
	setlocal bufhidden=delete

	nnoremap <buffer> <silent> q :hide<CR>

	call append(0, "; Press q to close this buffer!")

	return instance
endfunction

" Nails
if !exists("gorilla#NailgunClient")
	let gorilla#NailgunClient = "ng"
endif

function! gorilla#ExecuteNail(nail, ...)
	let cmd = join([g:gorilla#NailgunClient,
				\ "de.kotka.gorilla.nails." . a:nail] + a:000, " ")
	let result = system(cmd)
	if v:shell_error
		throw "Couldn't execute Nail! " . cmd
	endif
	return substitute(result, '\n$', '', '')
endfunction

function! gorilla#FilterNail(nail, rngStart, rngEnd, ...)
	let cmd = join([a:rngStart . "," . a:rngEnd . "!",
				\ g:gorilla#NailgunClient,
				\ "de.kotka.gorilla.nails." . a:nail] + a:000, " ")

	silent execute cmd
endfunction

function! gorilla#DocLookup(word)
	let docs = gorilla#ExecuteNail("DocLookup",
				\ "--namespace", b:gorilla_namespace,
				\ "--", a:word)
	let transientBuffer = g:gorilla#TransientBuffer.New()
	call transientBuffer.showText(docs)
endfunction

let s:DefaultJavadocPaths = {
			\ "java" : "http://java.sun.com/javase/6/docs/api/",
			\ "org/apache/commons/beanutils" : "http://commons.apache.org/beanutils/api/",
			\ "org/apache/commons/chain" : "http://commons.apache.org/chain/api-release/",
			\ "org/apache/commons/cli" : "http://commons.apache.org/cli/api-release/",
			\ "org/apache/commons/codec" : "http://commons.apache.org/codec/api-release/",
			\ "org/apache/commons/collections" : "http://commons.apache.org/collections/api-release/",
			\ "org/apache/commons/logging" : "http://commons.apache.org/logging/apidocs/",
			\ "org/apache/commons/mail" : "http://commons.apache.org/email/api-release/",
			\ "org/apache/commons/io" : "http://commons.apache.org/io/api-release/"
			\ }

if !exists("gorilla#JavadocPathMap")
	let gorilla#JavadocPathMap = {}
endif

for k in keys(s:DefaultJavadocPaths)
	if !has_key(gorilla#JavadocPathMap, k)
		let gorilla#JavadocPathMap[k] = s:DefaultJavadocPaths[k]
	endif
endfor

if !exists("gorilla#Browser")
	if has("win32") || has("win64")
		let gorilla#Browser = "start"
	elseif has("mac")
		let gorilla#Browser = "open"
	else
		let gorilla#Browser = "firefox -new-window"
	endif
endif

function! gorilla#JavadocLookup(word)
	let path = gorilla#ExecuteNail("JavadocPath",
				\ "--namespace", b:gorilla_namespace,
				\ "--", a:word)

	let match = ""
	for pattern in keys(g:gorilla#JavadocPathMap)
		if path =~ "^" . pattern && len(match) < len(pattern)
			let match = pattern
		endif
	endfor

	if match == ""
		throw "No matching Javadoc URL found for " . path
	endif

	let url = g:gorilla#JavadocPathMap[match] . path
	call system(join([g:gorilla#Browser, url], " "))
endfunction

" Evaluators
function! gorilla#MacroExpand(firstOnly)
	let sexp = gorilla#ExtractSexpr(0)
	let cmd = ["MacroExpand",
				\ "--expression", shellescape(sexp),
				\ "--namespace", b:gorilla_namespace]
	let cmd = a:firstOnly ? cmd + ["--first"] : cmd

	let expansion = call(function("gorilla#ExecuteNail"), cmd)

	let resultBuffer = g:gorilla#TransientBuffer.New()
	call resultBuffer.showText(expansion)
endfunction

" Epilog
let &cpo = s:save_cpo