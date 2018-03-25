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

if !exists("g:vimpire_dynamic_highlighting")
    let g:vimpire_dynamic_highlighting = v:true
endif

function! s:InitBufferCallback(buffer, nspace)
    call setbufvar(a:buffer, "vimpire_namespace", a:nspace)
    if exists("g:vimpire_dynamic_highlighting")
                \ && g:vimpire_dynamic_highlighting
        call vimpire#backend#dynhighlight#DynamicHighlighting()
    endif
endfunction

function! vimpire#backend#InitBuffer(...)
    if exists("b:vimpire_namespace")
        return
    endif

    if !&previewwindow
        " Get the namespace of the buffer.
        try
            let buffer  = bufnr("%")
            let content = join(getbufline(buffer, 1, line("$")), "\n")
            let server  = vimpire#connection#ForBuffer()
            call vimpire#connection#Action(
                        \ server,
                        \ ":vimpire/namespace-of-file",
                        \ {":content": content},
                        \ {"eval": function("s:InitBufferCallback", [buffer])})
        catch /Vimpire: No connection found/
            " Do nothing. Fail silently in this case.
        catch /.*/
            if a:000 == []
                call vimpire#ui#ReportError(
                            \ "Could not determine the Namespace of the file.\n\n"
                            \ . "This might have different reasons. Please check, that the server\n"
                            \ . "is running and that the file does not contain syntax errors. The\n"
                            \ . "interactive features will not be enabled.\n"
                            \ . "\nReason:\n" . v:exception)
            endif
        endtry
    endif
endfunction

" Epilog
let &cpo = s:save_cpo
