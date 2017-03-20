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
                \     vimpire#backend#server#Banner(this, ch, msg)
                \ }})

    return this
endfunction

function! vimpire#backend#server#Banner(this, channel, msg)
    if a:msg =~ '^user=>'
        call ch_setoptions(a:channel, {"callback": {ch, msg ->
                    \   vimpire#backend#server#Bootstrap(a:this, ch, msg)
                    \ }})

        let bootstrapCode = join(
                    \ readfile(s:Location . "/server/vimpire/bootstrap.clj"),
                    \ "\n") . "\n(needs-bootstrap?)\n"
        call ch_sendraw(a:channel, bootstrapCode)
    endif
endfunction

function! vimpire#backend#server#Bootstrap(this, channel, msg)
    if a:msg =~ 'Vimpire needs bootstrap!'
        let bootstrap = []
        for fname in g:vimpire#backend#Support
            call add(bootstrap,
                        \ "(vimpire.bootstrap/set-source \"" . fname . "\")")
            call extend(bootstrap, readfile(fname))
            call add(bootstrap,
                        \ "(vimpire.bootstrap/revert-source)")
        endfor
        call add(bootstrap, "\"Vimpire is ready!\"\n")

        call ch_sendraw(a:channel, join(bootstrap, "\n"))
    elseif a:msg =~ 'Vimpire is ready!'
        call ch_setoptions(a:channel, {"callback": {ch, msg ->
                    \   vimpire#backend#server#PromoteChannel(a:this, ch, msg)
                    \ }})

        call ch_sendraw(a:channel, "(vimpire.nails/nail-server)\n")
    endif
endfunction

function! vimpire#backend#server#PromoteChannel(this, channel, msg)
    if a:msg =~ 'Nail server ready!'
        call ch_setoptions(a:channel, {"mode": "json", "callback": ""})
        let a:this.running = v:true
    endif
endfunction

function! vimpire#backend#server#Stop(this)
    let a:this.running = v:false
    call ch_close(a:this.channel)
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
