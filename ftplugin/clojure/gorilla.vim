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

if exists("b:gorilla_loaded")
	finish
endif
let b:gorilla_loaded = "2.0.0"

let s:save_cpo = &cpo
set cpo&vim

call gorilla#MakePlug("n", "DocLookupWord", 'gorilla#DocLookup(expand("<cword>"))')
call gorilla#MakePlug("n", "JavadocLookupWord", 'gorilla#JavadocLookup(expand("<cword>"))')

call gorilla#MapPlug("n", "lw", "DocLookupWord")
call gorilla#MapPlug("n", "jw", "JavadocLookupWord")

call gorilla#MakePlug("n", "MacroExpand",  'gorilla#MacroExpand(0)')
call gorilla#MakePlug("n", "MacroExpand1", 'gorilla#MacroExpand(1)')

call gorilla#MapPlug("n", "me", "MacroExpand")
call gorilla#MapPlug("n", "m1", "MacroExpand1")

call gorilla#MakePlug("n", "StartRepl", 'gorilla#Repl.New()')
call gorilla#MapPlug("n", "sr", "StartRepl")

" Get the namespace of the buffer.
let s:here = bufnr("%")
let s:content = getbufline(s:here, 1, line("$"))
let s:tmpBuf = gorilla#TransientBuffer.New()

call s:tmpBuf.showText(join(s:content, "\n"))
let s:endLine = line("$")

call gorilla#FilterNail("NamespaceOfFile", 1, s:endLine)
let s:ns = getline(line("$"))

call s:tmpBuf.close()
let b:gorilla_namespace = s:ns

unlet s:content s:tmpBuf s:endLine s:ns

let &cpo = s:save_cpo
