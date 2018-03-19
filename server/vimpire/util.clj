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
    [clojure.stacktrace :as stacktrace]))

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

(defn splitted-match
  "Splits pattern and candidate at the given delimiters and matches
  the parts of the pattern with the parts of the candidate. Match
  means „startsWith“ here."
  [pattern candidate delimiters]
  (if-let [delimiters (seq delimiters)]
    (let [delim           (first delimiters)
          pattern-split   (.split pattern delim)
          candidate-split (.split candidate delim)]
      (and (<= (count pattern-split) (count candidate-split))
           (reduce #(and %1 %2) (map #(splitted-match %1 %2 (rest delimiters))
                                     pattern-split
                                     candidate-split))))
    (.startsWith candidate pattern)))

(defn safe-ns-resolve
  [nspace sym]
  (try
    (ns-resolve nspace sym)
    (catch ClassNotFoundException _ nil)))

(defn safe-var-get
  [the-var]
  (when (.isBound the-var)
    (var-get the-var)))

(defn decide-completion-in
  [nspace prefix base]
  (let [nom (name prefix)]
    (cond
      (pos? (count nom))
      (cond
        (or (contains? (set (map ns-name (all-ns))) prefix)
            (contains? (ns-aliases nspace) prefix))
        [:local-var]

        (or (Character/isUpperCase (char (first nom)))
            (try
              (instance? Class (ns-resolve nspace prefix))
              (catch ClassNotFoundException _ false)))
        [:static-field]

        :else (throw (Exception. "Cannot determine type of prefix")))

      (pos? (count base))
      (cond
        (Character/isUpperCase (char (first base))) [:import]
        (< -1 (.indexOf base (int \.)))             [:namespace]
        :else [:full-var :alias :namespace])

      :else
      [:full-var :alias :namespace])))

(defn- type-of-completion
  [thing]
  (cond
    (instance? clojure.lang.Namespace thing)   "n"
    (instance? java.lang.reflect.Field thing)  "S"
    (instance? java.lang.reflect.Method thing) "M"
    (class? thing)        "c"
    (coll? thing)         (recur (first thing))
    (:macro (meta thing)) "m"
    :else                 (let [value (safe-var-get thing)]
                            (cond
                              (instance? clojure.lang.MultiFn value) "f"
                              (fn? value) "f"
                              :else       "v"))))

(defmulti make-completion-item
  "Create a completion item for Vim's popup-menu."
  (fn [_ the-thing] (type-of-completion the-thing)))

(defmethod make-completion-item "n"
  [the-name the-space]
  (let [docs (-> the-space meta :doc)
        info (str " " the-name \newline
                  (when docs (str \newline docs)))]
    (hash-map "word" the-name
              "kind" "n"
              "menu" ""
              "info" info)))

(defmethod make-completion-item "c"
  [the-name _]
  (hash-map "word" the-name
            "kind" "c"
            "menu" ""
            "info" ""))

(defmethod make-completion-item "M"
  [the-name the-methods]
  (let [nam      (name (read-string the-name))
        rtypes   (map #(-> % .getReturnType .getSimpleName) the-methods)
        arglists (map (fn [m]
                        (let [types (.getParameterTypes m)]
                          (vec (map #(.getSimpleName %) types))))
                      the-methods)
        info     (apply str "  " the-name \newline \newline
                        (map #(str "  " %1 " " nam
                                   (str-wrap (str-cat %2 ", ") \( \))
                                   \; \newline)
                             rtypes arglists))]
    (hash-map "word" the-name
              "kind" "M"
              "menu" (print-str arglists)
              "info" info)))

(defmethod make-completion-item "S"
  [the-name [the-field]]
  (let [nam  (name (read-string the-name))
        menu (-> the-field .getType .getSimpleName)
        info (str "  " the-name \newline \newline
                  "  " menu " " the-name \newline)]
    (hash-map "word" the-name
              "kind" "S"
              "menu" menu
              "info" info)))

(defmethod make-completion-item "v"
  [the-name the-var]
  (let [info (str "  " the-name \newline)
        info (if-let [docstring (-> the-var meta :doc)]
               (str info \newline "  " docstring)
               info)]
    (hash-map "word" the-name
              "kind" "v"
              "menu" (pr-str (try
                               (type @the-var)
                               (catch IllegalStateException _
                                 "<UNBOUND>")))
              "info" info)))

(defn- make-completion-item-fm
  [the-name the-fn typ]
  (let [info     (str "  " the-name \newline)
        metadata (meta the-fn)
        arglists (:arglists metadata)
        info     (if arglists
                   (reduce #(str %1 "  " (prn-str (cons (symbol the-name) %2)))
                           (str info \newline) arglists)
                   info)
        info     (if-let [docstring (:doc metadata)]
                   (str info \newline "  " docstring)
                   info)]
    (hash-map "word" the-name
              "kind" typ
              "menu" (pr-str arglists)
              "info" info)))

(defmethod make-completion-item "f"
  [the-name the-fn]
  (make-completion-item-fm the-name the-fn "f"))

(defmethod make-completion-item "m"
  [the-name the-fn]
  (make-completion-item-fm the-name the-fn "m"))

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
