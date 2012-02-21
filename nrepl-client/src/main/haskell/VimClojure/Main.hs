---
-- Copyright 2012 (c) Meikel Brandmeyer.
-- All rights reserved.
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

module Main where

import Prelude
import System.IO
import System.IO.Error (isEOFError)
import System.Environment (getArgs)
import Network (connectTo, withSocketsDo, PortID(..))
import Control.Exception (finally)
import Data.Map as M
import Data.ByteString.Char8 as B hiding (elem, hPutStr, getContents, putStrLn)

import VimClojure.Bencode
import VimClojure.Client

withConnection host port f = do
        sock <- connectTo host $ PortNumber port
        f sock `finally` hClose sock

main = withSocketsDo $ do
        msg             <- getContents
        [host, portStr] <- getArgs
        let port        =  fromIntegral (read portStr :: Int)
        result          <- withConnection host port $ processMessage msg
        writeBencode stdout result
