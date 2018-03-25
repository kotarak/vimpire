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

let s:save_cpo = &cpo
set cpo&vim

" The Repl

" Simple wrapper to allow on demand load of autoload/vimpire.vim.
function! vimpire#repl#StartRepl(sibling, ...)
    let ns = a:0 > 0 ? a:1 : "user"
    call vimpire#repl#New(a:sibling, ns)
endfunction

" FIXME: Ugly hack. But easier than cleaning up the buffer
" mess in case something goes wrong with repl start.
function! vimpire#repl#New(sibling, namespace)
    let server  = vimpire#connection#New(a:sibling)

    let this = vimpire#window#New("vimpire#buffer#New")
    let this.conn = server

    let server.handlers =
                \ {":started-eval":
                \  { _t, r -> vimpire#repl#HandleStartedEval(this, r)},
                \  ":prompt":
                \  { _t, r -> vimpire#repl#HandlePrompt(this, r)},
                \  ":out":
                \  { _t, r -> vimpire#repl#HandleOutput(this, r)},
                \  ":err":
                \  { _t, r -> vimpire#repl#HandleOutput(this, r)},
                \  ":eval":
                \  { _t, r -> vimpire#repl#HandleEval(this, r)},
                \  ":exception":
                \  { _t, r -> vimpire#repl#HandleException(this, r)}}

    let this.history = []
    let this.historyDepth = 0

    setlocal buftype=nofile
    setlocal noswapfile

    let b:vimpire_repl = this
    set filetype=vimpire.clojure

    if !hasmapto("<Plug>(vimpire_repl_enter_hook)", "i")
        imap <buffer> <silent> <CR> <Plug>(vimpire_repl_enter_hook)
    endif
    if !hasmapto("<Plug>(vimpire_repl_evaluate)", "i")
        imap <buffer> <silent> <C-CR> <Plug>(vimpire_repl_evaluate)
    endif
    if !hasmapto("<Plug>(vimpire_repl_hat_hook)", "n")
        nmap <buffer> <silent> ^ <Plug>(vimpire_repl_hat_hook)
    endif
    if !hasmapto("<Plug>(vimpire_repl_up_history)", "i")
        imap <buffer> <silent> <C-Up> <Plug>(vimpire_repl_up_history)
    endif
    if !hasmapto("<Plug>(vimpire_repl_down_history)", "i")
        imap <buffer> <silent> <C-Down> <Plug>(vimpire_repl_down_history)
    endif

    call append(line("$"), "Clojure")

    normal! G
    startinsert!

    let b:vimpire_namespace = "user"
    let this.prompt = "user=> "
    let this.value  = {"form": v:null, "elisions": {}}

    call vimpire#connection#Start(server)

    if a:namespace != "user"
        call vimpire#connection#Eval(server,
                    \ "(in-ns '" . a:namespace . ")",
                    \ {})
    endif

    return this
endfunction

function! vimpire#repl#WithProtectedPrompt(this, f)
    if a:this.state == "prompt"
        let [ _buf, cline, ccol, _off ] = getpos(".")
        let lline = line("$")

        let pline = vimpire#repl#FindPrompt(a:this)
        let promptLines = getline(pline, lline)
        execute pline . "," lline . "delete _"

        call a:f()

        call append(line("$"), promptLines)
        call cursor(line("$") - (lline - cline), ccol)
        " Although supposed to be unnecessary…
        redraw
    else
        call vimpire#repl#DeleteLastLineIfNecessary(a:this)

        call a:f()

        call append(line("$"), "")
        call cursor(line("$"), col([line("$"), "$"]))
        " Although supposed to be unnecessary…
        redraw
    endif
endfunction

function! vimpire#repl#ShowPrompt(this)
    call vimpire#repl#DeleteLastLineIfNecessary(a:this)
    call vimpire#window#ShowText(a:this, a:this.prompt)

    call cursor(line("$"), col([line("$"), "$"]))
    " Although supposed to be unnecessary…
    redraw
endfunction

function! vimpire#repl#HandlePrompt(this, response)
    let nspace = a:this.conn.namespace
    let cmd = join(vimpire#repl#GetCommand(a:this), "\n")

    let a:this.conn.namespace = vimpire#edn#Simplify(a:response[1])["clojure.core/*ns*"]
    let a:this.prompt = a:this.conn.namespace . "=> "
    let a:this.state  = "prompt"

    if nspace != a:this.conn.namespace || cmd !~ '^\(\s\|\n\)*$'
        call vimpire#repl#ShowPrompt(a:this)
    endif
    let b:vimpire_namespace = a:this.conn.namespace
endfunction

function! vimpire#repl#HandleStartedEval(this, response)
    if a:this.state == "prompt"
        " Check if there is an empty prompt. Get rid of it if so.
        let cmd = join(vimpire#repl#GetCommand(a:this), "\n")
        if cmd =~ '^\(\s\|\n\)*$'
            call vimpire#repl#DeleteLast(a:this)
        endif
    endif

    let a:this.state = "stdin"

    call append(line("$"), "")
    call cursor(line("$"), col([line("$"), "$"]))
    " Although supposed to be unnecessary…
    redraw
endfunction

function! vimpire#repl#DeleteLastLineIfNecessary(this)
    call vimpire#window#GoHere(a:this)
    if getline(line("$")) == ""
        execute line("$") . "delete _"
    endif
endfunction

function! vimpire#repl#HandleOutput(this, response)
    call vimpire#repl#WithProtectedPrompt(
                \ a:this,
                \ function("vimpire#window#ShowText", [a:this, a:response[1]]))
endfunction

let g:vimpire#repl#Printers = {
            \ "clojure/var":
            \ { val, ps -> "#'" . vimpire#edn#Write(val, ps) },
            \ "unrepl/ratio":
            \ { val, ps_ -> val[0] . "/" . val[1] },
            \ "unrepl/...":
            \ { val, ps_ -> val is v:null ? "…" : "vv" . val },
            \ "unrepl/string":
            \ { val, ps ->
            \   vimpire#edn#WriteString(val[0] . "…")
            \     . vimpire#edn#Write(val[1], ps)
            \ }}

function! vimpire#repl#HandleEval(this, response)
    let a:this.value = vimpire#repl#ExtractElisions(a:response[1])

    call vimpire#repl#DeleteLastLineIfNecessary(a:this)

    let a:this.value.start = line("$") + 1

    call vimpire#window#ShowText(a:this,
                \ vimpire#edn#Write(a:this.value.form, g:vimpire#repl#Printers))
    call cursor(line("$"), col([line("$"), "$"]))

    " Although supposed to be unnecessary…
    redraw
endfunction

function! vimpire#repl#HandleException(this, response)
    " Exceptions are tagged as #error.
    let ex = vimpire#edn#SimplifyMap(a:response[1])[":ex"]["edn/value"]
    let ex = vimpire#edn#SimplifyMap(ex)

    let stackTrace = []
    let incomplete = v:false
    for elem in ex[":trace"]
        if vimpire#edn#IsTaggedLiteral(elem,
                    \ vimpire#edn#Symbol("...", "unrepl"))
            let incomplete = v:true
            break
        endif

        call add(stackTrace, vimpire#edn#Simplify(elem))
    endfor

    let exToPrint = vimpire#edn#Map([
                \ [vimpire#edn#Keyword("cause"), ex[":cause"]],
                \ [vimpire#edn#Keyword("trace"), stackTrace]
                \ ])

    call vimpire#connection#Action(a:this.conn.sibling,
                \ ":vimpire.nails/pprint-exception",
                \ {":ex": exToPrint},
                \ { "eval": { val ->
                \   vimpire#repl#WithProtectedPrompt(
                \     a:this,
                \     function("vimpire#repl#ShowException",
                \       [a:this, val, incomplete]))
                \ }})
endfunction

function! vimpire#repl#ShowException(this, response, incomplete)
    call vimpire#window#ShowText(a:this, a:response)
    if a:incomplete
        call vimpire#window#ShowText(a:this, "    ...")
    endif
endfunction

function! vimpire#repl#FindPrompt(this)
    let ln = line("$")

    while getline(ln) !~ "^" . a:this.prompt && ln > 0
        let ln = ln - 1
    endwhile

    return ln
endfunction

function! vimpire#repl#GetCommand(this)
    let ln = vimpire#repl#FindPrompt(a:this)

    " Special Case: User deleted Prompt by accident. Insert a new one.
    if ln == 0
        call vimpire#repl#ShowPrompt(a:this)
        return [""]
    endif

    let cmd = getline(ln, line("$"))
    let cmd[0] = substitute(cmd[0], "^" . a:this.prompt . "\\s*", "", "")

    return cmd
endfunction

function! vimpire#repl#CloseCommand(this)
    call vimpire#connection#Disconnect(a:this.conn.channel)
    call vimpire#window#Close(a:this)
    stopinsert
endfunction

let s:ReplCommands = {
            \ ",close": function("vimpire#repl#CloseCommand")
            \ }

function! vimpire#repl#EnterHookStdin(this)
    call vimpire#connection#Send(a:this.conn.channel, getline(line(".")))
    call append(line("$"), "")
    call cursor(line("$"), col([line("$"), "$"]))
    redraw
    startinsert!
endfunction

function! s:FindLastCol()
    normal! g_
    return col(".")
endfunction

function! vimpire#repl#EnterHookPrompt(this)
    " Special Case: If inside an expression we do not send the expression,
    " but enter a newline and reindent the code.
    if line(".") < line("$")
                \ || col(".") < vimpire#util#WithSavedPosition(function("s:FindLastCol"))
        execute "normal! a\<CR>x"
        normal! ==x
        if getline(".") =~ '^\s*$'
            startinsert!
        else
            startinsert
        endif
        return
    endif

    " Otherwise, we check whether the command is complete and if so,
    " submit it to the repl.
    let cmd = vimpire#repl#GetCommand(a:this)

    " Special Case: The user typed a shell command.
    if len(cmd) == 1 && has_key(s:ReplCommands, cmd[0])
        call s:ReplCommands[cmd[0]](a:this)
        return
    endif

    let cmd = join(cmd, "\n")

    " Special Case: Showed prompt (or user just hit enter).
    if cmd =~ '^\(\s\|\n\)*$'
        call append(line("$"), "")
        call cursor(line("$"), col([line("$"), "$"]))
        startinsert!
        return
    endif

    call vimpire#connection#Action(
                \ a:this.conn.sibling,
                \ ":vimpire.nails/check-syntax",
                \ {":nspace":  a:this.conn.namespace,
                \  ":content": cmd},
                \ {"eval":
                \  { val ->
                \     vimpire#repl#HandleSyntaxChecked(a:this, cmd, val)
                \  }})

    startinsert!
endfunction

function! vimpire#repl#HandleSyntaxChecked(this, cmd, validForm)
    if a:validForm
        let a:this.historyDepth = 0
        call insert(a:this.history, a:cmd)
        call vimpire#connection#Send(a:this.conn.channel, a:cmd)
    else
        execute "normal! a\<CR>x"
        normal! ==x
        call cursor(line("$"), col([line("$"), "$"]))
    endif
endfunction

function! vimpire#repl#EnterHook(this)
    if a:this.state == "prompt"
        call vimpire#repl#EnterHookPrompt(a:this)
    elseif a:this.state == "stdin"
        call vimpire#repl#EnterHookStdin(a:this)
    endif
endfunction

function! vimpire#repl#HatHook(this)
    let l = getline(".")

    if l =~ "^" . a:this.prompt
        let [buf, line, col, off] = getpos(".")
        call setpos(".", [buf, line, len(a:this.prompt) + 2, off])
    else
        normal! ^
    endif
endfunction

function! vimpire#repl#UpHistory(this)
    let histLen = len(a:this.history)
    let histDepth = a:this.historyDepth

    if histLen > 0 && histLen > histDepth
        let cmd = a:this.history[histDepth]
        let a:this.historyDepth = histDepth + 1

        call vimpire#repl#DeleteLast(a:this)
        call vimpire#window#ShowText(a:this, a:this.prompt . cmd)
    endif

    normal! G$
endfunction

function! vimpire#repl#DownHistory(this)
    let histLen = len(a:this.history)
    let histDepth = a:this.historyDepth

    if histDepth > 0 && histLen > 0
        if histDepth == histLen
            let a:this.historyDepth = histDepth - 2
        else
            let a:this.historyDepth = histDepth - 1
        endif
        let cmd = a:this.history[a:this.historyDepth]

        call vimpire#repl#DeleteLast(a:this)
        call vimpire#window#ShowText(a:this, a:this.prompt . cmd)
    elseif histDepth == 0
        call vimpire#repl#DeleteLast(a:this)
        call vimpire#window#ShowText(a:this, a:this.prompt)
    endif

    normal! G$
endfunction

function! vimpire#repl#DeleteLast(this)
    normal! G

    while getline("$") !~ a:this.prompt
        delete _
    endwhile

    delete _
endfunction

" Elision Handling
let s:ElisionSymbol = vimpire#edn#Symbol("...", "unrepl")
let s:ElisionString = vimpire#edn#Symbol("string", "unrepl")
let s:VimpireSplice = vimpire#edn#Symbol("splice", "vimpire")

function! s:ExtractElisionsWorker(unit, elision)
    if vimpire#edn#IsTaggedLiteral(a:elision, s:ElisionString)
        let el = copy(a:elision)
        let el["edn/value"] = vimpire#edn#Traverse(el["edn/value"],
                    \ function("s:ExtractElisionsWorker", [a:unit]))
        return el
    endif

    if !vimpire#edn#IsTaggedLiteral(a:elision, s:ElisionSymbol)
        return a:elision
    endif

    " This is the elided map key.
    if a:elision["edn/value"] is v:null
        return a:elision
    endif

    " Already known elision of a previous value, which is now
    " expanded in some other part.
    if type(a:elision["edn/value"]) == v:t_number
        return a:elision
    endif

    let elision = vimpire#edn#SimplifyMap(a:elision["edn/value"])

    let id = a:unit.id
    let a:unit.id += 1
    let a:unit.elisions[id] = elision[":get"]

    return {"edn/tag": s:ElisionSymbol, "edn/value": id}
endfunction

function! vimpire#repl#ExtractElisions(form, ...)
    let unit = a:0 > 0 ? a:1 : {"id": 1, "elisions": {}}

    let unit.form = vimpire#edn#Traverse(a:form,
                \ function("s:ExtractElisionsWorker", [unit]))

    return unit
endfunction

function! s:ElisionReplaceWorker(id, val, form)
    " unrepl/string may be spliced with a pure string or
    " another unrepl/string. In case of the latter we merge
    " the strings and take over the new elision. The string
    " is the simple case. There is no more elision so we can
    " happily replace the unrepl/string.
    if vimpire#edn#IsTaggedLiteral(a:form, s:ElisionString)
                \ && a:form["edn/value"][1]["edn/value"] == a:id
        if vimpire#edn#IsTaggedLiteral(a:val, s:ElisionString)
            return {"edn/tag": s:ElisionString,
                        \ "edn/value":
                        \   [a:form["edn/value"][0] . a:val["edn/value"][0],
                        \    a:val["edn/value"][1]]}
        else
            return a:form["edn/value"][0] . a:val
        endif
    endif

    if !vimpire#edn#IsTaggedLiteral(a:form, s:ElisionSymbol)
        return a:form
    endif

    " For non-strings we replace the elision with a custom
    " marker since the elision has to be spliced in the
    " surrounding compound form. If the expansion failed,
    " we get a null elision literal as value. In this case
    " we simply insert this value.
    if a:form["edn/value"] == a:id
        if vimpire#edn#IsTaggedLiteral(a:val, s:ElisionSymbol)
            return a:val
        else
            return {"edn/tag": s:VimpireSplice, "edn/value": a:val}
        endif
    else
        return a:form
    endif
endfunction

function! s:ElisionSpliceWorker(form)
    let elems = []
    if vimpire#edn#IsMagical(a:form, "edn/map")
                \ || (type(a:form) == v:t_dict
                \   && !vimpire#edn#IsMagical(a:form))
        for [k, v] in vimpire#edn#Items(a:form)
            if vimpire#edn#IsTaggedLiteral(v, s:VimpireSplice)
                call extend(elems, vimpire#edn#Items(v["edn/value"]))
            else
                call add(elems, [k, v])
            endif
        endfor
    else
        for elem in vimpire#edn#Items(a:form)
            if vimpire#edn#IsTaggedLiteral(elem, s:VimpireSplice)
                call extend(elems, vimpire#edn#Items(elem["edn/value"]))
            else
                call add(elems, elem)
            endif
        endfor
    endif
    return vimpire#edn#SameAs(elems, a:form)
endfunction

function! s:ShowUpdatedElision(this)
    execute a:this.value.start ",$delete _"
    call vimpire#window#ShowText(a:this,
                \ vimpire#edn#Write(a:this.value.form, g:vimpire#repl#Printers))
endfunction

function! vimpire#repl#ExpandElisionCallback(this, id, val)
    " If we got an elision literal, the elision could not
    " be resolved. There won't be a :get. Since vim has no
    " sets, we can safely set the contents here to v:null
    " for simple printing.
    if vimpire#edn#IsTaggedLiteral(a:val, s:ElisionSymbol)
        let a:val["edn/value"] = v:null
    endif

    unlet a:this.value.elisions[a:id]
    let a:this.value.form = vimpire#edn#Traverse(a:this.value.form,
                \ function("s:ElisionReplaceWorker", [a:id, a:val]),
                \ function("s:ElisionSpliceWorker"))

    let a:this.value = vimpire#repl#ExtractElisions(
                \ a:this.value.form, a:this.value)

    call vimpire#repl#WithProtectedPrompt(a:this,
                \ function("s:ShowUpdatedElision", [a:this]))
endfunction

function! vimpire#repl#ExpandElision(this, id)
    if !has_key(a:this.value.elisions, a:id)
        echomsg "Unknown id: " . a:id
        return
    endif

    call vimpire#connection#Eval(a:this.conn.sibling,
                \ vimpire#edn#Write(a:this.value.elisions[a:id]),
                \ {"eval":
                \  function("vimpire#repl#ExpandElisionCallback",
                \    [a:this, a:id])})
endfunction

function! vimpire#repl#GetElisionId(word)
    return substitute(a:word, '.*vv\(\d\+\)', '\1', '')
endfunction

" Epilog
let &cpo = s:save_cpo
