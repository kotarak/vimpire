;-
; Copyright 2012 (c) Meikel Brandmeyer.
; All rights reserved.
;
; Permission is hereby granted, free of charge, to any person obtaining a copy
; of this software and associated documentation files (the "Software"), to deal
; in the Software without restriction, including without limitation the rights
; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the Software is
; furnished to do so, subject to the following conditions:
;
; The above copyright notice and this permission notice shall be included in
; all copies or substantial portions of the Software.
;
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
; THE SOFTWARE.

(ns vimclojure.connector.nailgun
  (:require
    vimclojure.nails
    [vimclojure.util :as util])
  (:import
    java.io.BufferedReader
    java.io.ByteArrayOutputStream
    java.io.InputStreamReader
    java.io.OutputStreamWriter
    java.io.PrintStream
    java.io.PrintWriter
    clojure.lang.LineNumberingPushbackReader
    vimclojure.nailgun.NGContext
    vimclojure.nailgun.NGServer
    vimclojure.nailgun.ThreadLocalInputStream
    vimclojure.nailgun.ThreadLocalPrintStream))

(defn start-server-thread
  "Start a nailgun server in a dedicated daemon thread. Host defaults
  to 127.0.0.1, port to 2113."
  ([]     (start-server-thread "127.0.0.1" 2113))
  ([host] (start-server-thread host 2113))
  ([host port]
   (doto (Thread. #(NGServer/main (into-array [(str host ":" port)])))
     (.setDaemon true)
     (.start))))

(defn- make-stream-set
  [in out err encoding]
  [(-> in (InputStreamReader. encoding) LineNumberingPushbackReader.)
   (-> out (OutputStreamWriter. encoding))
   (-> err (OutputStreamWriter. encoding) PrintWriter.)])

(defn- set-input-stream
  [#^ThreadLocalInputStream sys local]
  (let [old (.getInputStream sys)]
    (.init sys local)
    old))

(defn- set-output-stream
  [#^ThreadLocalPrintStream sys local]
  (let [old (.getPrintStream sys)]
    (.init sys local)
    old))

(defn nailgun-driver
  "Entry point for the nailgun connector."
  [#^NGContext ctx]
  (let [out          (ByteArrayOutputStream.)
        err          (ByteArrayOutputStream.)
        encoding     (System/getProperty "clojure.vim.encoding" "UTF-8")
        [clj-in clj-out clj-err] (make-stream-set (.in ctx) out err encoding)
        sys-in       (set-input-stream System/in (.in ctx))
        sys-out      (set-output-stream System/out (PrintStream. out))
        sys-err      (set-output-stream System/err (PrintStream. err))
        result       (binding [*in*  clj-in
                               *out* clj-out
                               *err* clj-err]
                       (try
                         (eval (read))
                         (catch Throwable e
                           (.printStackTrace e))))]
    (.flush clj-out)
    (.flush clj-err)
    (set-input-stream System/in sys-in)
    (set-output-stream System/out sys-out)
    (set-output-stream System/err sys-err)
    (let [output (.getBytes
                   (print-str
                     (util/clj->vim
                       {:value  result
                        :stdout (.toString out encoding)
                        :stderr (.toString err encoding)}))
                   encoding)]
      (.write (.out ctx) output 0 (alength output)))
    (.flush (.out ctx))))
