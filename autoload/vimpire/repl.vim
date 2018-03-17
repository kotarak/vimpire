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

    call vimpire#connection#Start(server)

    if a:namespace != "user"
        call vimpire#connection#Eval(server,
                    \ "(in-ns '" . a:namespace . ")",
                    \ {})
    endif

    return this
endfunction

function! vimpire#repl#ShowWithProtectedPrompt(this, f)
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
    call vimpire#repl#ShowWithProtectedPrompt(
                \ a:this,
                \ function("vimpire#window#ShowText", [a:this, a:response[1]]))
endfunction

function! vimpire#repl#HandleEval(this, response)
    call vimpire#repl#DeleteLastLineIfNecessary(a:this)
    call vimpire#window#ShowText(a:this, vimpire#edn#Write(a:response[1]))
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
        if vimpire#edn#IsTaggedLiteral(elem, "unrepl/...")
            let incomplete = v:true
            break
        endif

        call add(stackTrace, vimpire#edn#Simplify(elem))
    endfor

    let exToPrint = {"edn/map": [
                \ [{"edn/keyword": ":cause"}, ex[":cause"]],
                \ [{"edn/keyword": ":trace"}, stackTrace]
                \ ]}

    call vimpire#connection#Action(a:this.conn.sibling,
                \ ":vimpire.nails/pprint-exception",
                \ {":ex": exToPrint},
                \ { "eval": { val ->
                \   vimpire#repl#ShowWithProtectedPrompt(
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
        normal! dd
    endwhile

    normal! dd
endfunction

" Epilog
let &cpo = s:save_cpo
