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

(ns vimpire.dynhighlight
  (:require
    [vimpire.util :as util]
    [clojure.set  :as set]))

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
        vars      (set/difference vars macros)
        fns       (set (filter #(let [v (util/safe-var-get (second %))]
                                  (or (fn? v)
                                      (instance? clojure.lang.MultiFn v)))
                               vars))
        vars      (set/difference vars fns)
        strfirst  (comp str first)]
    {"Func"     (mapv strfirst fns)
     "Macro"    (mapv strfirst macros)
     "Variable" (mapv strfirst vars)}))
