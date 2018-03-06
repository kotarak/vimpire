(ns vimpire.pprint
  (:require
    [clojure.java.io :as io]
    [clojure.string :as string])
  (:import
    clojure.lang.RT))

; Taken from clj-stacktrace: https://github.com/mmcgrana/clj-stacktrace
(defn ^:private clojure-code?
  "Returns true if the filename is non-null and indicates a clj source file."
  [class-name file]
  (or (re-find #"^user" class-name)
      (= file "NO_SOURCE_FILE")
      (= file "unrepl-session")
      (and file (re-find #"\.clj$" file))))

(defn ^:private clojure-ns
  "Returns the clojure namespace name implied by the bytecode class name."
  [class-name]
  (string/replace (or (get (re-find #"([^$]+)\$" class-name) 1)
                      (get (re-find #"(.+)\.[^.]+$" class-name) 1))
                  #"_" "-"))

;; drop everything before and including the first $
;; drop everything after and including and the second $
;; drop any __xyz suffixes
;; sub _PLACEHOLDER_ for the corresponding char
(def ^:private clojure-fn-subs
  [[#"^[^$]*\$" ""]
   [#"\$.*"    ""]
   [#"__\d+.*"  ""]
   [#"_QMARK_"  "?"]
   [#"_BANG_"   "!"]
   [#"_PLUS_"   "+"]
   [#"_GT_"     ">"]
   [#"_LT_"     "<"]
   [#"_EQ_"     "="]
   [#"_STAR_"   "*"]
   [#"_SLASH_"  "/"]
   [#"_"        "-"]])

(defn ^:private clojure-fn
  "Returns the clojure function name implied by the bytecode class name."
  [class-name]
  (reduce (fn [base-name [pattern sub]] (string/replace base-name pattern sub))
          class-name
          clojure-fn-subs))

(defn ^:private clojure-anon-fn?
  "Returns true if the bytecode class name implies an anonymous inner fn."
  [class-name]
  (boolean (re-find #"\$.*\$" class-name)))

(defn ^:private parse-trace-elem
  "Returns a map of information about the java trace element.
  All returned maps have the keys:
  :file      String of source file name.
  :line      Number of source line number of the enclosing form.
  Additionally for elements from Java code:
  :java      true, to indicate a Java elem.
  :class     String of the name of the class to which the method belongs.
  Additionally for elements from Clojure code:
  :clojure   true, to inidcate a Clojure elem.
  :ns        String representing the namespace of the function.
  :fn        String representing the name of the enclosing var for the function.
  :anon-fn   true iff the function is an anonymous inner fn."
  [[class-name method file line]]
  (let [parsed {:file file :line line}]
    (if (clojure-code? class-name file)
      (assoc parsed
        :clojure true
        :ns      (clojure-ns class-name)
        :fn      (clojure-fn class-name)
        :anon-fn (clojure-anon-fn? class-name))
      (assoc parsed
        :java true
        :class class-name
        :method method))))

(defn ^:private clojure-method-str
  [parsed]
  (str (:ns parsed) "/" (:fn parsed) (when (:anon-fn parsed) "[fn]")))

(defn ^:private java-method-str
  [parsed]
  (str (:class parsed) "." (:method parsed)))

(defn ^:private method-str
  [parsed]
  (if (:java parsed)
    (java-method-str parsed)
    (clojure-method-str parsed)))

; Taken from pyro: https://github.com/venantius/pyro
(defn ^:private pad-integer
  "Right-pad an integer with spaces until it takes up 4 character spaces."
  [n]
  (let [len (-> n str count)]
    (str n (apply str (repeat (- 4 len) " ")))))

(defn ^:private pad-source
  [s n]
  (str "    " (pad-integer n) " " s))

(defn ^:private pad-source-arrow
  [s n]
  (str "--> " (pad-integer n) " " s))

(defn ^:private filepath->stream
  [filepath]
  (or (.getResourceAsStream (RT/baseLoader) filepath)
      (let [file (io/file filepath)]
        (when (.exists file)
          (io/input-stream file)))))

(defn ^:private filepath->reader
  [filepath]
  (some-> (filepath->stream filepath) io/reader))

(defn ^:private file-source
  [filepath]
  (when-let [rdr (filepath->reader filepath)]
    (with-open [rdr rdr] (doall (line-seq rdr)))))

(defn ^:private source-fn
  [filepath line number]
  (let [lines (file-source filepath)]
    (when (seq lines)
      (let [content   (drop (- line (inc number)) lines)
            pre       (take number content)
            line-code (nth content number)
            post      (->> content (take (inc (* number 2))) (drop (inc number)))]
        (str (string/join "\n" (flatten
                                 [(map pad-source pre (range (- line number) line))
                                  (pad-source-arrow line-code line)
                                  (map pad-source post
                                       (range (inc line) (inc (+ line number))))]))
             "\n")))))

(defn ^:private ns->filename
  [n f]
  (let [n (-> n
            (string/replace "-" "_")
            (string/split #"\.")
            drop-last
            vec
            (conj f))]
    (string/join "/" n)))

(defn ^:private get-var-filename
  [{:keys [ns fn file] :as element}]
  (if (= fn "fn")
    ;; anonymous fn, but file exists
    (ns->filename ns file)
    ;; defined var
    (-> (symbol ns fn) resolve meta :file)))

(defn ^:private source-str
  [{:keys [file line]}]
  (str "(" file ":" line ")"))

(defn ^:private print-trace-element
  [{:keys [class method filename line anon-fn] :as element}]
  (println (method-str element) (source-str element))
  (when (:clojure element)
    (when-let [file (get-var-filename element)]
      (some-> (source-fn file line 2) println))))

(defn pprint-exception
  [error]
  (let [trace (map parse-trace-elem (:trace error))]
    (with-out-str
      (println "Cause:" (:cause error))
      (print " at ")
      (if-let [e (first trace)]
        (print-trace-element e)
        (print "[empty stack trace]"))
      (doseq [e (next trace)]
        (print "    ")
        (print-trace-element e)))))
