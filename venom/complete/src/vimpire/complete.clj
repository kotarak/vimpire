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
    [vimpire.util  :as util]
    [complete.core :as c]))

(defn completions
  [prefix nspace]
  (let [nspace (symbol nspace)]
    (vec
      (for [candidate (c/completions prefix nspace)]
        (if-let [v (util/safe-ns-resolve nspace (symbol candidate))]
          (let [info     (str "  " candidate \newline)
                metadata (meta v)
                arglists (:arglists metadata)
                info     (if arglists
                           (reduce #(str %1 "  " (prn-str (cons (symbol candidate) %2)))
                                   (str info \newline) arglists)
                           info)
                info     (if-let [docstring (:doc metadata)]
                           (str info \newline "  " docstring)
                           info)]
            {"word" candidate
             "kind" (if (:macro metadata) "m" "f")
             "menu" (pr-str arglists)
             "info" info})
          {"word" candidate})))))
