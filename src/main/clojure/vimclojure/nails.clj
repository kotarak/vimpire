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

(ns vimclojure.nails
  (:require
    (vimclojure [repl :as repl]
                [util :as util]
                [backend :as backend]))
  (:import
    java.io.BufferedReader
    java.io.StringWriter
    java.io.PrintWriter
    com.martiansoftware.nailgun.NGContext
    com.martiansoftware.nailgun.NGServer))

(defn start-server-thread
  "Start a nailgun server in a dedicated daemon thread. host defaults
  to 127.0.0.1, port to 2113."
  ([]     (start-server-thread "127.0.0.1" 2113))
  ([host] (start-server-thread host 2113))
  ([host port]
   (doto (Thread. #(NGServer/main (into-array [(str host ":" port)])))
     (.setDaemon true)
     (.start))))

(defn nail-driver
  "Driver for the defnail macro."
  [#^NGContext ctx nail]
  (let [out (StringWriter.)
        err (StringWriter.)
        ret (binding [*out* (PrintWriter. out)
                      *err* (PrintWriter. err)]
              (try
                (nail ctx)
                (catch Exception e
                  (.printStackTrace e *err*))))]
    (println
      (util/clj->vim {:value  ret
                      :stdout (.toString out)
                      :stderr (.toString err)}))
    (flush)))

(defmacro defnail
  "Define a new Nail of the given name. The arguments is a command line
  arguments specification vector suitable for with-command-line. The body
  will be installed as the body of the nail with the command-line arguments
  available according to the specification and the nailgun context as
  'nailContext'."
  [nail usage arguments & body]
  `(defn ~nail
     [ctx#]
     (nail-driver ctx#
                  (fn [~(with-meta 'nailContext {:tag `NGContext})]
                    (util/with-command-line (next (.getArgs ~'nailContext))
                      ~usage
                      ~arguments
                      ~@body)))))

(defnail DocLookup
  "Usage: ng vimclojure.nails.DocString [options] symbol ..."
  [[nspace n "Lookup the symbols in the given namespace." "user"]]
  (let [nspace  (util/resolve-and-load-namespace nspace)]
    (backend/doc-lookup nspace (read))))

(defnail FindDoc
  "Usage: ng vimclojure.nails.FindDoc"
  []
  (find-doc (.readLine *in*)))

(defnail JavadocPath
  "Usage: ng vimclojure.nails.JavadocPath [options]"
  [[nspace n "Lookup the symbols in the given namespace." "user"]]
  (let [nspace         (util/resolve-and-load-namespace nspace)
        our-ns-resolve #(ns-resolve nspace %)]
    (-> (read)
      our-ns-resolve
      backend/javadoc-path-for-class)))

(defnail SourceLookup
  "Usage: ng vimclojure.nails.SourceLookup [options]"
  [[nspace n "Lookup the symbols in the given namespace." "user"]]
  (let [nspace         (util/resolve-and-load-namespace nspace)
        our-ns-resolve #(ns-resolve nspace %)]
    (-> (read)
      our-ns-resolve
      backend/get-source
      println)))

(defnail MetaLookup
  "Usage: ng vimclojure.nails.MetaLookup [options]"
  [[nspace n "Lookup the symbols in the given namespace." "user"]]
  (let [nspace         (util/resolve-and-load-namespace nspace)
        our-ns-resolve #(ns-resolve nspace %)]
    (-> (read)
      our-ns-resolve
      meta
      util/pretty-print)))

(defnail SourceLocation
  "Usage: ng vimclojure.nails.SourceLocation [options]"
  [[nspace n "Lookup the symbols in the given namespace." "user"]]
  (let [nspace         (util/resolve-and-load-namespace nspace)
        our-ns-resolve #(ns-resolve nspace %)]
    (-> (read)
      our-ns-resolve
      backend/source-position)))

(defnail DynamicHighlighting
  "Usage: ng vimclojure.nails.DynamicHighlighting"
  []
  (let [nspace    (read)
        c-c       (the-ns 'clojure.core)
        the-space (util/resolve-and-load-namespace nspace)
        refers    (remove #(= c-c (-> % second meta :ns)) (ns-refers the-space))
        aliases   (mapcat (fn [[the-alias the-alias-space]]
                            (map #(vector (symbol (name the-alias)
                                                  (name (first %)))
                                          (second %))
                                 (ns-publics the-alias-space)))
                          (ns-aliases the-space))
        namespaces (mapcat (fn [the-namespace]
                             (map #(vector (symbol
                                             (name (ns-name the-namespace))
                                             (name (first %)))
                                           (second %))
                                  (ns-publics the-namespace)))
                           (remove #(= c-c %) (all-ns)))
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

(defnail NamespaceOfFile
  "Usage: ng vimclojure.nails.NamespaceOfFile"
  []
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

(defnail NamespaceInfo
  "Usage: ng vimclojure.nails.NamespaceInfo"
  []
  (println (util/clj->vim (map #(-> % symbol find-ns backend/ns-info)
                               (line-seq (BufferedReader. *in*))))))

(defnail MacroExpand
  "Usage: ng vimclojure.nails.MacroExpand [options]"
  [[nspace n "Lookup the symbols in the given namespace." "user"]
   [one?   o "Expand only the first macro."]]
  (let [nspace (util/resolve-and-load-namespace nspace)
        expand (if one
                 #(macroexpand-1 %)
                 #(macroexpand %))]
    (binding [*ns* nspace]
      (-> (read)
        expand
        util/pretty-print-code))))

(defnail Repl
  "Usage: ng vimclojure.nails.Repl [options]"
  [[start?  s "Start a new Repl."]
   [stop?   S "Stop the Repl of the given id."]
   [run?    r "Run the input in the Repl context of the given id."]
   [id      i "The id of the repl to act on." "-1"]
   [nspace  n "Change to namespace before executing the input." ""]
   [file    f "The filename to be set." "REPL"]
   [line    l "The initial line to be set." "0"]
   [ignore? I "Ignore the command with respect to *1, *2, *3"]]
  (let [id     (Integer/parseInt id)
        line   (Integer/parseInt line)
        nspace (when (not= nspace "")
                 (util/resolve-and-load-namespace nspace))]
    (cond
      start {:id (repl/start nspace)}
      stop  (repl/stop id)
      run   (repl/run id nspace file line ignore))))

(defnail ReplNamespace
  "Usage: ng vimclojure.nails.Repl [options]"
  [[id i "The id of the repl to act on."]]
  (let [id (Integer/parseInt id)]
    (get (get @repl/*repls* :id {:ns "user"}) :ns)))

(defnail CheckSyntax
  "Usage: ng vimclojure.nails.CheckSyntax"
  [[nspace  n "Change to namespace before executing the input." "user"]]
  (let [nspace (util/resolve-and-load-namespace nspace)]
    (binding [*ns* nspace]
      (try
        (dorun (util/stream->seq *in*))
        true
        (catch Exception e
          false)))))

(defnail Complete
  "Usage: ng vimclojure.nails.Complete"
  [[nspace n "Start completion in this namespace." "user"]
   [prefix p "Prefix used for the match, ie. the part before /." ""]
   [base   b "Base pattern to be matched."]]
  (let [nspace      (util/resolve-and-load-namespace nspace)
        prefix      (symbol prefix)
        to-complete (util/decide-completion-in nspace prefix base)
        completions (mapcat #(backend/complete % nspace prefix base)
                            to-complete)]
    (map #(apply util/make-completion-item %) completions)))
