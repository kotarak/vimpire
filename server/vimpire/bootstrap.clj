;-
; Copyright 2017 © Meikel Brandmeyer.
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

(ns vimpire.bootstrap
  (:require
    [clojure.java.io :as io])
  (:import
    clojure.lang.Compiler
    clojure.lang.LineNumberingPushbackReader))

(defn make-reader
  [reader offset]
  (proxy [LineNumberingPushbackReader] [reader]
    (getLineNumber [] (+ (proxy-super getLineNumber) offset))))

(defn set-source
  ([file] (set-source file 0))
  ([file line]
   (push-thread-bindings {Compiler/LINE        (Integer. (.intValue line))
                          Compiler/SOURCE_PATH file
                          Compiler/SOURCE      (.getName (io/file file))
                          #'*in*               (make-reader *in* line)})
   nil))

(defn revert-source
  []
  (pop-thread-bindings)
  nil)

(defn needs-bootstrap?
  []
  (try
    (the-ns 'vimpire.nails)
    "Vimpire is ready!"
    (catch Exception _
      "Vimpire needs bootstrap!")))
