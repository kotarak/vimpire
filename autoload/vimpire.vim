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

let vimpire#Location = expand("<sfile>:p:h:h") . "/"

if !exists("g:vimpire#BackendSupport")
    let vimpire#BackendSupport = []
endif
let vimpire#BackendSupport = [
            \ vimpire#Location . "server/vimpire/clojure/data/json.clj",
            \ vimpire#Location . "server/vimpire/util.clj",
            \ vimpire#Location . "server/vimpire/backend.clj",
            \ vimpire#Location . "server/vimpire/repl.clj",
            \ vimpire#Location . "server/vimpire/nails.clj"
            \ ] + vimpire#BackendSupport

let vimpire#BackendServer = copy(vimpire#Object)
let vimpire#BackendServer["__superObjectInit"]  = vimpire#BackendServer["Init"]

function! vimpire#BackendServer.Init(server, port) dict
    call self.__superObjectInit()
    let self.running = v:false
    let self.channel = ch_open(a:server . ":" . a:port,
                \ {"mode": "raw",
                \  "callback": {ch, msg -> self.promoteChannel(msg)}})

    let bootstrap = []
    for fname in g:vimpire#BackendSupport
        let bootstrap += readfile(fname)
    endfor
    let bootstrap += ["(vimpire.nails/nail-server)\n"]
    let bootstrapCode = join(bootstrap, "\n")

    call ch_sendraw(self.channel, bootstrapCode)
endfunction

function! vimpire#BackendServer.stop() dict
    call ch_close(self.channel)
endfunction

function! vimpire#BackendServer.promoteChannel(msg) dict
    if a:msg =~ "Nail server ready!"
        call ch_setoptions(self.channel, {"mode": "json", "callback": ""})
        let self.running = v:true
    endif
endfunction

" Epilog
let &cpo = s:save_cpo
