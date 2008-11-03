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
    PROMPT = /^Gorilla=> \z/n

    def Gorilla.connect()
        return Net::Telnet.new("Host" => "127.0.0.1", "Port" => 10123,
                               "Telnetmode" => false, "Prompt" => PROMPT)
    end

    def Gorilla.one_command(cmd)
        result = ""
        t = Gorilla.connect()
        begin
            t.waitfor(PROMPT)
            result = Gorilla.command(t, cmd)
        ensure
            t.close
        end
        return result
    end

    def Gorilla.command(t, cmd)
        result = t.cmd(cmd + "\n")
        return result.sub(PROMPT, "")
    end

    def Gorilla.print_in_buffer(buf, msg)
        msg.split(/\n/).each { |l| buf.append(buf.length, l) }
    end

    def Gorilla.show_result(res)
        VIM.command("new")
        VIM.set_option("buftype=nofile")
        VIM.command("nmap <buffer> <silent> q :bd<CR>")
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
        include Singleton

        def initialize()
            @history = []
            @history_depth = []
            @buf = $curbuf
            @conn = Gorilla.connect()

            Gorilla.print_in_buffer(@buf, @conn.waitfor(PROMPT))
            VIM.command("normal G$")
        end

        def send_off()
            l = @buf.length
            cmd = @buf[l]
            while cmd !~ /^Gorilla=> /
                l -= 1
                cmd = @buf[l] + "\n" + cmd
            end
            cmd = cmd.sub(/^Gorilla=> /, "")

            @history_depth = 0
            @history.unshift(cmd)

            Gorilla.print_in_buffer(@buf, Gorilla.command(@conn, cmd))
            Gorilla.print_in_buffer(@buf, "Gorilla=> ")
            VIM.command("normal G$")
        end

        def delete_last()
            VIM.command("normal gg")
            n = @buf.length
            while @buf[n] !~ /^Gorilla=> /
                @buf.delete(n)
                n -= 1
            end
            @buf.delete(n)
        end

        def go_up_in_history()
            if @history.length > 0 && @history_depth < @history.length
                cmd = @history[@history_depth]
                @history_depth += 1

                delete_last()
                Gorilla.print_in_buffer(@buf, "Gorilla=> " + cmd)
            end
            VIM.command("normal G$")
        end

        def go_down_in_history()
            if @history_depth > 0 && @history.length > 0
                @history_depth -= 1
                cmd = @history[@history_depth]

                delete_last()
                Gorilla.print_in_buffer(@buf, "Gorilla=> " + cmd)
            elsif @history_depth == 0
                delete_last()
                Gorilla.print_in_buffer(@buf, "Gorilla=> ")
            end
            VIM.command("normal G$")
        end

        def close()
            @conn.close
        end
    end
end
EOF

" Epilog
let &cpo = s:save_cpo
