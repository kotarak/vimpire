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

(clojure.core/ns de.kotka.gorilla.backend)

; Documentation:
(defn doc-lookup
  "Lookup up the documentation for the given symbols in the given namespace.
  The documentation is returned as a string."
  [namespace symbols]
  (with-out-str
    (doseq [sym symbols]
      (cond
        (special-form-anchor sym)
        (print-special-doc sym "Special Form" (special-form-anchor sym))

        (syntax-symbol-anchor sym)
        (print-special-doc sym "Special Form" (syntax-symbol-anchor sym))

        :else
        (print-doc (ns-resolve namespace sym))))))

(defn javadoc-path-for-class
  "Translate the name of a Class to the path of its javadoc file."
  [x]
  (-> x .getName (.replace \. \/) (.replace \$ \.) (.concat ".html")))

; Namespace Information:
(defn meta-info
  "Convert the meta data of the given Var into a map with the
  values converted to strings."
  [the-var]
  (reduce #(assoc %1 (first %2) (str (second %2))) {} (meta the-var)))

(defn symbol-info
  "Creates a tree node containing the meta information of the Var named
  by the fully qualified symbol."
  [the-symbol]
  (merge {:type "symbol" :name (name the-symbol)}
         (meta-info (find-var the-symbol))))

(defn var-info
  "Creates a tree node containing the meta information of the given Var."
  [the-var]
  (merge {:type "var" :name (str the-var)} (meta-info the-var)))

(defn ns-info
  "Creates a tree node containing the information about the given namespace."
  [the-namespace]
  {:name (-> the-namespace ns-name name) :type "namespace"
   :children (map #(-> % second var-info) (ns-interns the-namespace))})

; Omni Completion
(defn type-of-var
  [the-var]
  (let [the-val (var-get the-var)]
    (cond
      (:macro (meta the-var)) "m"
      (fn? the-val)           "f"
      (instance? clojure.lang.MultiFn the-val) "f"
      :else                   "v")))

(defn complete-in-namespace
  "Complete the given symbol name in the given namespace."
  [the-name the-space]
  (let [name-parts (.split the-name "-")
        publics (-> the-space symbol the-ns ns-map keys)
        publics (map name publics)]
    (reduce (fn [completions sym]
              (let [sym-parts (.split sym "-")]
                (if (and (<= (count name-parts) (count sym-parts))
                         (every? identity (map #(.startsWith %1 %2)
                                               sym-parts name-parts)))
                  (let [sym-var  (ns-resolve (symbol the-space) (symbol sym))
                        sym-meta (meta sym-var)
                        sym-type (type-of-var sym-var)
                        arglists (:arglists sym-meta)
                        info     (map #(str "  "
                                            (prn-str (cons (symbol sym) %)))
                                      arglists)
                        info     (str "  " sym \newline
                                      (when info
                                        (apply str \newline info))
                                      \newline "  "
                                      (:doc sym-meta))]
                    (conj completions
                          {"word" sym      "menu" (pr-str arglists)
                           "kind" sym-type "info" info}))
                completions)))
            [] publics)))
