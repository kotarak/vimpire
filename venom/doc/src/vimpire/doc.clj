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

(ns vimpire.doc
  (:require
    [vimpire.util :as util]
    [clojure.java.io :as io])
  (:import
    clojure.lang.RT
    java.io.LineNumberReader
    java.io.PushbackReader))

; Documentation:
; Mirror this from clojure 1.3 to allow backwards compatibility.
(def ^:private special-doc-map
  '{. {:url "java_interop#dot"
       :forms [(.instanceMember instance args*)
               (.instanceMember Classname args*)
               (Classname/staticMethod args*)
               Classname/staticField]
       :doc "The instance member form works for both fields and methods.
  They all expand into calls to the dot operator at macroexpansion time."}
    def {:forms [(def symbol init?)]
         :doc "Creates and interns a global var with the name
  of symbol in the current namespace (*ns*) or locates such a var if
  it already exists.  If init is supplied, it is evaluated, and the
  root binding of the var is set to the resulting value.  If init is
  not supplied, the root binding of the var is unaffected."}
    do {:forms [(do exprs*)]
        :doc "Evaluates the expressions in order and returns the value of
  the last. If no expressions are supplied, returns nil."}
    if {:forms [(if test then else?)]
        :doc "Evaluates test. If not the singular values nil or false,
  evaluates and yields then, otherwise, evaluates and yields else. If
  else is not supplied it defaults to nil."}
    monitor-enter {:forms [(monitor-enter x)]
                   :doc "Synchronization primitive that should be avoided
  in user code. Use the 'locking' macro."}
    monitor-exit {:forms [(monitor-exit x)]
                  :doc "Synchronization primitive that should be avoided
  in user code. Use the 'locking' macro."}
    new {:forms [(Classname. args*) (new Classname args*)]
         :url "java_interop#new"
         :doc "The args, if any, are evaluated from left to right, and
  passed to the constructor of the class named by Classname. The
  constructed object is returned."}
    quote {:forms [(quote form)]
           :doc "Yields the unevaluated form."}
    recur {:forms [(recur exprs*)]
           :doc "Evaluates the exprs in order, then, in parallel, rebinds
  the bindings of the recursion point to the values of the exprs.
  Execution then jumps back to the recursion point, a loop or fn method."}
    set! {:forms[(set! var-symbol expr)
                 (set! (. instance-expr instanceFieldName-symbol) expr)
                 (set! (. Classname-symbol staticFieldName-symbol) expr)]
          :url "vars#set"
          :doc "Used to set thread-local-bound vars, Java object instance
fields, and Java class static fields."}
    throw {:forms [(throw expr)]
           :doc "The expr is evaluated and thrown, therefore it should
  yield an instance of some derivee of Throwable."}
    try {:forms [(try expr* catch-clause* finally-clause?)]
         :doc "catch-clause => (catch classname name expr*)
  finally-clause => (finally expr*)

  Catches and handles Java exceptions."}
    var {:forms [(var symbol)]
         :doc "The symbol must resolve to a var, and the Var object
itself (not its value) is returned. The reader macro #'x expands to (var x)."}})

(defn ^:private special-doc
  [nspace name-symbol]
  (assoc (or (special-doc-map name-symbol)
             (meta (ns-resolve nspace name-symbol)))
         :name name-symbol
         :special-form true))

(defn ^:private namespace-doc
  [nspace]
  (assoc (meta nspace) :name (ns-name nspace)))

(defn ^:private print-documentation
  [m]
  (->> ["-------------------------"
        (str (when-let [ns (:ns m)] (str (ns-name ns) "/")) (:name m))
        (when-let [forms (:forms m)]
          (apply str (interleave (repeat "  ") (map prn-str (forms m)))))
        (when-let [arglists (:arglists m)]
          (prn-str arglists))
        (if (:special-form m)
          (str "Special Form\n"
               "  " (:doc m) \newline
               (if (contains? m :url)
                 (when (:url m)
                   (str "\n  Please see http://clojure.org/" (:url m))))
               (str "\n  Please see http://clojure.org/special_forms#" (:name m)))
          (str (when (:macro m) "Macro\n")
               "  " (:doc m) \newline))]
    (interpose \newline)
    (apply str)))

(defn doc-lookup
  [nspace sym]
  (let [nspace (util/resolve-and-load-namespace nspace)
        sym    (symbol sym)]
    (if-let [special-name ('{& fn catch try finally try} sym)]
      (print-documentation (special-doc nspace special-name))
      (condp #(%1 %2) sym
        special-doc-map        :>> (fn [_]
                                     (print-documentation
                                       (special-doc nspace sym)))
        find-ns                :>> #(print-documentation (namespace-doc %))
        #(ns-resolve nspace %) :>> #(print-documentation (meta %))
        (str "'" sym "' could not be found. Please check the spelling.")))))

(defn find-doc
  [re-string-or-pattern]
  (let [re (re-pattern re-string-or-pattern)
        ms (concat (mapcat #(sort-by :name (map meta (vals (ns-interns %))))
                           (all-ns))
                   (map namespace-doc (all-ns))
                   (map (partial special-doc "user") (keys special-doc-map)))
        sb (StringBuilder.)]
    (doseq [m ms
            :when (and (:doc m)
                       (or (re-find (re-matcher re (:doc m)))
                           (re-find (re-matcher re (str (:name m))))))]
      (.append sb (print-documentation m)))
    (str sb)))

(defn javadoc-path
  [nspace sym]
  (let [nspace (util/resolve-and-load-namespace nspace)]
    )
  (-> sym
    symbol
    (->> (ns-resolve nspace))
    .getName
    (.replace \. \/)
    (.replace \$ \.)
    (str ".html")))

(defn source-lookup
  [nspace sym]
  (let [nspace  (util/resolve-and-load-namespace nspace)
        the-var (ns-resolve nspace (symbol sym))
        fname   (:file (meta the-var))
        file    (io/file fname)
        strm    (if (.isAbsolute file)
                  (io/input-stream file)
                  (.getResourceAsStream (RT/baseLoader) fname))]
    (when strm
      (with-open [rdr (LineNumberReader. (io/reader strm))]
        (dotimes [_ (dec (:line (meta the-var)))] (.readLine rdr))
        (let [text (StringBuilder.)
              pbr (proxy [PushbackReader] [rdr]
                    (read [] (let [i (proxy-super read)]
                               (.append text (char i))
                               i)))]
          (read (PushbackReader. pbr))
          (str text))))))
