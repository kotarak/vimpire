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

if !exists("s:Registry")
    let s:Registry = {}
endif

function! vimpire#connection#RegisterPrefix(prefix, server)
    if !has_key(s:Registry, a:prefix)
        let s:Registry[a:prefix] = vimpire#connection#New(a:server)
        call vimpire#connection#Start(s:Registry[a:prefix])
    endif
endfunction

function! vimpire#connection#ForBuffer()
    let path = expand("%:p")

    if path == ""
       if exists("b:vimpire_connection")
           return b:vimpire_connection
       else
           let path = getcwd()
       endif
    endif

    for [ candidate, conn ] in items(s:Registry)
        if strpart(path, 0, len(candidate)) == candidate
            return conn
        endif
    endfor

    throw "Vimpire: No connection found"
endfunction

let s:DefaultHandlers = {
            \ ":read":
            \ { t, r -> vimpire#connection#HandleRead(t, r) },
            \ ":start-eval":
            \ { t, r -> vimpire#connection#HandleEvent(t, "startEval", r) },
            \ ":eval":
            \ { t, r -> vimpire#connection#HandleEndOfEval(t, "eval", r) },
            \ ":prompt":
            \ { t, r -> vimpire#connection#HandlePrompt(t, r) },
            \ ":out":
            \ { t, r -> vimpire#connection#HandleEvent(t, "out", r) },
            \ ":err":
            \ { t, r -> vimpire#connection#HandleEvent(t, "err", r) },
            \ ":log":
            \ { t, r -> vimpire#connection#HandleEvent(t, "log", r) },
            \ ":exception":
            \ { t, r -> vimpire#connection#HandleEndOfEval(t, "exception", r) }
            \ }

function! vimpire#connection#New(serverOrSibling)
    let this = {}

    let this.unrepled  = v:false
    let this.namespace = "user"

    if type(a:serverOrSibling) == v:t_dict
        let this.server  = a:serverOrSibling.server
        let this.sibling = a:serverOrSibling
    else
        let this.server  = a:serverOrSibling
        let this.sibling = v:none
    endif

    let this.equeue   = []
    let this.state    = "raw"
    let this.queue    = ""
    let this.handlers = s:DefaultHandlers

    return this
endfunction

function! vimpire#connection#Start(this)
    let a:this.channel = ch_open(
                \ a:this.server,
                \ { "mode": "raw",
                \   "callback" : { ch, msg ->
                \      vimpire#connection#UpgradeRepl(a:this, msg)
                \ }})
endfunction

function! vimpire#connection#UpgradeRepl(this, msg)
    let a:this.queue .= a:msg

    if a:this.queue =~ '\[:unrepl.upgrade/failed\]'
        call ch_close(a:this.channel)
        throw "Vimpire: Couldn't upgrade to unrepl."
    elseif a:this.queue =~ 'user=> ' && !a:this.unrepled
        let a:this.unrepled = v:true
        let a:this.queue = ""

        let starter = ""
        if type(a:this.sibling) != v:t_none
            let starter = vimpire#edn#Write(
                        \ vimpire#connection#ExpandAction(
                        \  a:this.sibling.actions[":start-aux"],
                        \  {}))
        else
            let starter = join(readfile(s:Location . "venom/unrepl/blob.clj"),
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

    while len(a:this.queue) > 0
        " Sideloader not ready, yet.
        if a:this.state == "hello"
            return
        endif

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

        let tag = vimpire#edn#Simplify(response[0])

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
    let payload = vimpire#edn#SimplifyMap(a:response[1])

    if has_key(payload, ":actions")
        let a:this.actions = vimpire#edn#SimplifyMap(payload[":actions"])
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
        let a:this.state = "hello"

        " This is the tooling repl for this backend server. We have to setup
        " the sideloader to get at the tooling venom. Also the tooling repl
        " should not use elisions.
        let a:this.sideloader = vimpire#connection#NewSideloader(a:this)

        " Disable elisions for tooling repl.
        let action = vimpire#connection#Action(
                    \ a:this,
                    \ ":print-limits",
                    \ {":unrepl.print/string-length": {"edn/symbol": "Long/MAX_VALUE"},
                    \  ":unrepl.print/coll-length":   {"edn/symbol": "Long/MAX_VALUE"},
                    \  ":unrepl.print/nesting-depth": {"edn/symbol": "Long/MAX_VALUE"}})

        " Set the name of the tooling repl.
        let action = vimpire#connection#Action(
                    \ a:this,
                    \ ":set-source",
                    \ {":unrepl/sourcename": "Tooling Repl",
                    \  ":unrepl/line": 1,
                    \  ":unrepl/column": 1})
    else
        let a:this.state = "awaiting-prompt"
    endif
endfunction

function! vimpire#connection#HandleEvent(this, event, response)
    if a:this.state != "evaling"
        return
    endif

    if has_key(a:this.equeue[0].callbacks, a:event)
        call a:this.equeue[0].callbacks[a:event](a:response[1])
    endif
endfunction

function! vimpire#connection#HandleEndOfEval(this, event, response)
    if a:this.state == "evaling"
        if has_key(a:this.equeue[0].callbacks, a:event)
            call a:this.equeue[0].callbacks[a:event](a:response[1])
        elseif a:event == "exception"
            echoerr vimpire#edn#Write(a:response[1])
        endif

        if a:this.equeue[0].remaining == 0
            call remove(a:this.equeue, 0)
            let a:this.state = "awaiting-prompt"
        endif
    endif
endfunction

function! vimpire#connection#HandlePrompt(this, response)
    let resp = vimpire#edn#Simplify(a:response)
    let a:this.namespace = resp[1]["clojure.core/*ns*"]

    " Weirdo heuristic. Either the submitted code was just whitespace
    " or we did a unrepl/do action. Cleanup the queue.
    if a:this.state == "evaling" && a:this.equeue[0].remaining == 0
        call remove(a:this.equeue, 0)
        let a:this.state = "awaiting-prompt"
    endif

    if a:this.state == "awaiting-prompt"
        let a:this.state = "prompt"
        call vimpire#connection#DoEval(a:this)
    endif
endfunction

function! vimpire#connection#HandleRead(this, response)
    if a:this.state == "evaling"
        let ctx = a:this.equeue[0]

        if has_key(ctx.callbacks, "read")
            call ctx.callbacks.read(a:response[1])
        endif

        let response = vimpire#edn#Simplify(a:response[1])

        let ctx.remaining = ctx.remaining - response[":len"]
    endif
endfunction

function! vimpire#connection#Eval(this, code, ...)
    " Note: strchars + 1 for trailing newline on submit
    let ctx = {
                \ "code":      a:code,
                \ "remaining": strchars(a:code) + 1,
                \ "callbacks": (a:0 > 0 ? a:1 : {})
                \ }

    call add(a:this.equeue, ctx)
    call vimpire#connection#DoEval(a:this)
endfunction

function! vimpire#connection#DoEval(this)
    if a:this.state != "prompt" || len(a:this.equeue) == 0
        return
    endif

    let a:this.state = "evaling"

    call ch_sendraw(a:this.channel, a:this.equeue[0].code . "\n")
endfunction

function! vimpire#connection#NewSideloader(oniisama)
    let this = {}

    let this.running  = v:false
    let this.oniisama = a:oniisama
    let this.queue    = ""
    let this.state    = "raw"
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
        let a:this.state = "waiting"

        let [ hello_, nextQueue ] = vimpire#edn#Read(a:this.queue)
        let a:this.queue = nextQueue

        call ch_setoptions(a:this.channel,
                    \ { "callback": { ch, msg ->
                    \   vimpire#connection#HandleResponse(a:this, msg)
                    \ }})

        let a:this.running = v:true

        " Tell Onii-sama and trigger queue activation.
        let a:this.oniisama.state = "awaiting-prompt"
        call vimpire#connection#HandleResponse(a:this.oniisama, "")
    endif
endfunction

function! vimpire#connection#HandleSideloadedResource(this, response)
    let fname = s:Location . "venom/" . a:response[1] . ".b64"
    if filereadable(fname)
        " Join without newline here, since files are wrapped.
        let data = vimpire#edn#Write(join(readfile(fname), ""))
        call ch_sendraw(a:this.channel, data . "\n")
    else
        call ch_sendraw(a:this.channel, "nil\n")
    endif
endfunction

function! vimpire#connection#ExpandAction(form, bindings)
    if type(a:form) == v:t_dict
        if has_key(a:form, "edn/tag") && a:form["edn/tag"] == "unrepl/param"
            if has_key(a:bindings, a:form["edn/value"]["edn/keyword"])
                return a:bindings[a:form["edn/value"]["edn/keyword"]]
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

function! vimpire#connection#Action(this, action, bindings, ...)
    let action = vimpire#connection#ExpandAction(
                \ a:this.actions[a:action],
                \ a:bindings)
    let code   = vimpire#edn#Write(action)

    call vimpire#connection#Eval(a:this, code, a:0 > 0 ? a:1 : {})
endfunction


" Epilog
let &cpo = s:save_cpo
