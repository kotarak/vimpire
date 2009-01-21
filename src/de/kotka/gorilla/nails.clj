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
     (de.kotka.gorilla [util :only (with-command-line clj->vim)]
                       backend))
  (:import
     com.martiansoftware.nailgun.NGContext))

(gen-class
  :name    de.kotka.gorilla.nails.DocLookup
  :prefix  DocLookup-
  :methods [#^{:static true}
            [nailMain [com.martiansoftware.nailgun.NGContext] void]]
  :main    false)

(defn DocLookup-nailMain
  [#^NGContext context]
  (with-command-line (.getArgs context)
    "Usage: ng de.kotka.gorilla.nails.DocString [options] [--] symbol ..."
    [[namespace n "Lookup the symbols in the given namespace." "user"]
     symbols]
    (binding [*out* (-> context .out java.io.OutputStreamWriter.)]
      (print (doc-lookup namespace symbols))
      (flush))))

(gen-class
  :name    de.kotka.gorilla.nails.NamespaceInfo
  :prefix  NamespaceInfo-
  :methods [#^{:static true}
            [nailMain [com.martiansoftware.nailgun.NGContext] void]]
  :main    false)

(defn NamespaceInfo-nailMain
  [#^NGContext context]
  (with-command-line (.getArgs context)
    "Usage: ng de.kotka.gorilla.nails.NamespaceInfo namespace ..."
    [namespaces]
    (println (clj->vim (map #(-> % symbol find-ns ns-info) namespaces)))))
