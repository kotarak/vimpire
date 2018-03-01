"-
" Copyright 2009-2017 © Meikel Brandmeyer.
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

" Prolog
let s:save_cpo = &cpo
set cpo&vim

let s:Location = expand("<sfile>:p:h:h:h") . "/"

let s:Registry = {}

function! vimpire#connection#RegisterPrefix(prefix, server)
    if !has_key(s:Registry, a:prefix)
        let s:Registry[a:prefix] = { "server": a:server }
    endif
endfunction

function! vimpire#connection#ForPrefix(prefix)
    if !has_key(s:Registry, a:prefix)
        throw "Vimpire: prefix '" . a:prefix . "' unknown."
    endif

    if !has_key(s:Registry[a:prefix], "conn")
        let s:Registry[a:prefix].conn =
                    \ vimpire#connection#New(s:Registry[a:prefix].server,
                    \   v:none)
    endif

    return s:Registry[a:prefix].conn
endfunction

function! vimpire#connection#New(server, sibling)
    let this = {}

    let this.running = v:false
    let this.server  = a:server
    let this.sibling = a:sibling
    let this.queue   = ""
    let this.channel = ch_open(
                \ a:server,
                \ { "mode": "raw",
                \   "callback" : { ch, msg ->
                \      vimpire#connection#UpgradeRepl(this, msg)
                \ }})

    let this.handlers = {
                \ ":out":  { t, r -> append(line("$"), "out=>" . r[1]) },
                \ ":eval": { t, r -> append(line("$"), "eval=>" . r[1]) }
                \ }

    return this
endfunction

function! vimpire#connection#UpgradeRepl(this, msg)
    let a:this.queue .= a:msg

    if a:this.queue =~ '\[:unrepl.upgrade/failed\]'
        call ch_close(a:this.channel)
        throw "Vimpire: Couldn't upgrade to unrepl."
    elseif a:this.queue =~ 'user=> '
        let a:this.queue = ""

        let starter = ""
        if type(a:this.sibling) != v:t_none
            let starter = vimpire#edn#Write(
                        \ vimpire#connection#ExpandAction(
                        \  a:this.sibling.actions[":start-aux"],
                        \  {}))
        else
            let starter = join(readfile(s:Location . "server/unrepl/blob.clj"),
                        \ "\n")
        endif

        call ch_sendraw(a:this.channel, starter . "\n")
    elseif a:this.queue =~ '\[:unrepl/hello'
        " Get rid of any possible remnants of a prompt or the like.
        let a:this.queue = substitute(a:this.queue, "^.*\[:unrepl/hello", "[:unrepl/hello", "")

        call ch_setoptions(a:this.channel,
                    \ { "callback": { ch, msg ->
                    \   vimpire#connection#HandleResponse(a:this, msg)
                    \ }})

        call vimpire#connection#HandleResponse(a:this, "")
    endif
endfunction

function! vimpire#connection#HandleResponse(this, msg)
    let a:this.queue .= a:msg

    while v:true
        try
            let [ response, nextQueue ] = vimpire#edn#Read(a:this.queue)
        catch /EOF/
            let response = v:none
            let nextQueue = a:this.queue
        endtry

        let a:this.queue = nextQueue

        if type(response) == v:t_none
            break
        endif

        let tag = response[0]

        " :unrepl/hello needs special treatment. If it's the first connection
        " for a prefix, ie. there is no sibling, we have to also fire up a
        " separate sideloader connection for the tooling backend.
        if tag == ":unrepl/hello"
            call vimpire#connection#HandleHello(a:this, response)
        endif

        if has_key(a:this.handlers, tag)
            call call(a:this.handlers[tag], [a:this, response])
        endif
    endwhile
endfunction

function! vimpire#connection#HandleHello(this, response)
    let payload = a:response[1]

    if has_key(payload, ":actions")
        let a:this.actions = payload[":actions"]
    else
        let a:this.actions = {}
    endif

    if has_key(payload, ":session")
        let a:this.session = payload[":session"]
    endif

    if has_key(payload, ":about")
        let a:this.about = payload[":about"]
    endif

    if type(a:this.sibling) == v:t_none
        let a:this.sideloader = vimpire#connection#NewSideloader(a:this)
    endif

    let a:this.running = v:true
endfunction

function! vimpire#connection#NewSideloader(oniisama)
    let this = {}

    let this.running  = v:false
    let this.oniisama = a:oniisama
    let this.queue    = ""
    let this.channel  = ch_open(
                \ a:oniisama.server, {
                \   "mode": "raw",
                \   "callback" : { ch, msg ->
                \      vimpire#connection#UpgradeSideloader(this, msg)
                \   }
                \ })

    let this.handlers = {
                \   ":resource":
                \   function("vimpire#connection#HandleSideloadedResource"),
                \   ":class":
                \   { this, response -> ch_sendraw(this.channel, "nil\n") }
                \ }

    return this
endfunction

function! vimpire#connection#UpgradeSideloader(this, msg)
    let a:this.queue .= a:msg

    if a:this.queue =~ 'user=> '
        let a:this.queue = ""

        let starter = vimpire#edn#Write(
                    \ vimpire#connection#ExpandAction(
                    \  a:this.oniisama.actions[":unrepl.jvm/start-side-loader"],
                    \  {}))

        call ch_sendraw(a:this.channel, starter . "\n")
    elseif a:this.queue =~ '\[:unrepl.jvm.side-loader/hello\]'
        let [ hello_, nextQueue ] = vimpire#edn#Read(a:this.queue)
        let a:this.queue = nextQueue

        call ch_setoptions(a:this.channel,
                    \ { "callback": { ch, msg ->
                    \   vimpire#connection#HandleResponse(a:this, msg)
                    \ }})

        let a:this.running = v:true
    endif
endfunction

function! vimpire#connection#HandleSideloadedResource(this, response)
    let fname = s:Location . "server/" . a:response[1]
    if filereadable(fname)
        let data = vimpire#edn#Write(join(readfile(fname), "\n"))
        call ch_sendraw(a:this.channel, data . "\n")
    else
        call ch_sendraw(a:this.channel, "nil\n")
    endif
endfunction

function! vimpire#connection#ExpandAction(form, bindings)
    if type(a:form) == v:t_dict
        if has_key(a:form, "edn/tag") && a:form["edn/tag"] == "unrepl/param"
            if has_key(a:bindings, a:form["edn/value"])
                return a:bindings[a:form["edn/value"]]
            else
                return v:null
            endif
        endif
    endif

    if type(a:form) == v:t_list
        let res = []

        for item in a:form
            call add(res, vimpire#connection#ExpandAction(item, a:bindings))
        endfor

        return res
    endif

    if type(a:form) == v:t_dict
        let res = {}

        for [ key, value ] in items(a:form)
            let key      = vimpire#connection#ExpandAction(key, a:bindings)
            let res[key] = vimpire#connection#ExpandAction(value, a:bindings)
        endfor

        return res
    endif

    " Just a value
    return a:form
endfunction

" Epilog
let &cpo = s:save_cpo
