"-
" Copyright 2008 (c) Meikel Brandmeyer.
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
if !has("ruby")
    finish
endif

try
    if !gatekeeper#Guard("g:gorilla", "1.0.0")
        finish
    endif
catch /^Vim\%((\a\+)\)\=:E117/
    if exists("g:gorilla_loaded")
        finish
    endif
    let g:gorilla_loaded = "1.0.0"
endtry

let s:save_cpo = &cpo
set cpo&vim

function! GorillaSynItem()
    return synIDattr(synID(line("."), col("."), 0), "name")
endfunction

" The Gorilla Module
ruby <<EOF
require 'net/telnet'
require 'singleton'

module Gorilla
    PROMPT = "Gorilla=> "
    PROMPT_C = /^#{PROMPT}\z/
    PROMPT_B = /^#{PROMPT}/

    module Cmd
        def Cmd.bdelete()
            VIM.command("bdelete")
        end

        def Cmd.expand(str)
            return VIM.evaluate("expand('" + str + "')")
        end

        def Cmd.getpos(p)
            return VIM.evaluate("getpos('#{p}')").split(/\n/)
        end

        def Cmd.setpos(p, cursor)
            VIM.command("call setpos('#{p}', [#{cursor.join(",")}])")
        end

        def Cmd.getreg(r)
            return VIM.evaluate("getreg('#{r}')")
        end

        def Cmd.setreg(r, val)
            VIM.command("call setreg('#{r}', '#{val}')")
        end

        def Cmd.input(str)
            return VIM.evaluate("input('" + str + "')")
        end

        def Cmd.map(mode, remap, options, key, target)
            cmd = mode
            cmd = remap ? cmd + "map" : cmd + "noremap"
            cmd = options != "" ? cmd + " " + options : cmd
            cmd = cmd + " " + key
            cmd = cmd + " " + target
            VIM.command(cmd)
        end

        def Cmd.new()
            VIM.command("new")
        end

        def Cmd.normal(cmd)
            VIM.command("normal " + cmd)
        end

        def Cmd.resize(size)
            VIM.command("resize " + size.to_s)
        end

        def Cmd.set(option)
            VIM.set_option(option)
        end

        def Cmd.set_local(option)
            VIM.command("setlocal " + option)
        end

        def Cmd.setfiletype(type)
            VIM.command("setfiletype " + type)
        end
    end

    def Gorilla.setup_maps()
        Cmd.map("n", false, "<buffer> <silent>", "<LocalLeader>lw",
                ":ruby Gorilla.lookup_word(Gorilla.namespace_of($curbuf), Gorilla::Cmd.expand('<cword>'))<CR>")
        Cmd.map("n", false, "<buffer> <silent>", "<LocalLeader>ld",
                ":ruby Gorilla.lookup_word()<CR>")

        Cmd.map("n", false, "<buffer> <silent>", "<LocalLeader>et",
                ":ruby Gorilla.send_sexp(true)<CR>")
        Cmd.map("n", false, "<buffer> <silent>", "<LocalLeader>es",
                ":ruby Gorilla.send_sexp(false)<CR>")

        Cmd.map("n", false, "<buffer> <silent>", "<LocalLeader>me",
                ":ruby Gorilla.macro_expand(true)<CR>")
        Cmd.map("n", false, "<buffer> <silent>", "<LocalLeader>m1",
                ":ruby Gorilla.macro_expand(false)<CR>")

        Cmd.map("n", false, "<buffer> <silent>", "<LocalLeader>sr",
                ":ruby Gorilla::Repl.start()<CR>")
    end

    def Gorilla.with_saved_register(reg, &block)
        s = Cmd.getreg(reg)
        begin
            r = yield
        ensure
            Cmd.setreg(reg, s)
        end
        return r
    end

    def Gorilla.with_saved_position(&block)
        s = Cmd.getpos(".")
        begin
            r = yield
        ensure
            Cmd.setpos(".", s)
        end
        return r
    end

    def Gorilla.yank(r, how)
        Gorilla.with_saved_register(r) do
            VIM.command(how)
            Cmd.getreg(r)
        end
    end

    def Gorilla.connect()
        return Net::Telnet.new("Host" => "127.0.0.1", "Port" => 10123,
                               "Telnetmode" => false, "Prompt" => PROMPT_C)
    end

    def Gorilla.namespace_of(buf)
        len = buf.length
        i = 1
        while i < len
            if buf[i] =~ /^\((clojure\/)?(in-)?ns\s+'?([a-z][a-z0-9._-]*)/
                return $3
            end
            i += 1
        end

        return "user"
    end

    def Gorilla.with_connection(&block)
        result = nil
        t = Gorilla.connect()
        begin
            result = yield(t)
        ensure
            t.close
        end
        return result
    end

    def Gorilla.one_command_in_ns(ns, cmd)
        Gorilla.with_connection() do |t|
            t.waitfor(PROMPT_C)
            Gorilla.command(t, "(clojure/in-ns '" + ns + ")")
            result = Gorilla.command(t, cmd)
        end
    end

    def Gorilla.one_command(cmd)
        return Gorilla.one_command_in_ns("user", cmd)
    end

    def Gorilla.command(t, cmd)
        result = t.cmd(cmd + "\n")
        return result.sub(PROMPT_B, "")
    end

    def Gorilla.print_in_buffer(buf, msg)
        msg.split(/\n/).each { |l| buf.append(buf.length, l) }
    end

    def Gorilla.show_result(res)
        Cmd.new()
        Cmd.set_local("buftype=nofile")
        Cmd.set_local("bufhidden=delete")
        Cmd.set_local("noswapfile")
        Cmd.map("n", true, "<buffer> <silent>", "q", ":bd<CR>")
        Gorilla.print_in_buffer($curbuf, res)
        Cmd.normal("ggdd")
        Cmd.resize([$curbuf.length, 3].max)
    end

    def Gorilla.lookup_word(*args)
        ns, word = args

        ns = ns.nil? ? "user" : ns
        word = word.nil? ? Cmd.input("Symbol to look up? ") : word

        if word =~ /\//
            ns, word = word.split(/\//)
        end

        Gorilla.show_result(Gorilla.find_doc(ns, word))
    end

    DOCS = {}

    def Gorilla.find_doc(ns, word)
        pair = [ns, word]

        return DOCS[pair] if DOCS.has_key?(pair)

        ds = Gorilla.one_command_in_ns(pair[0], "(doc " + pair[1] + ")")
        DOCS[pair] = ds

        return ds
    end

    def Gorilla.extract_sexp(toplevel)
        flags = toplevel ? 'bWr' : 'bW'
        sexp = ""
        Gorilla.with_saved_position() do
            if VIM.evaluate("searchpairpos('(', '', ')', '#{flags}', 'GorillaSynItem() !~ \"clojureParen\\\\d\"') != [0, 0]") then
                sexp = Gorilla.yank('l', 'normal "ly%')
            end
        end
        return sexp
    end

    def Gorilla.send_sexp(toplevel)
        sexp = Gorilla.extract_sexp(toplevel)
        return if sexp == ""

        ns = Gorilla.namespace_of($curbuf)
        Gorilla.show_result(Gorilla.one_command_in_ns(ns, sexp))
    end

    def Gorilla.expand_macro(total)
        level = total ? "" : "-1"
        sexp = Gorilla.extrast_sexp(false)
        return if sexp == ""

        ns = Gorilla.namespace_of($curbuf)
        sexp = "(macroexpand#{level} '#{sexp})"
        Gorilla.show_result(Gorilla.one_command_in_ns(ns, sexp))
    end

    class Repl
        @@id = 1
        @@repls = {}

        def Repl.by_id(id)
            return @@repls[id]
        end

        def Repl.start()
            Cmd.new()
            Cmd.set_local("buftype=nofile")
            Cmd.setfiletype("clojure")

            id = Repl.new($curbuf).id

            Cmd.map("i", false, "<buffer> <silent>", "<CR>",
                    "<Esc>:ruby Gorilla::Repl.by_id(#{id}).enter_hook()<CR>")
            Cmd.map("i", false, "<buffer> <silent>", "<C-Up>",
                    "<C-O>:ruby Gorilla::Repl.by_id(#{id}).up_history()<CR>")
            Cmd.map("i", false, "<buffer> <silent>", "<C-Down>",
                    "<C-O>:ruby Gorilla::Repl.by_id(#{id}).down_history()<CR>")
        end

        def initialize(buf)
            @history = []
            @history_depth = []
            @buf = buf
            @conn = Gorilla.connect()
            @id = @@id

            @@id = @@id.next
            @@repls[id] = self

            Gorilla.print_in_buffer(@buf, @conn.waitfor(PROMPT_C))
            Cmd.normal("G$")
            VIM.command("startinsert!")
        end
        attr :id

        def repl_command(cmd)
            case cmd.chomp
            when ",close" then close()
            else return false
            end
            return true
        end

        def get_command()
            l = @buf.length
            cmd = @buf[l]
            while cmd !~ PROMPT_B
                l -= 1
                cmd = @buf[l] + "\n" + cmd
            end
            return cmd.sub(PROMPT_B, "")
        end

        def enter_hook()
            delim = nil
            pos = nil

            Gorilla.with_saved_position() do
                if VIM.evaluate("getline('.')") !~ PROMPT_B then
                    VIM.command("?#{PROMPT}")
                end
                Cmd.normal("0")

                l = VIM.evaluate("getline('.')")
                if l =~ /^#{PROMPT}\s*(\(|\[|#?\{)/ then
                    delim = $1.sub(/#/, "")
                    Cmd.normal("f#{delim}")
                    pos = Cmd.getpos(".")
                end
            end

            if delim.nil? then
                send(get_command())
                VIM.command("startinsert!")
                return
            end

            Cmd.normal("g_")

            if VIM.evaluate("GorillaSynItem()") == "clojureParen0" then
                submit = false

                Gorilla.with_saved_position() do
                    Cmd.normal("%")
                    submit = Cmd.getpos(".") == pos
                end

                if submit then
                    send(get_command())
                    VIM.command("startinsert!")
                    return
                end
            end

            # This is a hack to enter a new line and get indenting...
            @buf.append(@buf.length, "")
            Cmd.normal("G")
            Cmd.normal("ix")
            Cmd.normal("==x")
            VIM.command("startinsert!")
        end

        def send(cmd)
            return if repl_command(cmd)

            @history_depth = 0
            @history.unshift(cmd)

            Gorilla.print_in_buffer(@buf, Gorilla.command(@conn, cmd))
            Gorilla.print_in_buffer(@buf, PROMPT)
            Cmd.normal("G$")
        end

        def delete_last()
            Cmd.normal("gg")
            n = @buf.length
            while @buf[n] !~ PROMPT_B
                @buf.delete(n)
                n -= 1
            end
            @buf.delete(n)
        end

        def up_history()
            if @history.length > 0 && @history_depth < @history.length
                cmd = @history[@history_depth]
                @history_depth += 1

                delete_last()
                Gorilla.print_in_buffer(@buf, PROMPT + cmd)
            end
            Cmd.normal("G$")
        end

        def down_history()
            if @history_depth > 0 && @history.length > 0
                @history_depth -= 1
                cmd = @history[@history_depth]

                delete_last()
                Gorilla.print_in_buffer(@buf, PROMPT + cmd)
            elsif @history_depth == 0
                delete_last()
                Gorilla.print_in_buffer(@buf, PROMPT)
            end
            Cmd.normal("G$")
        end

        def close()
            @conn.close
            @@repls[@id] = nil
            Cmd.bdelete()
        end
    end
end
EOF

" Epilog
let &cpo = s:save_cpo
