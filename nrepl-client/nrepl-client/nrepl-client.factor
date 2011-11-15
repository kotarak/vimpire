! Copyright 2011 (c) Meikel Brandmeyer.
! All rights reserved.
! 
! Permission is hereby granted, free of charge, to any person obtaining a copy
! of this software and associated documentation files (the "Software"), to deal
! in the Software without restriction, including without limitation the rights
! to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
! copies of the Software, and to permit persons to whom the Software is
! furnished to do so, subject to the following conditions:
! 
! The above copyright notice and this permission notice shall be included in
! all copies or substantial portions of the Software.
! 
! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
! IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
! FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
! AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
! LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
! OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
! THE SOFTWARE.

USING: accessors combinators command-line io io.encodings.utf8 io.sockets
    kernel math math.parser namespaces prettyprint sequences strings uuid ;
IN: nrepl-client

TUPLE: message id code stdin ;
: <message> ( code stdin -- message )
    uuid1 2over message boa swap drop swap drop ;

TUPLE: response id stdout stderr value nspace status ;
: <response> ( id -- response )
    "" "" "" "" "more" response boa ;

: read-response-chunk-count ( -- count )
    readln string>number ;

: read-trimmed-line ( -- line )
    readln rest but-last ;

: read-response-chunk ( response -- response )
    read-trimmed-line
    { { "id"     [ readln drop ] }
      { "out"    [ [ read-trimmed-line append ] change-stdout ] }
      { "err"    [ [ read-trimmed-line append ] change-stderr ] }
      { "value"  [ read-trimmed-line >>value ] }
      { "ns"     [ read-trimmed-line >>nspace ] }
      { "status" [ read-trimmed-line >>status ] }
    } case ;

: read-response-chunks ( response -- response )
    read-response-chunk-count [ read-response-chunk ] times ;

: read-response ( response -- response )
    [ dup status>> "done" = not ] [ read-response-chunks ] while ;

: print-response ( response -- )
   "{" write
   """ "stdout" : """"    write dup stdout>> write """",""" write
   """ "stderr" : """"    write dup stderr>> write """",""" write
   """ "value" : """"     write dup value>>  write """",""" write
   """ "namespace" : """" write dup nspace>> write """" """ write
   "}" print
   flush
   drop ;

: send-message ( message -- response )
    "3"          print
    """"id""""   print dup id>>    .
    """"code"""" print dup code>>  .
    """"in""""   print dup stdin>> .
    flush
    id>> <response> ;

: nrepl-session ( -- )
    readln lines <message>
    command-line get first2 string>number
    <inet> utf8 [
        send-message
        read-response
    ] with-client
    print-response ;
