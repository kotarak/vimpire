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

module VimClojure.Client (
processMessage
) where

import Prelude
import System.IO
import Data.Map as M
import Data.ByteString.Char8 as B hiding (elem, hPutStr)

import VimClojure.Bencode

data ResponseMap = Response String String String String [String]

emptyString = toBencode ""
emptyList   = toBencode ([] :: [[Char]])

instance IsBencodeReadable ResponseMap where
    fromBencode (BMap this) =
        Response (fromBencode $ findWithDefault emptyString "out" this)
                 (fromBencode $ findWithDefault emptyString "err" this)
                 (fromBencode $ findWithDefault emptyString "value" this)
                 (fromBencode $ findWithDefault emptyString "ns" this)
                 (fromBencode $ findWithDefault emptyList "status" this)

instance IsBencodeWritable ResponseMap where
    toBencode (Response out err value ns status) =
        BMap $
        fromList [("out",    toBencode out),
                  ("err",    toBencode err),
                  ("value",  toBencode value),
                  ("ns",     toBencode ns),
                  ("status", toBencode status)]

emptyResponse = Response "" "" "" "" []

readToken stream = do
    token <- readBencode stream
    return $ fromBencode token

mergeToken (Response out err value ns status) (Response tokenOut tokenErr tokenValue tokenNS tokenStatus) =
    Response
        (out ++ tokenOut)
        (err ++ tokenErr)
        (if tokenValue == "" then value else tokenValue)
        (if tokenNS == "" then ns else tokenNS)
        (status ++ tokenStatus)

readResponse stream response = do
    token <- readToken stream
    let updatedResponse = mergeToken response token
    let (Response _ _ _ _ status) = updatedResponse
    if ("done" `elem` status) then do
        return updatedResponse
    else do
        readResponse stream updatedResponse

processMessage msg stream = do
    hPutStr stream msg
    hFlush stream
    readResponse stream $ emptyResponse
