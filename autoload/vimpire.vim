" Part of a Vim filetype plugin for Clojure
" Language:     Clojure
" Maintainer:   Meikel Brandmeyer <mb@kotka.de>

let s:save_cpo = &cpo
set cpo&vim

let vimpire#Object = {}

function! vimpire#Object.New(...) dict
    let instance = copy(self)
    let instance.prototype = self

    call call(instance.Init, a:000, instance)

    return instance
endfunction

function! vimpire#Object.Init() dict
endfunction

function! vimpire#Object.isA(type) dict
    return self.prototype is a:type
endfunction





" Epilog
let &cpo = s:save_cpo
