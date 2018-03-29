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

(ns vimpire.util
  (:require
    [clojure.pprint :as pprint]
    [clojure.stacktrace :as stacktrace])
  (:import
    clojure.lang.ISeq
    clojure.lang.LineNumberingPushbackReader
    clojure.lang.LispReader$ReaderException
    java.io.StringReader))

; Common helpers
(defn str-wrap
  "Wrap the given string into the given separators."
  ([string sep]
   (str-wrap string sep sep))
  ([string before after]
   (str before string after)))

(defn str-cat
  "Concatenate the given collection to a string, separating the
  collection's items with the given separator."
  [coll sep]
  (apply str (interpose sep coll)))

(defn safe-ns-resolve
  [nspace sym]
  (try
    (ns-resolve nspace sym)
    (catch ClassNotFoundException _ nil)))

(defn safe-var-get
  [the-var]
  (when (.isBound the-var)
    (var-get the-var)))

; Namespace helpers
(defn resolve-and-load-namespace
  "Loads and returns the namespace named by the given string or symbol."
  [namespace]
  ; Special case for user: make sure it always exists for the Repl.
  (binding [*ns* *ns*]
    (in-ns 'user))
  (let [namespace (if (symbol? namespace) namespace (symbol namespace))]
    (try
      (the-ns namespace)
      (catch Exception _
        (require namespace)
        (the-ns namespace)))))

(defn stream->seq
  "Turns a given stream into a seq of Clojure forms read from the stream."
  [stream]
  (let [eof (Object.)
        rdr (fn [] (read stream false eof))]
    (take-while #(not= % eof) (repeatedly rdr))))

; Pretty printing.
(defn pretty-print
  "Print the given form in a pretty way."
  [form]
  (pprint/pprint form))

(defn pretty-print-code
  "Print the given form in a pretty way.
  Uses the *code-dispatch* formatting."
  [form]
  (pprint/with-pprint-dispatch pprint/code-dispatch
    (pprint/pprint form)))

(defn pretty-print-stacktrace
  "Print the stacktrace of the given Throwable. Tries clj-stacktrace,
  clojure.stacktrace and clojure.contrib.stacktrace in that order. Otherwise
  defaults to simple printing."
  [e]
  (stacktrace/print-stack-trace e))

(defn pretty-print-causetrace
  "Print the causetrace of the given Throwable. Tries clj-stacktrace,
  clojure.stacktrace and clojure.contrib.stacktrace in that order. Otherwise
  defaults to simple printing."
  [e]
  (stacktrace/print-cause-trace e))

(defn namespace-of-file
  [content]
  (let [of-interest '#{in-ns ns clojure.core/in-ns clojure.core/ns}
        in-seq      (-> content
                      StringReader.
                      LineNumberingPushbackReader.
                      stream->seq)
        candidate   (first
                      (drop-while #(or (not (instance? ISeq %))
                                       (not (contains? of-interest (first %))))
                                  in-seq))]
    (cond
      (not (instance? ISeq candidate))                 "user"
      ('#{ns clojure.core/ns} (first candidate))       (name (second candidate))
      ('#{in-ns clojure.core/in-ns} (first candidate)) (-> candidate
                                                         second
                                                         second
                                                         name))))

(defn check-syntax
  [nspace content]
  (let [nspace (resolve-and-load-namespace nspace)]
    (binding [*ns* nspace]
      (try
        (let [eof (Object.)
              rdr (LineNumberingPushbackReader. (StringReader. content))]
          (loop [x nil]
            (if (identical? x eof)
              true
              (recur (read rdr false eof)))))
        (catch LispReader$ReaderException exc
          (let [e (.getCause exc)]
            (if (.startsWith (.getMessage e) "EOF while reading")
              false
              (throw exc))))))))
