;-
; Copyright 2009 (c) Meikel Brandmeyer.
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

(clojure.core/ns de.kotka.gorilla.nails
  (:use
     (de.kotka.gorilla [util :only (with-command-line
                                     clj->vim
                                     resolve-and-load-namespace
                                     stream->seq)]
                       backend)
     [clojure.contrib.def :only (defvar)])
  (:require
     [de.kotka.gorilla.repl :as repl])
  (:import
     com.martiansoftware.nailgun.NGContext
     clojure.lang.LineNumberingPushbackReader
     (java.io InputStreamReader OutputStreamWriter PrintWriter)))

(defmacro defnail
  "Define a new Nail of the given name. A suitable class with the
  .nailMain method is generated. The arguments is a command line
  arguments specification vector suitable for with-command-line.
  The body will be installed as the body .nailMain method with the
  command-line arguments available according to the specification
  and the nailgun context as 'nailContext'."
  [nail usage arguments & body]
  `(do
     (gen-class
       :name    ~(symbol (str "de.kotka.gorilla.nails." (name nail)))
       :prefix  ~(symbol (str (name nail) "-"))
       :methods [#^{:static true}
                 [~'nailMain [com.martiansoftware.nailgun.NGContext] ~'void]]
       :main    false)

     (defn ~(symbol (str (name nail) "-nailMain"))
       ~usage
       [~(with-meta 'nailContext {:tag 'NGContext})]
       (binding [~'*in*  (-> ~'nailContext
                           .in
                           InputStreamReader.
                           LineNumberingPushbackReader.)
                 ~'*out* (-> ~'nailContext .out OutputStreamWriter.)
                 ~'*err* (-> ~'nailContext .err PrintWriter.)]
         (with-command-line (.getArgs ~'nailContext)
           ~usage
           ~arguments
           ~@body)))))

(defnail DocLookup
  "Usage: ng de.kotka.gorilla.nails.DocString [options] [--] symbol ..."
  [[namespace n "Lookup the symbols in the given namespace." "user"]
   symbols]
  (let [namespace (resolve-and-load-namespace namespace)
        symbols   (map symbol symbols)]
    (print (doc-lookup namespace symbols))
    (flush)))

(defnail JavadocPath
  "Usage: ng de.kotka.gorilla.nails.JavadocPath [options] [--] class ..."
  [[namespace n "Lookup the symbols in the given namespace." "user"]
   classes]
  (let [namespace      (resolve-and-load-namespace namespace)
        our-ns-resolve #(ns-resolve namespace %)]
    (doseq [path (map #(-> % symbol our-ns-resolve javadoc-path-for-class)
                      classes)]
      (println path))))

(defnail NamespaceOfFile
  "Usage: ng de.kotka.gorilla.nails.NamespaceOfFile [options]"
  [[file f "Read the named file. Use '-' for stdin." "-"]]
  (let [in     (if (not= file "-")
                 (-> file
                   java.io.FileInputStream.
                   java.io.InputStreamReader.
                   LineNumberingPushbackReader.)
                 *in*)
        eof    (Object.)
        of-interest '#{in-ns ns clojure.core/in-ns clojure.core/ns}
        in-seq (repeatedly #(read in false eof))
        candidate (first
                    (drop-while #(and (not= % eof)
                                      (or (not (instance? clojure.lang.ISeq %))
                                          (not (contains? of-interest
                                                          (first %)))))
                                in-seq))]
    (println
      (cond
        (= candidate eof)                                "user"
        ('#{ns clojure.core/ns} (first candidate))       (second candidate)
        ('#{in-ns clojure.core/in-ns} (first candidate)) (second (second candidate))
        :else                                            (println "user")))))

(defnail NamespaceInfo
  "Usage: ng de.kotka.gorilla.nails.NamespaceInfo [--] namespace ..."
  [namespaces]
  (println (clj->vim (map #(-> % symbol find-ns ns-info) namespaces))))

(defnail MacroExpand
  "Usage: ng de.kotka.gorilla.nails.MacroExpand [options]"
  [[namespace n "Lookup the symbols in the given namespace." "user"]
   [one?      o "Expand only the first macro."]]
  (let [namespace (resolve-and-load-namespace namespace)
        expand    (if one
                    #(macroexpand-1 %)
                    #(macroexpand %))]
    (binding [*ns* namespace]
      (doseq [expr (stream->seq *in*)]
        (-> expr expand prn)))))

(defnail Repl
  "Usage: ng de.kotka.gorilla.nails.Repl [options]"
  [[start? s "Start a new Repl."]
   [stop?  S "Stop the Repl of the given id."]
   [run?   r "Run the input in the Repl context of the given id."]
   [id     i "The id of the repl to act on." "-1"]
   [file   f "The filename to be set." "REPL"]
   [line   l "The initial line to be set." "0"]]
  (let [id   (Integer/parseInt id)
        line (Integer/parseInt line)]
    (cond
      start (println (repl/start))
      stop  (repl/stop id)
      run   (repl/run id file line))))

(defnail CheckSyntax
  "Usage: ng de.kotka.gorilla.nails.CheckSyntax"
  []
  (try
    (dorun (stream->seq *in*))
    (println true)
    (catch Exception e
      (println false))))
