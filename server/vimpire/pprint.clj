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
  (println (method-str element) (source-str element)))

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
