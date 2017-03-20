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
function! vimpire#repl#StartRepl(...)
    let ns = a:0 > 0 ? a:1 : "user"
    call vimpire#repl#New(ns)
endfunction

" FIXME: Ugly hack. But easier than cleaning up the buffer
" mess in case something goes wrong with repl start.
function! vimpire#repl#New(namespace, ...)
    let server = vimpire#backend#server#Instance()

    let replStart = vimpire#backend#server#Execute(server,
                \ {"op":     "repl",
                \  "start?": v:true,
                \  "nspace": a:namespace})
    if replStart.stderr != ""
        call vimpire#ui#ReportError(replStart.stderr)
        return
    endif

    let this = vimpire#window#New("vimpire#buffer#New")
    let this.id = replStart.value

    let this.history = []
    let this.historyDepth = 0
    let this.prompt = a:namespace . "=>"

    setlocal buftype=nofile
    setlocal noswapfile

    call append(line("$"), ["Clojure", this.prompt . " "])

    let b:vimpire_repl = this

    let b:vimpire_namespace = a:namespace
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

    normal! G
    startinsert!

    return this
endfunction

let s:ReplCommands = [ ",close", ",st", ",ct", ",toggle-pprint" ]

function! s:IsReplCommand(cmd)
    for candidate in s:ReplCommands
        if candidate == a:cmd
            return 1
        endif
    endfor
    return 0
endfunction

function! vimpire#repl#DoReplCommand(this, cmd)
    let server = vimpire#backend#server#Instance()

    if a:cmd == ",close"
        call vimpire#backend#server#Execute(server,
                    \ {"op":    "repl",
                    \  "id":    a:this.id,
                    \  "stop?": v:true})
        call vimpire#window#Close(a:this)
        stopinsert
    elseif a:cmd == ",st"
        let result = vimpire#backend#server#Execute(server,
                    \ {"op":      "repl",
                    \  "id":      a:this.id,
                    \  "ignore?": v:true,
                    \  "stdin":   "(vimpire.util/pretty-print-stacktrace *e)"})
        call vimpire#window#ShowOutput(a:this, result)
        call vimpire#repl#ShowPrompt(a:this)
    elseif a:cmd == ",ct"
        let result = vimpire#backend#server#Execute(server,
                    \ {"op":      "repl",
                    \  "id":      a:this.id,
                    \  "ignore?": v:true,
                    \  "stdin":   "(vimpire.util/pretty-print-causetrace *e)"})
        call vimpire#window#ShowOutput(a:this, result)
        call vimpire#repl#ShowPrompt(a:this)
    elseif a:cmd == ",toggle-pprint"
        let result = vimpire#backend#server#Execute(server,
                    \ {"op":      "repl",
                    \  "id":      a:this.id,
                    \  "ignore?": v:true,
                    \  "stdin":   "(set! vimpire.repl/*print-pretty* (not vimpire.repl/*print-pretty*))"})
        call vimpire#window#ShowOutput(a:this, result)
        call vimpire#repl#ShowPrompt(a:this)
    endif
endfunction

function! vimpire#repl#ShowPrompt(this)
    call vimpire#window#ShowText(a:this, a:this.prompt . " ")
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

function! vimpire#repl#EnterHook(this)
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

    let server = vimpire#backend#server#Instance()

    let result = vimpire#backend#server#Execute(server,
                \ {"op": "check-syntax",
                \  "nspace": b:vimpire_namespace,
                \  "stdin": cmd})
    if result.value == v:false && result.stderr == ""
        call s:DoEnter()
    elseif result.stderr != ""
        call vimpire#ui#ShowResult(result)
    else
        let result = vimpire#backend#server#Execute(server,
                    \ {"op":    "repl",
                    \  "id":    a:this.id,
                    \  "run?":  v:true,
                    \  "stdin": cmd})
        call vimpire#window#ShowOutput(a:this, result)

        let a:this.historyDepth = 0
        let a:this.history = [cmd] + a:this.history

        let namespace = vimpire#backend#server#Execute(server,
                    \ {"op": "repl-namespace",
                    \  "id": a:this.id})
        let b:vimpire_namespace = namespace.value
        let a:this.prompt = namespace.value . "=>"

        call vimpire#repl#ShowPrompt(a:this)
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
