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

if !has("nvim")
    function! vimpire#connection#Connect(this, initCallback)
        return ch_open(a:this.server,
                    \ {"mode":     "raw",
                    \  "callback": { ch_, msg -> a:initCallback(msg)}})
    endfunction

    function! vimpire#connection#Disconnect(this)
        call ch_close(a:this)
    endfunction

    function! vimpire#connection#Send(this, code)
        call ch_sendraw(a:this, a:code . "\n")
    endfunction
else
    function! vimpire#connection#Connect(this, initCallback)
        return sockconnect("tcp", a:this.server,
                    \ {"on_data":
                    \  vimpire#connection#Dispatch(a:this, a:initCallback)})
    endfunction

    function! vimpire#connection#Disconnect(this)
        call chanclose(a:this)
    endfunction

    function! vimpire#connection#Send(this, code)
        call chansend(a:this, a:code . "\n")
    endfunction

    function! vimpire#connection#DoDispatch(this, initCallback, msg)
        let msg = join(a:msg, "\n")

        if a:this.state != "raw"
            call vimpire#connection#HandleResponse(a:this, msg)
        else
            call a:initCallback(msg)
        endif
    endfunction

    function! vimpire#connection#Dispatch(this, initCallback)
        return { t_, msg, e_ ->
                    \ vimpire#connection#DoDispatch(a:this, a:initCallback, msg)
                    \ }
    endfunction
endif

function! s:Ready()
    let fangs = [
                \ '        __   __',
                \ '     .-''  "."  ''-.',
                \ '   .''   ___,___   ''.',
                \ '  ;__.-; | | | ;-.__;',
                \ '  | \  | | | | |  / |',
                \ '   \ \/`"`"`"`"`\/ /',
                \ '    \_.-,-,-,-,-._/',
                \ '     \`-:_|_|_:-''/',
                \ 'jgs   ''.       .''',
                \ '        `''---''`',
                \ ]

    let padding = repeat(" ", (winwidth(0) - 20) / 2)

    return join(
                \ map(
                \   copy(fangs),
                \     { idx_, line -> padding . line }),
                \   "\n")
                \ . "\n"
endfunction

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
        let path = getcwd()
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
            \ { t, r -> vimpire#connection#HandleEvent(t, "read", r) },
            \ ":start-eval":
            \ { t, r -> vimpire#connection#HandleEvent(t, "startEval", r) },
            \ ":eval":
            \ { t, r -> vimpire#connection#HandleEndOfEval(t, "eval", r) },
            \ ":prompt":
            \ { t, r -> vimpire#connection#HandlePrompt(t, r) },
            \ ":out":
            \ { t, r -> vimpire#connection#HandleOutput(t, "out", r) },
            \ ":err":
            \ { t, r -> vimpire#connection#HandleOutput(t, "err", r) },
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
        let this.sibling = g:vimpire#Nil
    endif

    let this.equeue   = []
    let this.offset   = 0
    let this.state    = "raw"
    let this.queue    = ""
    let this.handlers = s:DefaultHandlers
    let this.venom    = vimpire#venom#Inject()
    let this.evalUnit = { "id": 0, "output": [] }

    return this
endfunction

function! vimpire#connection#Start(this)
    let a:this.channel = vimpire#connection#Connect(
                \ a:this,
                \ { msg -> vimpire#connection#UpgradeRepl(a:this, msg)})
endfunction

function! vimpire#connection#UpgradeRepl(this, msg)
    let a:this.queue .= a:msg

    if a:this.queue =~ '\[:unrepl.upgrade/failed\]'
        call vimpire#connection#Disconnect(a:this.channel)
        throw "Vimpire: Couldn't upgrade to unrepl."
    elseif a:this.queue =~ 'user=> ' && !a:this.unrepled
        let a:this.unrepled = v:true
        let a:this.queue = ""

        let starter = ""
        if a:this.sibling isnot g:vimpire#Nil
            let starter = vimpire#edn#Write(
                        \ vimpire#connection#ExpandAction(
                        \  a:this.sibling.actions[":start-aux"],
                        \  {}))
        else
            let starter = a:this.venom.blob . "\n" . a:this.venom.actions
        endif

        call vimpire#connection#Send(a:this.channel, starter)
    elseif a:this.queue =~ '\[:unrepl/hello'
        let a:this.state = "greeted"

        " Get rid of any possible remnants of a prompt or the like.
        let a:this.queue = substitute(a:this.queue, "^.*\[:unrepl/hello", "[:unrepl/hello", "")

        if !has("nvim")
            call ch_setoptions(a:this.channel,
                        \ { "callback": { ch, msg ->
                        \   vimpire#connection#HandleResponse(a:this, msg)
                        \ }})
        endif

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
            let response = g:vimpire#Nil
            let nextQueue = a:this.queue
        endtry

        let a:this.queue = nextQueue

        if response is g:vimpire#Nil
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

    if a:this.sibling is g:vimpire#Nil
        let a:this.state = "hello"

        " This is the tooling repl for this backend server. We have to setup
        " the sideloader to get at the tooling venom. Also the tooling repl
        " should not use elisions.
        let a:this.sideloader = vimpire#connection#NewSideloader(a:this)

        " Disable elisions for tooling repl.
        let longMaxValue = vimpire#edn#Symbol("Long/MAX_VALUE")
        let action = vimpire#connection#Action(
                    \ a:this,
                    \ ":print-limits",
                    \ {":unrepl/string-length": longMaxValue,
                    \  ":unrepl/coll-length":   longMaxValue,
                    \  ":unrepl/nesting-depth": longMaxValue})

        " Require the venom namespaces.
        call vimpire#connection#Eval(a:this, a:this.venom.init, {})

        " Set the name of the tooling repl.
        let action = vimpire#connection#Action(
                    \ a:this,
                    \ ":set-source",
                    \ {":unrepl/sourcename": "Tooling Repl",
                    \  ":unrepl/line": 1,
                    \  ":unrepl/column": 1})

        " Await the previous commands to finish.
        call vimpire#connection#Eval(
                    \ a:this,
                    \ "true",
                    \ { "eval": { val_ -> vimpire#ui#ShowResult(s:Ready()) }})
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
    let a:this.evalUnit.result = [a:event, a:response[1]]

    if a:this.state == "evaling"
        if has_key(a:this.equeue[0].callbacks, a:event)
            call a:this.equeue[0].callbacks[a:event](a:response[1])
        endif
    else
        if a:event == "exception"
            echoerr vimpire#edn#Write(a:response[1])
        endif
    endif
endfunction

function! vimpire#connection#HandlePrompt(this, response)
    let response = vimpire#edn#Simplify(a:response[1])
    let a:this.namespace = response["clojure.core/*ns*"]

    " Weirdo heuristic. Either the submitted code was just whitespace
    " or we did a unrepl/do action. Cleanup the queue.
    if a:this.state == "evaling"
        let len = response[":offset"] - a:this.offset
        let ctx = a:this.equeue[0]

        let ctx.remaining -= len

        " If the current eval unit has no result,
        " this was a spurious prompt.
        if has_key(a:this.evalUnit, "result")
            call add(ctx.evalUnits, a:this.evalUnit)
        endif

        if ctx.remaining == 0
            if has_key(ctx.callbacks, "result")
                call ctx.callbacks.result(ctx.evalUnits)
            endif
            call remove(a:this.equeue, 0)
            let a:this.state = "awaiting-prompt"
        else
            if has_key(ctx.callbacks, "prompt")
                call ctx.prompt(a:response[1])
            endif
        endif
    endif

    let a:this.offset = response[":offset"]
    let a:this.evalUnit = { "id": a:response[2], "output": [] }

    if a:this.state == "awaiting-prompt"
        let a:this.state = "prompt"
        call vimpire#connection#DoEval(a:this)
    endif
endfunction

function! vimpire#connection#HandleOutput(this, event, response)
    if a:response[2] != a:this.evalUnit.id
        return
    endif

    if a:this.state != "evaling"
        return
    endif

    if has_key(a:this.equeue[0].callbacks, a:event)
        call a:this.equeue[0].callbacks[a:event](a:response[1])
    endif

    call add(a:this.evalUnit.output,
                \ [a:event, split(a:response[1], '\r\?\n')])
endfunction

function! vimpire#connection#Eval(this, code, ...)
    " Note: strchars + 1 for triggering newline.
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

    let a:this.equeue[0].evalUnits = []

    call vimpire#connection#Send(a:this.channel, a:this.equeue[0].code)
endfunction

let s:SideloaderHandlers = {
            \   ":resource":
            \   function("vimpire#connection#HandleSideloadedResource"),
            \   ":class":
            \   { t, response ->
            \     vimpire#connection#Send(t.channel, "nil")
            \   }
            \ }

function! vimpire#connection#NewSideloader(oniisama)
    let this = {}

    let this.server   = a:oniisama.server
    let this.running  = v:false
    let this.oniisama = a:oniisama
    let this.queue    = ""
    let this.state    = "raw"
    let this.channel  = vimpire#connection#Connect(
                \ this,
                \ { msg -> vimpire#connection#UpgradeSideloader(this, msg) })

    let this.handlers = s:SideloaderHandlers

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

        call vimpire#connection#Send(a:this.channel, starter)
    elseif a:this.queue =~ '\[:unrepl.jvm.side-loader/hello\]'
        let a:this.state = "waiting"

        let [ hello_, nextQueue ] = vimpire#edn#Read(a:this.queue)
        let a:this.queue = nextQueue

        if !has("nvim")
            call ch_setoptions(a:this.channel,
                        \ { "callback": { ch_, msg ->
                        \   vimpire#connection#HandleResponse(a:this, msg)
                        \ }})
        endif

        let a:this.running = v:true

        " Tell Onii-sama and trigger queue activation.
        let a:this.oniisama.state = "awaiting-prompt"
        call vimpire#connection#HandleResponse(a:this.oniisama, "")
    endif
endfunction

function! vimpire#connection#HandleSideloadedResource(this, response)
    call vimpire#connection#Send(a:this.channel,
                \ vimpire#edn#Write(get(a:this.oniisama.venom.resources,
                \   a:response[1], v:null)))
endfunction

function! vimpire#connection#ExpandAction(form, bindings)
    if type(a:form) == v:t_dict
        if vimpire#edn#IsTaggedLiteral(a:form,
                    \ {"edn/namespace": "unrepl", "edn/symbol": "param"})
            let k = vimpire#edn#Simplify(a:form["edn/value"])

            if !has_key(a:bindings, k)
                throw "Vimpire: binding " . k . "missing in action expansion"
            endif

            return a:bindings[k]
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
