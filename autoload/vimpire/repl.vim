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

    let server.handlers = {
                \ ":started-eval":
                \ { _t, r -> vimpire#repl#HandleStartedEval(this, r) },
                \ ":prompt":
                \ { _t, r -> vimpire#repl#HandlePrompt(this, r) },
                \ ":out":
                \ { _t, r -> vimpire#repl#HandleOutput(this, r) },
                \ ":err":
                \ { _t, r -> vimpire#repl#HandleOutput(this, r) },
                \ ":eval":
                \ { _t, r -> vimpire#repl#HandleEval(this, r) },
                \ ":exception":
                \ { _t, r -> vimpire#repl#HandleException(this, r) }
                \ }

    let this.history = []
    let this.historyDepth = 0

    setlocal buftype=nofile
    setlocal noswapfile

    let b:vimpire_repl = this
    set filetype=vimpire.clojure

    if !hasmapto("<Plug>VimpireReplEnterHook.", "i")
        imap <buffer> <silent> <CR> <Plug>VimpireReplEnterHook.
    endif
    if !hasmapto("<Plug>VimpireReplEvaluate.", "i")
        imap <buffer> <silent> <C-CR> <Plug>VimpireReplEvaluate.
    endif
    if !hasmapto("<Plug>VimpireReplHatHook.", "n")
        nmap <buffer> <silent> ^ <Plug>VimpireReplHatHook.
    endif
    if !hasmapto("<Plug>VimpireReplUpHistory.", "i")
        imap <buffer> <silent> <C-Up> <Plug>VimpireReplUpHistory.
    endif
    if !hasmapto("<Plug>VimpireReplDownHistory.", "i")
        imap <buffer> <silent> <C-Down> <Plug>VimpireReplDownHistory.
    endif

    call append(line("$"), "Clojure")

    normal! G
    startinsert!

    let b:vimpire_namespace = "user"
    let this.namespace = "user"
    let this.prompt = "user=> "

    call vimpire#connection#Start(server)

    if a:namespace != "user"
        call vimpire#connection#Eval(server,
                    \ "(in-ns '" . a:namespace . ")",
                    \ {})
    endif

    return this
endfunction

function! vimpire#repl#HandlePrompt(this, response) abort
    let resp = vimpire#edn#Simplify(a:response)

    let a:this.namespace = resp[1]["clojure.core/*ns*"]
    let a:this.prompt = a:this.namespace . "=> "
    let a:this.state = "prompt"

    call vimpire#repl#ShowPrompt(a:this)
endfunction

function! vimpire#repl#HandleStartedEval(this, response)
    let a:this.state = "stdin"
endfunction

function! vimpire#repl#DeleteLastLineIfNecessary(this)
    call vimpire#window#GoHere(a:this)
    if getline(line("$")) == ""
        execute "normal! Gdd"
    endif
endfunction

function! vimpire#repl#HandleOutput(this, response)
    call vimpire#repl#DeleteLastLineIfNecessary(a:this)
    call vimpire#window#ShowText(a:this, a:response[1])
endfunction

function! vimpire#repl#HandleEval(this, response)
    call vimpire#repl#DeleteLastLineIfNecessary(a:this)
    call vimpire#window#ShowText(a:this, vimpire#edn#Write(a:response[1]))
endfunction

function! vimpire#repl#HandleException(this, response)
    call vimpire#repl#DeleteLastLineIfNecessary(a:this)
    call vimpire#window#ShowText(a:this, vimpire#edn#Write(a:response[1]))
endfunction

let s:ReplCommands = [ ",close" ]

function! s:IsReplCommand(cmd)
    for candidate in s:ReplCommands
        if candidate == a:cmd
            return 1
        endif
    endfor
    return 0
endfunction

function! vimpire#repl#DoReplCommand(this, cmd)
    if a:cmd == ",close"
        call ch_close(a:this.conn.channel)
        call vimpire#window#Close(a:this)
        stopinsert
    endif
endfunction

function! vimpire#repl#ShowPrompt(this)
    call vimpire#window#ShowText(a:this, a:this.prompt)
    let b:vimpire_namespace = a:this.namespace

    normal! G
    startinsert!
endfunction

function! vimpire#repl#GetCommand(this)
    let ln = line("$")

    while getline(ln) !~ "^" . a:this.prompt && ln > 0
        let ln = ln - 1
    endwhile

    " Special Case: User deleted Prompt by accident. Insert a new one.
    if ln == 0
        call vimpire#repl#ShowPrompt(a:this)
        return ""
    endif

    let cmd = vimpire#util#Yank("l", ln . "," . line("$") . "yank l")

    let cmd = substitute(cmd, "^" . a:this.prompt . "\\s*", "", "")
    let cmd = substitute(cmd, "\n$", "", "")
    return cmd
endfunction

function! s:DoEnter()
    execute "normal! a\<CR>x"
    normal! ==x
    if getline(".") =~ '^\s*$'
        startinsert!
    else
        startinsert
    endif
endfunction

function! vimpire#repl#EnterHookStdin(this)
    call ch_sendraw(a:this.conn.channel, getline(line(".")) . "\n")
    execute "normal! a\<CR>"
    startinsert!
endfunction

function! vimpire#repl#EnterHookPrompt(this)
    let lastCol = {}

    function lastCol.f() dict
        normal! g_
        return col(".")
    endfunction

    if line(".") < line("$") || col(".") < vimpire#util#WithSavedPosition(lastCol)
        call s:DoEnter()
        return
    endif

    let cmd = vimpire#repl#GetCommand(a:this)

    " Special Case: Showed prompt (or user just hit enter).
    if cmd =~ '^\(\s\|\n\)*$'
        execute "normal! a\<CR>"
        startinsert!
        return
    endif

    if s:IsReplCommand(cmd)
        call vimpire#repl#DoReplCommand(a:this, cmd)
        return
    endif

    let action = vimpire#connection#ExpandAction(
                \ a:this.conn.sibling.actions[":vimpire.nails/check-syntax"],
                \ {":nspace":  a:this.namespace,
                \  ":content": cmd})
    let code   = vimpire#edn#Write(action)

    call vimpire#connection#Eval(
                \ a:this.conn.sibling,
                \ code,
                \ {"eval":
                \  { val ->
                \     vimpire#repl#HandleSyntaxChecked(a:this, cmd, val)
                \  }})
endfunction

function! vimpire#repl#HandleSyntaxChecked(this, cmd, validForm)
    if a:validForm
        call ch_sendraw(a:this.conn.channel, a:cmd . "\n")
        execute "normal! o"
        startinsert!
    else
        call s:DoEnter()
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
        call vimpire#window#ShowText(a:this, a:this.prompt . " " . cmd)
    endif

    normal! G$
endfunction

function! vimpire#repl#DownHistory(this)
    let histLen = len(a:this.history)
    let histDepth = a:this.historyDepth

    if histDepth > 0 && histLen > 0
        let a:this.historyDepth = histDepth - 1
        let cmd = a:this.history[a:this.historyDepth]

        call vimpire#repl#DeleteLast(a:this)
        call vimpire#window#ShowText(a:this, a:this.prompt . " " . cmd)
    elseif histDepth == 0
        call vimpire#repl#DeleteLast(a:this)
        call vimpire#window#ShowText(a:this, a:this.prompt . " ")
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
