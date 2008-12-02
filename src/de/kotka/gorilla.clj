;-
; Copyright 2008 (c) Meikel Brandmeyer.
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

(clojure.core/ns de.kotka.gorilla
  (:gen-class)
  (:use [clojure.contrib.fcase :only (case)])
  (:import
     (clojure.lang RT Compiler Compiler$CompilerException LispReader
                   LineNumberingPushbackReader)
     (java.io InputStreamReader OutputStreamWriter PrintWriter)
     (java.net InetAddress ServerSocket Socket)))

(defn go-word-position
  [v]
  (let [m      (meta v)
        vns    (name (ns-name (m :ns)))
        nsbase (.substring vns (inc (.lastIndexOf vns (int \.))))
        nspath (.replace vns \. \/)
        file   (m :file)
        fbase  (.substring file 0 (.lastIndexOf file (int \.)))
        line   (m :line)]
    (if (= fbase nsbase)
      (str nspath ".clj " line)
      (str nspath "/" file " " line))))

(defn print-rest
  [input]
  (loop [c (.read input)]
    (when-not (neg? c)
      (print (char c))
      (recur (.read input)))))

(defn try-eval
  [input]
  (loop [state :running]
    (when (= state :running)
      (recur
        (do
          (.mark input 0)
          (set! *in* (new java.io.PushbackReader input))
          (try
            (let [eof (new Object)
                  r   (read *in* false eof)]
              (if (= r eof)
                :done
                (let [r (eval r)]
                  (println r)
                  (flush)
                  (set! *3 *2)
                  (set! *2 *1)
                  (set! *1 r)
                  :running)))
            (catch Throwable e
              (if (and (instance? Exception e)
                       (= (.getMessage e) "EOF while reading"))
                (do
                  (println "-ERR incomplete expression")
                  (.reset input)
                  (print-rest input)
                  :done)
                (let [c (last (take-while #(not (nil? %))
                                          (iterate #(.getCause %) e)))]
                  (binding [*out* *err*]
                    (println (if (instance? Compiler$CompilerException e) e c))
                    (flush))
                  (set! *e e)
                  :running)))))))))

(defn try-read
  [in]
  (let [s (new StringBuilder)]
    (loop [wait true]
      (if (or (.ready in) wait)
        (let [c (.read in)]
          (if (neg? c)
            (if wait
              nil
              (str s))
            (do
              (.append s (char c))
              (recur false))))
        (str s)))))

(defn repl
  [in out]
  (try
    (binding [*in*  *in*
              *out* out
              *err* (new PrintWriter out true)
              *ns*  *ns*
              *warn-on-reflection* *warn-on-reflection*
              *print-meta*   *print-meta*
              *print-length* *print-length*
              *print-level*  *print-level*
              *1 nil
              *2 nil
              *3 nil
              *e nil]
      (in-ns 'user)
      (refer 'clojure.core)
      (loop [state :prompt]
        (case state
          :prompt (recur
                    (do
                      (println "+OK")
                      (flush)
                      :eval))

          :eval   (recur
                    (let [input (try-read in)]
                      (if input
                        (do
                          (try-eval (new java.io.StringReader input))
                          :prompt)
                        :exit)))

          :exit   (do
                    (println)
                    (flush))))
      (catch Exception e
        (.printStackTrace e *err*)))))

(defn handle-connection
  [conn]
  (-> (fn []
        (repl
          (new InputStreamReader (.getInputStream conn)  RT/UTF8)
          (new OutputStreamWriter (.getOutputStream conn) RT/UTF8))
        (.close conn)
        (println "Connection closed."))
    Thread.
    .start))

(defn server-loop
  [server]
  (let [conn (.accept server)]
    (println "Connection started.")
    (handle-connection conn)
    (recur server)))

(defn -main
  [& _]
  (let [address (InetAddress/getByName "localhost")
        server  (new ServerSocket 10123 0 address)]
    (println "Listening...")
    (server-loop server)))
