" Part of Vim filetype plugin for Clojure
" Language:     Clojure
" Maintainer:   Meikel Brandmeyer <mb@kotka.de>

" Prolog
let s:save_cpo = &cpo
set cpo&vim

function! vimclojure#bencode#ReadString(input, pos)
	let cntS = ""
	let pos = a:pos

	while 1
		let c = a:input[pos]
		let pos += 1
		if c == ":"
			break
		endif

		let cntS .= c
	endwhile
	let cnt = eval(cntS)
	let s = strpart(a:input, pos, cnt)

	return [ [s], pos + strchars(s) ]
endfunction

function! vimclojure#bencode#ReadNumber(input, pos)
	let numberS = ""
	let pos = a:pos

	while 1
		let c = a:input[pos]
		let pos += 1
		if c == "e"
			break
		endif

		let numberS .= c
	endwhile

	return [ [eval(numberS)], pos ]
endfunction

let vimclojure#bencode#Nil = []

function! vimclojure#bencode#ReadList(input, pos)
	let l = []
	let pos = a:pos

	while 1
		let [ elt, pos ]  = vimclojure#bencode#ReadToken(a:input, pos)
		if elt is g:vimclojure#bencode#Nil
			break
		endif

		call add(l, elt[0])
	endwhile

	return [ [l], pos ]
endfunction

function! vimclojure#bencode#ReadMap(input, pos)
	let m = {}
	let pos = a:pos

	while 1
		let [ k, pos ] = vimclojure#bencode#ReadToken(a:input, pos)

		if k is g:vimclojure#bencode#Nil
			break
		endif

		let [ v, pos ] = vimclojure#bencode#ReadToken(a:input, pos)
		let m[k[0]] = v[0]
	endwhile

	return [ [m], pos ]
endfunction

function! vimclojure#bencode#ReadToken(input, pos)
	let c = a:input[a:pos]

	if c == "i"
		return vimclojure#bencode#ReadNumber(a:input, a:pos + 1)
	elseif c == "l"
		return vimclojure#bencode#ReadList(a:input, a:pos + 1)
	elseif c == "d"
		return vimclojure#bencode#ReadMap(a:input, a:pos + 1)
	elseif c == "e"
		return [ g:vimclojure#bencode#Nil, a:pos + 1 ]
	else
		return vimclojure#bencode#ReadString(a:input, a:pos)
	endif
endfunction

function! vimclojure#bencode#ReadBencode(input)
	return vimclojure#bencode#ReadToken(a:input, 0)[0][0]
endfunction

" Epilog
let &cpo = s:save_cpo
