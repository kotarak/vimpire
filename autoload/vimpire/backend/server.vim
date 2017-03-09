" Part of a Vim filetype plugin for Clojure
" Language:     Clojure
" Maintainer:   Meikel Brandmeyer <mb@kotka.de>

let s:save_cpo = &cpo
set cpo&vim

let s:Location = expand("<sfile>:p:h:h:h:h") . "/"

if !exists("g:vimpire#backend#Support")
    let vimpire#backend#Support = []
endif
let vimpire#backend#Support = [
            \ s:Location . "server/vimpire/clojure/data/json.clj",
            \ s:Location . "server/vimpire/util.clj",
            \ s:Location . "server/vimpire/backend.clj",
            \ s:Location . "server/vimpire/repl.clj",
            \ s:Location . "server/vimpire/nails.clj"
            \ ] + vimpire#backend#Support

function! vimpire#backend#server#New(server)
    let this = {}

    let this.running = v:false
    let this.channel = ch_open(
                \ a:server,
                \ {"mode": "raw",
                \  "callback": {ch, msg ->
                \     vimpire#backend#server#PromoteChannel(this, ch, msg)
                \ }})

    let bootstrap = []
    for fname in g:vimpire#backend#Support
        let bootstrap += readfile(fname)
    endfor
    let bootstrap += ["(vimpire.nails/nail-server)\n"]
    let bootstrapCode = join(bootstrap, "\n")

    call ch_sendraw(this.channel, bootstrapCode)

    return this
endfunction

function! vimpire#backend#server#Stop(this)
    let a:this.running = v:false
    call ch_close(a:this.channel)
endfunction

function! vimpire#backend#server#PromoteChannel(this, channel, msg)
    if a:msg =~ "Nail server ready!"
        call ch_setoptions(a:channel, {"mode": "json", "callback": ""})
        let a:this.running = v:true
    endif
endfunction

function! vimpire#backend#server#Execute(this, ctx)
    if ch_status(a:this.channel) != "open" || !a:this.running
        return {
                    \ "value":  v:null,
                    \ "stdout": "",
                    \ "stderr": "Vimpire: Backend server not ready."
                    \ }
    endif

    if stridx(a:ctx.op, "/") == -1
        let a:ctx.op = "vimpire.nails/" . a:ctx.op
    endif

    return ch_evalexpr(a:this.channel, a:ctx)
endfunction

function! vimpire#backend#server#Instance()
    if exists("b:vimpire_server")
        return b:vimpire_server
    endif

    if exists("t:vimpire_server")
        return t:vimpire_server
    endif

    if exists("g:vimpire_server")
        return g:vimpire_server
    endif

    throw "Vimpire: No backend server found!"
endfunction

" Epilog
let &cpo = s:save_cpo
