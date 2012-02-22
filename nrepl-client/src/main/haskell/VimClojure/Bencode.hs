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

module VimClojure.Bencode (
readBencode,
writeBencode,
toBencode,
fromBencode,
IsBencodeReadable,
IsBencodeWritable,
Bencode(BString, BInt, BList, BMap)
) where

import Prelude hiding (readList)
import System.IO
import Data.Map as M hiding (map)
import Data.String
import Data.ByteString.Char8 as B hiding (readInt, map, replicate, hPutStr, head)

data Bencode = BString B.ByteString
    | BInt Int
    | BList [Bencode]
    | BMap (M.Map [Char] Bencode)

class IsBencodeReadable a where
    fromBencode     :: Bencode -> a
    fromBencodeList :: Bencode -> [a]
    fromBencodeList (BList l) = map fromBencode l

instance IsBencodeReadable Char where
    fromBencode     (BString s) = head $ B.unpack s
    fromBencodeList (BString s) = B.unpack s

instance IsBencodeReadable Int where
    fromBencode (BInt n) = n

instance (IsBencodeReadable a) => IsBencodeReadable [a] where
    fromBencode = fromBencodeList

mapEntryFromBencode (k, v) = (k, fromBencode v)

instance (IsBencodeReadable a) => IsBencodeReadable (M.Map [Char] a) where
    fromBencode (BMap m) = M.fromList $ map mapEntryFromBencode $ toList m

readUntil delim readToken stream = do
    ch <- hLookAhead stream
    if ch == delim then do
        _ <- hGetChar stream
        return []
    else do
        h <- readToken stream
        t <- readUntil delim readToken stream
        return $ h:t

readByteCount stream = do
    digits <- readUntil ':' hGetChar stream
    return (read digits :: Int)

readByteString stream = do
    byteCount <- readByteCount stream
    B.hGet stream byteCount

readString stream = do
    bytes <- readByteString stream
    return $ B.unpack bytes

readInt stream = do
    _      <- hGetChar stream
    digits <- readUntil 'e' hGetChar stream
    return (read digits :: Int)

readList stream = do
    _        <- hGetChar stream
    readUntil 'e' readBencode stream

readMapEntry stream = do
    k <- readString stream
    v <- readBencode stream
    return (k, v)

readMap stream = do
    _     <- hGetChar stream
    items <- readUntil 'e' readMapEntry stream
    return $ M.fromList items

readBencode stream = do
    ch <- hLookAhead stream
    case ch of
        'i' -> do
            n <- readInt stream
            return $ BInt n
        'l' -> do
            l <- readList stream
            return $ BList l
        'd' -> do
            d <- readMap stream
            return $ BMap d
        _   -> do
            s <- readByteString stream
            return $ BString s

class IsBencodeWritable a where
    toBencode     :: a -> Bencode
    toBencodeList :: [a] -> Bencode
    toBencodeList l = BList $ map toBencode l

instance IsBencodeWritable Char where
    toBencode     = BString . B.pack . replicate 1
    toBencodeList = BString . B.pack

instance IsBencodeWritable Integer where
    toBencode = BInt . fromInteger

instance (IsBencodeWritable a) => IsBencodeWritable [a] where
    toBencode = toBencodeList

mapEntryToBencode (k, v) = (k, toBencode v)

instance (IsBencodeWritable b) => IsBencodeWritable (M.Map [Char] b) where
    toBencode = BMap . fromList . map mapEntryToBencode . toList

doWriteBencode stream (BString s) = do
    hPutStr stream $ show $ B.length s
    hPutChar stream ':'
    hPut stream s

doWriteBencode stream (BInt n) = do
    hPutChar stream 'i'
    hPutStr stream $ show n
    hPutChar stream 'e'

doWriteBencode stream (BList l) = do
    hPutChar stream 'l'
    mapM_ (doWriteBencode stream) l
    hPutChar stream 'e'

doWriteBencode stream (BMap m) = do
    hPutChar stream 'd'
    mapM_ (doWriteMapEntry stream) $ toList m
    hPutChar stream 'e'

doWriteMapEntry stream (k, v) = do
    doWriteBencode stream $ toBencode k
    doWriteBencode stream v

writeBencode stream x = doWriteBencode stream $ toBencode x
