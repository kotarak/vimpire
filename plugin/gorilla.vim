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

    def Gorilla.connect()
        return Net::Telnet.new("Host" => "127.0.0.1", "Port" => 10123,
                               "Telnetmode" => false, "Prompt" => PROMPT_C)
    end

    def Gorilla.one_command(cmd)
        result = ""
        t = Gorilla.connect()
        begin
            t.waitfor(PROMPT_C)
            result = Gorilla.command(t, cmd)
        ensure
            t.close
        end
        return result
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
        Cmd.set("buftype=nofile")
        Cmd.map("n", true, "<buffer> <silent>", "q", ":bd<CR>")
        Gorilla.print_in_buffer($curbuf, res)
    end

    DOCS = {}

    def Gorilla.doc(word)
        if DOCS.has_key?(word)
            return DOCS[word]
        end
        return Gorilla.one_command("(doc " + word + ")")
    end

    class Repl
        @@id = 1
        @@repls = {}

        def Repl.by_id(id)
            return @@repls[id]
        end

        def Repl.start()
            Cmd.new()
            Cmd.set("buftype=nofile")
            Cmd.setfiletype("clojure")

            id = Repl.new($curbuf).id

            Cmd.map("i", false, "<buffer> <silent>", "<C-CR>",
                    "<C-O>:ruby Gorilla::Repl.by_id(#{id}).send()<CR>")
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
        end
        attr :id

        def send()
            l = @buf.length
            cmd = @buf[l]
            while cmd !~ PROMPT_B
                l -= 1
                cmd = @buf[l] + "\n" + cmd
            end
            cmd = cmd.sub(PROMPT_B, "")

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
