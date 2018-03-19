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

(ns vimpire.complete
  (:require
    [vimpire.util    :as util]
    [compliment.core :as c]))

(defmulti make-completion-item
  "Create a completion item for Vim's popup-menu."
  (fn [the-thing]
    (let [t (:type the-thing)]
      (if (= t :var)
        (if-let [v (util/safe-ns-resolve (symbol (:ns the-thing))
                                         (symbol (:candidate the-thing)))]
          (cond
            (instance? clojure.lang.MultiFn (util/safe-var-get v)) :function
            (fn? (util/safe-var-get v)) :function
            :else :var)
          :var)
        t))))

(defmethod make-completion-item :namespace
  [{:keys [candidate]}]
  (let [docs (-> candidate symbol the-ns meta :doc)
        info (str " " candidate \newline
                  (when docs (str \newline docs)))]
    {"word" candidate
     "kind" "n"
     "menu" ""
     "info" info}))

(defmethod make-completion-item :class
  [{:keys [candidate]}]
  {"word" candidate
   "kind" "c"
   "menu" ""
   "info" ""})

(defmethod make-completion-item :method
  [{:keys [candidate]}]
  {"word" candidate
   "kind" "M"
   "menu" ""
   "info" ""})

(defmethod make-completion-item :var
  [{:keys [candidate ns]}]
  (let [the-var (util/safe-ns-resolve (symbol ns) (symbol candidate))
        info    (str "  " candidate \newline)
        info    (if-let [docstring (-> the-var meta :doc)]
                  (str info \newline "  " docstring)
                  info)]
    {"word" candidate
     "kind" "v"
     "menu" (pr-str (try
                      (type @the-var)
                      (catch IllegalStateException _
                        "<UNBOUND>")))
     "info" info}))

(defn- make-completion-item-fm
  [{:keys [candidate ns]} typ]
  (let [the-var  (util/safe-ns-resolve (symbol ns) (symbol candidate))
        the-fn   (util/safe-var-get the-var)
        info     (str "  " candidate \newline)
        metadata (meta the-var)
        arglists (:arglists metadata)
        info     (if arglists
                   (reduce #(str %1 "  " (prn-str (cons (symbol candidate) %2)))
                           (str info \newline) arglists)
                   info)
        info     (if-let [docstring (:doc metadata)]
                   (str info \newline "  " docstring)
                   info)]
    {"word" candidate
     "kind" typ
     "menu" (pr-str arglists)
     "info" info}))

(defmethod make-completion-item :function
  [the-thing]
  (make-completion-item-fm the-thing "f"))

(defmethod make-completion-item :macro
  [the-thing]
  (make-completion-item-fm the-thing "m"))

(defmethod make-completion-item :default
  [{:keys [candidate]}]
  {"word" candidate
   "kind" ""
   "menu" ""
   "info" ""})

(defn completions
  [prefix nspace]
  (let [nspace (symbol nspace)]
    (mapv make-completion-item (c/completions prefix {:ns nspace}))))
