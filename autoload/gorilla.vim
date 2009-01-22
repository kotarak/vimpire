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

" The transient buffer, used to display results.
let gorilla#TransientBuffer = {}

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

function! gorilla#TransientBuffer.goHere() dict
	execute "buffer! " . self._buffer
endfunction

function! gorilla#TransientBuffer.resize() dict
	call self.goHere()
	let size = line("$")
	if size < 3
		let size = 3
	endif
	execute "resize " . size
endfunction

function! gorilla#TransientBuffer.showText(text) dict
	call self.goHere()
	call append(line("$"), split(a:text, '\n'))
	call self.resize()
endfunction

let &cpo = s:save_cpo
