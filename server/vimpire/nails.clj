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
    [vimpire.backend :as backend]
    [vimpire.util    :as util]
    [clojure.pprint  :as pprint]
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

(defn doc-lookup
  [nspace sym]
  (let [nspace (util/resolve-and-load-namespace nspace)]
    (backend/doc-lookup nspace (symbol sym))))

(defn find-doc
  [query]
  (backend/find-documentation query))

(defn javadoc-path
  [nspace sym]
  (let [nspace (util/resolve-and-load-namespace nspace)]
    (->> (symbol sym)
      (ns-resolve nspace)
      backend/javadoc-path-for-class)))

(defn source-lookup
  [nspace sym]
  (let [nspace (util/resolve-and-load-namespace nspace)]
    (->> (symbol sym)
      (ns-resolve nspace)
      backend/get-source)))

(defn source-location
  [nspace sym]
  (let [nspace (util/resolve-and-load-namespace nspace)]
    (->> (symbol sym)
      (ns-resolve nspace)
      backend/source-position)))

(defn dynamic-highlighting
  [nspace]
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
        vars      (clojure.set/difference vars fns)
        strfirst  (comp str first)]
    (hash-map "Func"     (mapv strfirst fns)
              "Macro"    (mapv strfirst macros)
              "Variable" (mapv strfirst vars))))

(defn namespace-of-file
  [content]
  (let [of-interest '#{in-ns ns clojure.core/in-ns clojure.core/ns}
        in-seq      (-> content
                      StringReader.
                      LineNumberingPushbackReader.
                      util/stream->seq)
        candidate   (first
                      (drop-while #(or (not (instance? clojure.lang.ISeq %))
                                       (not (contains? of-interest (first %))))
                                  in-seq))]
    (cond
      (not (instance? clojure.lang.ISeq candidate))    "user"
      ('#{ns clojure.core/ns} (first candidate))       (name (second candidate))
      ('#{in-ns clojure.core/in-ns} (first candidate)) (-> candidate
                                                         second
                                                         second
                                                         name))))

(defn namespace-info
  [content]
  (map #(-> % symbol find-ns backend/ns-info)
       (-> content StringReader. line-seq)))

(defn macro-expand
  [nspace form one?]
  (let [nspace (util/resolve-and-load-namespace nspace)
        expand (if one?
                 #(macroexpand-1 %)
                 #(macroexpand %))]
    (binding [*ns* nspace]
      (with-out-str (-> (read-string form) expand pprint/pprint)))))

(defn check-syntax
  [nspace content]
  (let [nspace (util/resolve-and-load-namespace nspace)]
    (binding [*ns* nspace]
      (try
        (let [eof (Object.)
              rdr (LineNumberingPushbackReader. (StringReader. content))]
          (loop [x nil]
            (if (identical? x eof)
              true
              (recur (read rdr false eof)))))
        (catch clojure.lang.LispReader$ReaderException exc
          (let [e (.getCause exc)]
            (if (.startsWith (.getMessage e) "EOF while reading")
              false
              (throw exc))))))))

(defn complete
  [nspace prefix base]
  (let [nspace      (util/resolve-and-load-namespace nspace)
        prefix      (symbol prefix)
        to-complete (util/decide-completion-in nspace prefix base)
        completions (mapcat #(backend/complete % nspace prefix base)
                            to-complete)]
    (mapv #(apply util/make-completion-item %) completions)))

(defn run-tests
  [nspace all?]
  (when (not= "user" nspace)
    (if all?
      (require :reload-all (symbol nspace))
      (require :reload (symbol nspace))))
  (with-out-str
    (binding [clojure.test/*test-out* *out*]
      (clojure.test/run-tests (symbol nspace)))))
