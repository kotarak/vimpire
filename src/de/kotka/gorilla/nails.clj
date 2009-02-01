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
                                     make-reader)]
                       backend)
     [clojure.contrib.def :only (defvar)])
  (:import
     com.martiansoftware.nailgun.NGContext
     clojure.lang.LineNumberingPushbackReader
     (clojure.lang Var Compiler)
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
                    #(macroexpand %))
        eof       (Object.)]
    (binding [*ns* namespace]
      (doseq [expr (take-while #(not= % eof)
                               (repeatedly #(read *in* false eof)))]
        (-> expr expand prn)))))

; The Repl
(defvar *repls*
  (ref {})
  "A map holding the references to all running repls indexed by their repl id.")

(let [id (ref 0)]
  (defn repl-id
    "Get a new Repl id."
    []
    (dosync (alter id inc))))

(defstruct
  #^{:doc
  "The structure for the Repl interface. Holds the state of a Repl between
  invokations. The members correspond to the Vars as bound be with-binding."}
  repl
  :id :ns :warn-on-reflection :print-meta :print-length :print-level
  :compile-path :command-line-args :expr1 :expr2 :expr3 :exception)

(defn make-repl
  [id args]
  ; Make sure user namespace exists.
  (binding [*ns* *ns*]
    (in-ns 'user))
  (struct-map repl
              :id                 id
              :ns                 (the-ns 'user)
              :warn-on-reflection *warn-on-reflection*
              :print-meta         *print-meta*
              :print-length       *print-length*
              :print-level        *print-level*
              :compile-path       (System/getProperty
                                    "clojure.compile.path"
                                    "classes")
              :command-line-args  args
              :expr1              nil
              :expr2              nil
              :expr3              nil
              :exception          nil
              :line               0))

(defn root-cause
  [cause]
  (if-let [cause (.getCause cause)]
    (recur cause)
    cause))

(defnail ReplStart
  "Usage: ng de.kotka.gorilla.nails.ReplStart"
  []
  (let [id       (repl-id)
        the-repl (make-repl id (.getArgs nailContext))]
    (dosync (commute *repls* assoc id the-repl))
    (println id)))

(defnail ReplSend
  "Usage: ng de.kotka.gorilla.nails.ReplSend [options]"
  [[id   i "The id of the Repl to which the expression is sent.
                    -1 for one-shot." "-1"]
   [file f "Set the source name to the given file." "REPL"]
   [line l "Set the initial line number." "0"]]
  (let [id       (Integer/parseInt id)
        the-repl (if (= id -1)
                   (make-repl nil (.getArgs nailContext))
                   (*repls* id))]
    (if the-repl
      (try
        (Var/pushThreadBindings
          {Compiler/SOURCE file
           Compiler/LINE   (var-get Compiler/LINE)})
        (binding [*in*                 (-> nailContext
                                         .in
                                         InputStreamReader.
                                         (make-reader (if (= line "0")
                                                        (the-repl :line)
                                                        (Integer/parseInt 0))))
                  *ns*                 (the-repl :ns)
                  *warn-on-reflection* (the-repl :warn-on-reflection)
                  *print-meta*         (the-repl :print-meta)
                  *print-length*       (the-repl :print-length)
                  *print-level*        (the-repl :print-level)
                  *compile-path*       (the-repl :compile-path)
                  *command-line-args*  (the-repl :command-line-args)
                  *1                   (the-repl :expr1)
                  *2                   (the-repl :expr2)
                  *3                   (the-repl :expr3)
                  *e                   (the-repl :exception)]
          (try
            (let [eof   (Object.)
                  exprs (take-while #(not= % eof)
                                    (repeatedly #(read *in* false eof)))]
              (dorun exprs)
              (doseq [expr exprs]
                (let [value (eval expr)]
                  (prn value)
                  (when-not (= *1 value)
                    (set! *3 *2)
                    (set! *2 *1)
                    (set! *1 value)))))
            (catch Throwable e
              (-> (if (instance? clojure.lang.Compiler$CompilerException e)
                    e
                    (root-cause e))
                .toString
                println)
              (set! *e e)))
          (when-not (= id -1)
            (let [new-repl
                  (struct-map repl
                              :id                 id
                              :ns                 *ns*
                              :warn-on-reflection *warn-on-reflection*
                              :print-meta         *print-meta*
                              :print-length       *print-length*
                              :print-level        *print-level*
                              :compile-path       *compile-path*
                              :command-line-args  *command-line-args*
                              :expr1              *1
                              :expr2              *2
                              :expr3              *3
                              :exception          *e
                              :line               (dec (.getLineNumber *in*)))]
              (dosync (commute *repls* assoc id new-repl)))))
        (finally
          (Var/popThreadBindings)))
    (println "ERROR: no repl of that id"))))

(defnail ReplStop
  "Usage: ng de.kotka.gorilla.nails.ReplStop [options]"
  [[id   i "The id of the Repl to stop." ""]
   [all?   "Stop all Repls."]]
  (if all
    (dosync (ref-set *repls* {}))
    (dosync (alter *repls* dissoc (Integer/parseInt id)))))
