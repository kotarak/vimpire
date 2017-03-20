;-
; Copyright 2009-2017 © Meikel Brandmeyer.
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

(ns vimpire.nails
  (:require
    [clojure.pprint :as pprint]
    clojure.set
    clojure.test)
  (:import
    java.io.BufferedReader
    java.io.ByteArrayOutputStream
    java.io.InputStreamReader
    java.io.OutputStreamWriter
    java.io.PrintStream
    java.io.PrintWriter
    java.io.StringReader
    clojure.lang.LineNumberingPushbackReader))

(alias 'json    'vimpire.clojure.data.json)
(alias 'backend 'vimpire.backend)
(alias 'repl    'vimpire.repl)
(alias 'util    'vimpire.util)

(defn- make-stream-set
  [in out err encoding]
  ; FIXME: encoding for stdin?
  [(-> in  StringReader. LineNumberingPushbackReader.)
   (-> out (OutputStreamWriter. encoding))
   (-> err (OutputStreamWriter. encoding) PrintWriter.)])

(defn doc-lookup
  [{:strs [nspace sym] :or {nspace "user"}}]
  (let [nspace (util/resolve-and-load-namespace nspace)]
    (backend/doc-lookup nspace (symbol sym))))

(defn find-doc
  [{:strs [query]}]
  (backend/find-documentation query))

(defn javadoc-path
  [{:strs [nspace sym] :or {nspace "user"}}]
  (let [nspace (util/resolve-and-load-namespace nspace)]
    (->> (symbol sym)
      (ns-resolve nspace)
      backend/javadoc-path-for-class)))

(defn source-lookup
  [{:strs [nspace sym] :or {nspace "user"}}]
  (let [nspace (util/resolve-and-load-namespace nspace)]
    (->> (symbol sym)
      (ns-resolve nspace)
      backend/get-source
      println)))

(defn meta-lookup
  [{:strs [nspace sym] :or {nspace "user"}}]
  (let [nspace (util/resolve-and-load-namespace nspace)]
    (->> (symbol sym)
      (ns-resolve nspace)
      meta
      pprint/pprint)))

(defn source-location
  [{:strs [nspace sym] :or {nspace "user"}}]
  (let [nspace (util/resolve-and-load-namespace nspace)]
    (-> (symbol sym)
      (ns-resolve nspace)
      backend/source-position)))

(defn dynamic-highlighting
  [{:strs [nspace]}]
  (let [c-c       (the-ns 'clojure.core)
        the-space (util/resolve-and-load-namespace nspace)
        refers    (remove #(= c-c (-> % second meta :ns)) (ns-refers the-space))
        aliases   (for [[the-alias the-alias-space] (ns-aliases the-space)
                        [the-sym the-var] (ns-publics the-alias-space)]
                    [(symbol (name the-alias) (name the-sym)) the-var])
        namespaces (for [the-namespace     (remove #{c-c} (all-ns))
                         [the-sym the-var] (ns-publics the-namespace)]
                     [(symbol (name (ns-name the-namespace)) (name the-sym))
                      the-var])
        vars      (set (concat refers aliases namespaces))
        macros    (set (filter #(-> % second meta :macro) vars))
        vars      (clojure.set/difference vars macros)
        fns       (set (filter #(let [v (util/safe-var-get (second %))]
                                  (or (fn? v)
                                      (instance? clojure.lang.MultiFn v)))
                               vars))
        vars      (clojure.set/difference vars fns)]
    (hash-map "Func"     (map first fns)
              "Macro"    (map first macros)
              "Variable" (map first vars))))

(defn namespace-of-file
  [_ctx]
  (let [of-interest '#{in-ns ns clojure.core/in-ns clojure.core/ns}
        in-seq      (util/stream->seq *in*)
        candidate   (first
                      (drop-while #(or (not (instance? clojure.lang.ISeq %))
                                       (not (contains? of-interest (first %))))
                                  in-seq))]
    (cond
      (not (instance? clojure.lang.ISeq candidate))    "user"
      ('#{ns clojure.core/ns} (first candidate))       (second candidate)
      ('#{in-ns clojure.core/in-ns} (first candidate)) (-> candidate
                                                         second
                                                         second))))

(defn namespace-info
  [{:strs [input]}]
  (map #(-> % symbol find-ns backend/ns-info)
       (-> input StringReader. BufferedReader. line-seq)))

(defn macro-expand
  [{:strs [nspace one?] :or {nspace "user" one? true}}]
  (let [nspace (util/resolve-and-load-namespace nspace)
        expand (if one?
                 #(macroexpand-1 %)
                 #(macroexpand %))]
    (binding [*ns* nspace]
      (-> (read) expand pprint/pprint))))

(defn repl
  [{:strs [start? stop? run?]
    :or   {start? false stop? false run? true}
    :as   ctx}]
  (cond
    start? (repl/start ctx)
    stop?  (repl/stop ctx)
    run?   (repl/run ctx)))

(defn repl-namespace
  [{:strs [id]}]
  (-> @repl/*repls*
    (get-in [id :ns] 'user)
    ns-name
    name))

(defn check-syntax
  [{:strs [nspace] :or {nspace "user"}}]
  (let [nspace (util/resolve-and-load-namespace nspace)]
    (binding [*ns* nspace]
      (try
        (let [eof (Object.)]
          (loop [x nil]
            (if (identical? x eof)
              true
              (recur (read *in* false eof)))))
        (catch clojure.lang.LispReader$ReaderException exc
          (let [e (.getCause exc)]
            (if (.startsWith (.getMessage e) "EOF while reading")
              false
              (throw exc))))))))

(defn complete
  [{:strs [nspace prefix base] :or {nspace "user" prefix ""}}]
  (let [nspace      (util/resolve-and-load-namespace nspace)
        prefix      (symbol prefix)
        to-complete (util/decide-completion-in nspace prefix base)
        completions (mapcat #(backend/complete % nspace prefix base)
                            to-complete)]
    (map #(apply util/make-completion-item %) completions)))

(defn run-tests
  [{:strs [nspace all?] :or {nspace "user" all? true}}]
  (when (not= "user" nspace)
    (if all?
      (require :reload-all (symbol nspace))
      (require :reload (symbol nspace))))
  (binding [clojure.test/*test-out* *out*]
    (clojure.test/run-tests (symbol nspace)))
  nil)

(defn nail-server
  []
  (binding [*ns* *ns*]
    (in-ns 'user)
    (refer-clojure)
    (use 'clojure.repl))
  (println "Nail server ready!")
  (flush)
  (loop []
    (let [eof (Object.)
          msg (json/read *in* :eof-error? false :eof-value eof)]
      (when (not= msg eof)
        (let [[msg-id ctx]  msg
              op            (get ctx "op")
              [nspace nail] (.split ^String op "/")
              nail          (ns-resolve (symbol nspace) (symbol nail))
              out           (ByteArrayOutputStream.)
              err           (ByteArrayOutputStream.)
              encoding      (System/getProperty "clojure.vim.encoding" "UTF-8")
              [clj-in clj-out clj-err]
              (make-stream-set (get ctx "stdin" "") out err encoding)
              result        (binding [*in*  clj-in
                                      *out* clj-out
                                      *err* clj-err]
                              (try
                                (nail (dissoc ctx "op" "stdin"))
                                (catch Throwable e
                                  (binding [*out* *err*]
                                    (prn e)))))]
          (.flush clj-out)
          (.flush clj-err)
          (json/write [msg-id {:value  result
                               :stdout (.toString out encoding)
                               :stderr (.toString err encoding)}]
                      *out*)
          (flush)
          (recur))))))
