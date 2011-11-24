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

USING: assocs combinators io io.encodings.ascii io.encodings.string
    io.encodings.utf8 kernel math math.parser sequences strings ;
IN: bencode

DEFER: read-bencode

: read-byte-count ( first-digit -- number )
     B{ } swap [ dup CHAR: : = ] [ suffix read1 ] until
     drop ascii decode string>number ;

: read-string ( first-digit -- string )
    read-byte-count read utf8 decode ;

: read-number ( -- number )
    B{ } read1 [ dup CHAR: e = ] [ suffix read1 ] until
    drop ascii decode string>number ;

: read-list ( -- seq )
    { } read-bencode
    [ dup ] [
        suffix
        read-bencode
    ] while
    drop ;

: read-map ( -- map )
    H{ } read-bencode
    [ dup ] [
        read-bencode swap pick set-at
        read-bencode
    ] while
    drop ;

: read-bencode ( -- token )
    read1
    { { [ dup CHAR: i = ] [ drop read-number ] }
      { [ dup CHAR: l = ] [ drop read-list ] }
      { [ dup CHAR: d = ] [ drop read-map ] }
      { [ dup CHAR: e = ] [ drop f ] }
      [ read-string ] } cond ;

DEFER: bencode

: bencode-byte-count ( seq -- bytes )
    length number>string ascii encode ;

: bencode-string ( string -- bytes )
    utf8 encode [ bencode-byte-count CHAR: : suffix ] keep append ;

: bencode-number ( number -- bytes )
    number>string ascii encode
    CHAR: i prefix
    CHAR: e suffix ;

: bencode-list ( seq -- bytes )
    B{ } [ bencode append ] reduce
    CHAR: l prefix
    CHAR: e suffix ;

: bencode-map ( seq -- bytes )
    unzip
    B{ } [ [ bencode ] dip bencode 3append ] 2reduce
    CHAR: d prefix
    CHAR: e suffix ;

: bencode ( thing -- bytes )
    { { [ dup string? ]   [ bencode-string ] }
      { [ dup number? ]   [ bencode-number ] }
      { [ dup sequence? ] [ bencode-list ] }
      { [ dup assoc? ]    [ bencode-map ] } } cond ;

: write-bencode ( thing -- )
    bencode write ;
