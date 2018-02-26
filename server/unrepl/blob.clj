(clojure.core/let [nop (clojure.core/constantly nil)
e (clojure.core/atom (if (clojure.core/find-ns 'unrepl.repl$bLuNN0FbPN9UYLG_Qi9W_0nokCo) nop eval))]
(clojure.main/repl
:read #(let [x (clojure.core/read)] (clojure.core/case x <<<FIN %2 x))
:prompt nop
:eval #(@e %)
:print nop
:caught #(do (set! *e %) (reset! e nop) (prn [:unrepl.upgrade/failed]))))
(ns unrepl.print$bLuNN0FbPN9UYLG_Qi9W_0nokCo
(:require [clojure.string :as str]
[clojure.edn :as edn]
[clojure.main :as main]))
(defprotocol MachinePrintable
(-print-on [x write rem-depth]))
(defn print-on [write x rem-depth]
(let [rem-depth (dec rem-depth)]
(if (and (neg? rem-depth) (or (nil? *print-length*) (pos? *print-length*)))
(binding [*print-length* 0]
(print-on write x 0))
(do
(when (and *print-meta* (meta x))
(write "#unrepl/meta [")
(-print-on (meta x) write rem-depth)
(write " "))
(-print-on x write rem-depth)
(when (and *print-meta* (meta x))
(write "]"))))))
(defn base64-encode [^java.io.InputStream in]
(let [table "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
sb (StringBuilder.)]
(loop [shift 4 buf 0]
(let [got (.read in)]
(if (neg? got)
(do
(when-not (= shift 4)
(let [n (bit-and (bit-shift-right buf 6) 63)]
(.append sb (.charAt table n))))
(cond
(= shift 2) (.append sb "==")
(= shift 0) (.append sb \=))
(str sb))
(let [buf (bit-or buf (bit-shift-left got shift))
n (bit-and (bit-shift-right buf 6) 63)]
(.append sb (.charAt table n))
(let [shift (- shift 2)]
(if (neg? shift)
(do
(.append sb (.charAt table (bit-and buf 63)))
(recur 4 0))
(recur shift (bit-shift-left buf 6))))))))))
(defn base64-decode [^String s]
(let [table "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
in (java.io.StringReader. s)
bos (java.io.ByteArrayOutputStream.)]
(loop [bits 0 buf 0]
(let [got (.read in)]
(when-not (or (neg? got) (= 61 #_\= got))
(let [buf (bit-or (.indexOf table got) (bit-shift-left buf 6))
bits (+ bits 6)]
(if (<= 8 bits)
(let [bits (- bits 8)]
(.write bos (bit-shift-right buf bits))
(recur bits (bit-and 63 buf)))
(recur bits buf))))))
(.toByteArray bos)))
(def ^:dynamic *elide*
"Function of 1 argument which returns the elision."
(constantly nil))
(def ^:dynamic *string-length* 80)
(def ^:dynamic *max-colls* 100)
(def ^:dynamic *realize-on-print*
"Set to false to avoid realizing lazy sequences."
true)
(defmacro ^:private blame-seq [& body]
`(try (seq ~@body)
(catch Throwable t#
 (list (tagged-literal 'unrepl/lazy-error t#)))))
(defn- may-print? [s]
(or *realize-on-print* (not (instance? clojure.lang.IPending s)) (realized? s)))
(declare ->ElidedKVs)
(defn- print-kvs
[write kvs rem-depth]
(let [print-length *print-length*]
(loop [kvs kvs i 0]
(if (< i print-length)
(when-some [[[k v] & kvs] (seq kvs)]
(when (pos? i) (write ", "))
(print-on write k rem-depth)
(write " ")
(print-on write v rem-depth)
(recur kvs (inc i)))
(when (seq kvs)
(when (pos? i) (write ", "))
(write "#unrepl/... nil ")
(print-on write (tagged-literal 'unrepl/... (*elide* (->ElidedKVs kvs))) rem-depth))))))
(defn- print-vs
[write vs rem-depth]
(let [print-length *print-length*]
(loop [vs vs i 0]
(when-some [[v :as vs] (blame-seq vs)]
(when (pos? i) (write " "))
(if (and (< i print-length) (may-print? vs))
(if (and (tagged-literal? v) (= (:tag v) 'unrepl/lazy-error))
(print-on write v rem-depth)
(do
(print-on write v rem-depth)
(recur (rest vs) (inc i))))
(print-on write (tagged-literal 'unrepl/... (*elide* vs)) rem-depth))))))
(defrecord WithBindings [bindings x]
MachinePrintable
(-print-on [_ write rem-depth]
(with-bindings bindings
(-print-on x write rem-depth))))
(defrecord ElidedKVs [s]
MachinePrintable
(-print-on [_ write rem-depth]
(write "{")
(print-kvs write s rem-depth)
(write "}")))
(def atomic? (some-fn nil? true? false? char? string? symbol? keyword? #(and (number? %) (not (ratio? %)))))
(defn- as-str
"Like pr-str but escapes all ASCII control chars."
[x]
(cond
(string? x) (str/replace (pr-str x) #"\p{Cntrl}"
#(format "\\u%04x" (int (.charAt ^String % 0))))
(char? x) (str/replace (pr-str x) #"\p{Cntrl}"
#(format "u%04x" (int (.charAt ^String % 0))))
:else (pr-str x)))
(defmacro ^:private latent-fn [& fn-body]
`(let [d# (delay (binding [*ns* (find-ns '~(ns-name *ns*))] (eval '(fn ~@fn-body))))]
(fn
([] (@d#))
([x#] (@d# x#))
([x# & xs#] (apply @d# x# xs#)))))
(defrecord MimeContent [mk-in]
MachinePrintable
(-print-on [_ write rem-depth]
(with-open [in (mk-in)]
(write "#unrepl/base64 \"")
(write (base64-encode in))
(write "\""))))
(defn- mime-content [mk-in]
(when-some [e (*elide* (MimeContent. mk-in))]
{:content (tagged-literal 'unrepl/... e)}))
(def ^:dynamic *object-representations*
"map of classes to functions returning their representation component (3rd item in #unrepl/object [class id rep])"
{clojure.lang.IDeref
(fn [x]
(let [pending? (and (instance? clojure.lang.IPending x)
(not (.isRealized ^clojure.lang.IPending x)))
[ex val] (when-not pending?
(try [false @x]
(catch Throwable e
[true e])))
failed? (or ex (and (instance? clojure.lang.Agent x)
(agent-error x)))
status (cond
failed? :failed
pending? :pending
:else :ready)]
{:unrepl.ref/status status :unrepl.ref/val val}))
clojure.lang.AFn
(fn [x]
(-> x class .getName main/demunge))
java.io.File (fn [^java.io.File f]
(into {:path (.getPath f)}
(when (.isFile f)
{:attachment (tagged-literal 'unrepl/mime
(into {:content-type "application/octet-stream"
:content-length (.length f)}
(mime-content #(java.io.FileInputStream. f))))})))
java.awt.Image (latent-fn [^java.awt.Image img]
(let [w (.getWidth img nil)
h (.getHeight img nil)]
(into {:width w :height h}
{:attachment
(tagged-literal 'unrepl/mime
(into {:content-type "image/png"}
(mime-content #(let [bos (java.io.ByteArrayOutputStream.)]
(when (javax.imageio.ImageIO/write
(doto (java.awt.image.BufferedImage. w h java.awt.image.BufferedImage/TYPE_INT_ARGB)
(-> .getGraphics (.drawImage img 0 0 nil)))
"png" bos)
(java.io.ByteArrayInputStream. (.toByteArray bos)))))))})))
Object (fn [x]
(if (-> x class .isArray)
(seq x)
(str x)))})
(defn- object-representation [x]
(reduce-kv (fn [_ class f]
(when (instance? class x) (reduced (f x)))) nil *object-representations*))
(defn- class-form [^Class x]
(if (.isArray x) [(-> x .getComponentType class-form)] (symbol (.getName x))))
(def unreachable (tagged-literal 'unrepl/... nil))
(defn- print-tag-lit-on [write tag form rem-depth]
(write (str "#" tag " "))
(print-on write form rem-depth))
(defn- print-trusted-tag-lit-on [write tag form rem-depth]
(print-tag-lit-on write tag form (inc rem-depth)))
(defn StackTraceElement->vec'
"Constructs a data representation for a StackTraceElement"
{:added "1.9"}
[^StackTraceElement o]
[(symbol (.getClassName o)) (symbol (.getMethodName o)) (.getFileName o) (.getLineNumber o)])
(defn Throwable->map'
"Constructs a data representation for a Throwable."
{:added "1.7"}
[^Throwable o]
(let [base (fn [^Throwable t]
(merge {:type (symbol (.getName (class t)))
:message (.getLocalizedMessage t)}
(when-let [ed (ex-data t)]
{:data ed})
(let [st (.getStackTrace t)]
(when (pos? (alength st))
{:at (StackTraceElement->vec' (aget st 0))}))))
via (loop [via [] ^Throwable t o]
(if t
(recur (conj via t) (.getCause t))
via))
^Throwable root (peek via)
m {:cause (.getLocalizedMessage root)
:via (vec (map base via))
:trace (vec (map StackTraceElement->vec'
(.getStackTrace ^Throwable (or root o))))}
data (ex-data root)]
(if data
(assoc m :data data)
m)))
(def Throwable->map''
(if (neg? (compare (mapv *clojure-version* [:major :minor]) [1 9]))
Throwable->map'
Throwable->map))
(extend-protocol MachinePrintable
clojure.lang.TaggedLiteral
(-print-on [x write rem-depth]
(case (:tag x)
unrepl/... (binding
[*print-length* Long/MAX_VALUE
*print-level* Long/MAX_VALUE
*string-length* Long/MAX_VALUE]
(write (str "#" (:tag x) " "))
(print-on write (:form x) Long/MAX_VALUE))
(print-tag-lit-on write (:tag x) (:form x) rem-depth)))
clojure.lang.Ratio
(-print-on [x write rem-depth]
(print-trusted-tag-lit-on write "unrepl/ratio"
[(.numerator x) (.denominator x)] rem-depth))
clojure.lang.Var
(-print-on [x write rem-depth]
(print-tag-lit-on write "clojure/var"
(when-some [ns (:ns (meta x))]
(symbol (name (ns-name ns)) (name (:name (meta x)))))
rem-depth))
Throwable
(-print-on [t write rem-depth]
(print-tag-lit-on write "error" (Throwable->map'' t) rem-depth))
Class
(-print-on [x write rem-depth]
(print-tag-lit-on write "unrepl.java/class" (class-form x) rem-depth))
java.util.Date (-print-on [x write rem-depth] (write (pr-str x)))
java.util.Calendar (-print-on [x write rem-depth] (write (pr-str x)))
java.sql.Timestamp (-print-on [x write rem-depth] (write (pr-str x)))
clojure.lang.Namespace
(-print-on [x write rem-depth]
(print-tag-lit-on write "unrepl/ns" (ns-name x) rem-depth))
java.util.regex.Pattern
(-print-on [x write rem-depth]
(print-tag-lit-on write "unrepl/pattern" (str x) rem-depth))
String
(-print-on [x write rem-depth]
(if (<= (count x) *string-length*)
(write (as-str x))
(let [i (if (and (Character/isHighSurrogate (.charAt ^String x (dec *string-length*)))
(Character/isLowSurrogate (.charAt ^String x *string-length*)))
(inc *string-length*) *string-length*)
prefix (subs x 0 i)
rest (subs x i)]
(if (= rest "")
(write (as-str x))
(do
(write "#unrepl/string [")
(write (as-str prefix))
(write " ")
(print-on write (tagged-literal 'unrepl/... (*elide* rest)) rem-depth)
(write "]")))))))
(defn- print-coll [open close write x rem-depth]
(write open)
(print-vs write x rem-depth)
(write close))
(extend-protocol MachinePrintable
nil
(-print-on [_ write _] (write "nil"))
Object
(-print-on [x write rem-depth]
(cond
(atomic? x) (write (as-str x))
(map? x)
(do
(when (record? x)
(write "#") (write (.getName (class x))) (write " "))
(write "{")
(print-kvs write x rem-depth)
(write "}"))
(vector? x) (print-coll "[" "]" write x rem-depth)
(seq? x) (print-coll "(" ")" write x rem-depth)
(set? x) (print-coll "#{" "}" write x rem-depth)
:else
(print-trusted-tag-lit-on write "unrepl/object"
[(class x) (format "0x%x" (System/identityHashCode x)) (object-representation x)
{:bean {unreachable (tagged-literal 'unrepl/... (*elide* (ElidedKVs. (bean x))))}}]
(inc rem-depth)))))
(defn edn-str [x]
(let [out (java.io.StringWriter.)
write (fn [^String s] (.write out s))]
(binding [*print-readably* true
*print-length* (or *print-length* 10)
*print-level* (or *print-level* 8)
*string-length* (or *string-length* 72)]
(print-on write x (or *print-level* 8))
(str out))))
(defn full-edn-str [x]
(binding [*print-length* Long/MAX_VALUE
*print-level* Long/MAX_VALUE
*string-length* Integer/MAX_VALUE]
(edn-str x)))
(ns unrepl.repl$bLuNN0FbPN9UYLG_Qi9W_0nokCo
(:require [clojure.main :as m]
[unrepl.print$bLuNN0FbPN9UYLG_Qi9W_0nokCo :as p]
[clojure.edn :as edn]
[clojure.java.io :as io]))
(defn classloader
"Creates a classloader that obey standard delegating policy.
   Takes two arguments: a parent classloader and a function which
   takes a keyword (:resource or :class) and a string (a resource or a class name) and returns an array of bytes
   or nil."
[parent f]
(proxy [clojure.lang.DynamicClassLoader] [parent]
(findResource [name]
(when-some [bytes (f :resource name)]
(let [file (doto (java.io.File/createTempFile "unrepl-sideload-" (str "-" (re-find #"[^/]*$" name)))
.deleteOnExit)]
(io/copy bytes file)
(-> file .toURI .toURL))))
(findClass [name]
(if-some [bytes (f :class name)]
(.defineClass ^clojure.lang.DynamicClassLoader this name bytes nil)
(throw (ClassNotFoundException. name))))))
(defn ^java.io.Writer tagging-writer
([write]
(proxy [java.io.Writer] []
(close [])
(flush [])
(write
([x]
(write (cond
(string? x) x
(integer? x) (str (char x))
:else (String. ^chars x))))
([string-or-chars off len]
(when (pos? len)
(write (subs (if (string? string-or-chars) string-or-chars (String. ^chars string-or-chars))
off (+ off len))))))))
([tag write]
(tagging-writer (fn [s] (write [tag s]))))
([tag group-id write]
(tagging-writer (fn [s] (write [tag s group-id])))))
(defn blame-ex [phase ex]
(if (::phase (ex-data ex))
ex
(ex-info (str "Exception during " (name phase) " phase.")
{::ex ex ::phase phase} ex)))
(defmacro blame [phase & body]
`(try ~@body
(catch Throwable t#
 (throw (blame-ex ~phase t#)))))
(defn atomic-write [^java.io.Writer w]
(fn [x]
(let [s (blame :print (p/edn-str x))]
(locking w
(.write w s)
(.write w "\n")
(.flush w)))))
(defn fuse-write [awrite]
(fn [x]
(when-some [w @awrite]
(try
(w x)
(catch Throwable t
(reset! awrite nil))))))
(def ^:dynamic write)
(defn unrepl-reader [^java.io.Reader r]
(let [offset (atom 0)
offset! #(swap! offset + %)]
(proxy [clojure.lang.LineNumberingPushbackReader clojure.lang.ILookup] [r]
(valAt
([k] (get this k nil))
([k not-found] (case k :offset @offset not-found)))
(read
([]
(let [c (proxy-super read)]
(when-not (neg? c) (offset! 1))
c))
([cbuf]
(let [n (proxy-super read cbuf)]
(when (pos? n) (offset! n))
n))
([cbuf off len]
(let [n (proxy-super read cbuf off len)]
(when (pos? n) (offset! n))
n)))
(unread
([c-or-cbuf]
(if (integer? c-or-cbuf)
(when-not (neg? c-or-cbuf) (offset! -1))
(offset! (- (alength c-or-cbuf))))
(proxy-super unread c-or-cbuf))
([cbuf off len]
(offset! (- len))
(proxy-super unread cbuf off len)))
(skip [n]
(let [n (proxy-super skip n)]
(offset! n)
n))
(readLine []
(when-some [s (proxy-super readLine)]
(offset! (count s))
s)))))
(defn soft-store [make-action]
(let [ids-to-session+refs (atom {})
refs-to-ids (atom {})
refq (java.lang.ref.ReferenceQueue.)
NULL (Object.)]
(.start (Thread. (fn []
(let [ref (.remove refq)]
(let [id (@refs-to-ids ref)]
(swap! refs-to-ids dissoc ref)
(swap! ids-to-session+refs dissoc id)))
(recur))))
{:put (fn [session-id x]
(let [x (if (nil? x) NULL x)
id (keyword (gensym))
ref (java.lang.ref.SoftReference. x refq)]
(swap! refs-to-ids assoc ref id)
(swap! ids-to-session+refs assoc id [session-id ref])
{:get (make-action id)}))
:get (fn [id]
(when-some [[session-id ^java.lang.ref.Reference r] (@ids-to-session+refs id)]
(let [x (.get r)]
[session-id (if (= NULL x) nil x)])))}))
(defonce ^:private sessions (atom {}))
(defn session [id]
(some-> @sessions (get id) deref))
(defonce ^:private elision-store (soft-store #(list `fetch %)))
(defn fetch [id]
(if-some [[session-id x] ((:get elision-store) id)]
(unrepl.print$bLuNN0FbPN9UYLG_Qi9W_0nokCo.WithBindings.
(select-keys (some-> session-id session :bindings) [#'*print-length* #'*print-level* #'p/*string-length* #'p/*elide*])
(cond
(instance? unrepl.print$bLuNN0FbPN9UYLG_Qi9W_0nokCo.ElidedKVs x) x
(string? x) x
(instance? unrepl.print$bLuNN0FbPN9UYLG_Qi9W_0nokCo.MimeContent x) x
:else (seq x)))
p/unreachable))
(defn interrupt! [session-id eval]
(let [{:keys [^Thread thread eval-id promise]}
(some-> session-id session :current-eval)]
(when (and (= eval eval-id)
(deliver promise
{:ex (doto (ex-info "Evaluation interrupted" {::phase :eval})
(.setStackTrace (.getStackTrace thread)))
:bindings {}}))
(.stop thread)
true)))
(defn background! [session-id eval]
(let [{:keys [eval-id promise future]}
(some-> session-id session :current-eval)]
(boolean
(and
(= eval eval-id)
(deliver promise
{:eval future
:bindings {}})))))
(defn reattach-outs! [session-id]
(some-> session-id session :write-atom
(reset!
(if (bound? #'write)
write
(let [out *out*]
(fn [x]
(binding [*out* out
*print-readably* true]
(prn x))))))))
(defn attach-sideloader! [session-id]
(prn '[:unrepl.jvm.side-loader/hello])
(some-> session-id session :side-loader
(reset!
(let [out *out*
in *in*]
(fn self [k name]
(binding [*out* out]
(locking self
(prn [k name])
(some-> (edn/read {:eof nil} in) p/base64-decode)))))))
(let [o (Object.)] (locking o (.wait o))))
(defn set-file-line-col [session-id file line col]
(when-some [^java.lang.reflect.Field field
(->> clojure.lang.LineNumberingPushbackReader
.getDeclaredFields
(some #(when (= "_columnNumber" (.getName ^java.lang.reflect.Field %)) %)))]
(doto field (.setAccessible true))
(when-some [in (some-> session-id session :in)]
(set! *file* file)
(set! *source-path* file)
(.setLineNumber in line)
(.set field in (int col)))))
(defn- writers-flushing-repo [max-latency-ms]
(let [writers (java.util.WeakHashMap.)
flush-them-all #(locking writers
(doseq [^java.io.Writer w (.keySet writers)]
(.flush w)))]
(.scheduleAtFixedRate
(java.util.concurrent.Executors/newScheduledThreadPool 1)
flush-them-all
max-latency-ms max-latency-ms java.util.concurrent.TimeUnit/MILLISECONDS)
(fn [w]
(locking writers (.put writers w nil)))))
(defmacro ^:private flushing [bindings & body]
`(binding ~bindings
(try ~@body
(finally ~@(for [v (take-nth 2 bindings)]
`(.flush ~(vary-meta v assoc :tag 'java.io.Writer)))))))
(defn- non-eliding-write [x]
(binding [*print-length* Long/MAX_VALUE
*print-level* Long/MAX_VALUE
p/*string-length* Long/MAX_VALUE]
(write x)))
(defn start []
(with-local-vars [eval-id 0
prompt-vars #{#'*ns* #'*warn-on-reflection*}
current-eval-future nil]
(let [session-id (keyword (gensym "session"))
raw-out *out*
aw (atom (atomic-write raw-out))
write-here (fuse-write aw)
schedule-writer-flush! (writers-flushing-repo 50)
scheduled-writer (fn [& args]
(-> (apply tagging-writer args)
java.io.BufferedWriter.
(doto schedule-writer-flush!)))
edn-out (scheduled-writer :out (fn [x] (binding [p/*string-length* Integer/MAX_VALUE] (write-here x))))
in (unrepl-reader *in*)
session-state (atom {:current-eval {}
:in in
:write-atom aw
:log-eval (fn [msg]
(when (bound? eval-id)
(write [:log msg @eval-id])))
:log-all (fn [msg]
(write [:log msg nil]))
:side-loader (atom nil)
:prompt-vars #{#'*ns* #'*warn-on-reflection*}})
current-eval-thread+promise (atom nil)
say-hello
(fn []
(non-eliding-write
[:unrepl/hello {:session session-id
:actions (into
{:start-aux `(start-aux ~session-id)
:log-eval
`(some-> ~session-id session :log-eval)
:log-all
`(some-> ~session-id session :log-all)
:print-limits
`(let [bak# {:unrepl.print/string-length p/*string-length*
:unrepl.print/coll-length *print-length*
:unrepl.print/nesting-depth *print-level*}]
(some->> ~(tagged-literal 'unrepl/param :unrepl.print/string-length) (set! p/*string-length*))
(some->> ~(tagged-literal 'unrepl/param :unrepl.print/coll-length) (set! *print-length*))
(some->> ~(tagged-literal 'unrepl/param :unrepl.print/nesting-depth) (set! *print-level*))
bak#)
:set-source
`(unrepl/do
(set-file-line-col ~session-id
~(tagged-literal 'unrepl/param :unrepl/sourcename)
~(tagged-literal 'unrepl/param :unrepl/line)
~(tagged-literal 'unrepl/param :unrepl/column)))
:unrepl.jvm/start-side-loader
`(attach-sideloader! ~session-id)}
{})}]))
interruptible-eval
(fn [form]
(try
(let [original-bindings (get-thread-bindings)
p (promise)
f
(future
(swap! session-state update :current-eval
assoc :thread (Thread/currentThread))
(with-bindings original-bindings
(try
(write [:started-eval
{:actions
{:interrupt (list `interrupt! session-id @eval-id)
:background (list `background! session-id @eval-id)}}
@eval-id])
(let [v (blame :eval (eval form))]
(deliver p {:eval v :bindings (get-thread-bindings)})
v)
(catch Throwable t
(deliver p {:ex t :bindings (get-thread-bindings)})
(throw t)))))]
(swap! session-state update :current-eval
into {:eval-id @eval-id :promise p :future f})
(let [{:keys [ex eval bindings]} @p]
(swap! session-state assoc :bindings bindings)
(doseq [[var val] bindings
:when (not (identical? val (original-bindings var)))]
(var-set var val))
(if ex
(throw ex)
eval)))
(finally
(swap! session-state assoc :current-eval {}))))
cl (.getContextClassLoader (Thread/currentThread))
slcl (classloader cl
(fn [k x]
(when-some [f (some-> session-state deref :side-loader deref)]
(f k x))))]
(swap! session-state assoc :class-loader slcl)
(swap! sessions assoc session-id session-state)
(binding [*out* edn-out
*err* (tagging-writer :err write)
*in* in
*file* "unrepl-session"
*source-path* "unrepl-session"
p/*elide* (partial (:put elision-store) session-id)
p/*string-length* p/*string-length*
write write-here]
(.setContextClassLoader (Thread/currentThread) slcl)
(with-bindings {clojure.lang.Compiler/LOADER slcl}
(try
(m/repl
:init #(do
(swap! session-state assoc :bindings (get-thread-bindings))
(say-hello))
:prompt (fn []
(non-eliding-write [:prompt (into {:file *file*
:line (.getLineNumber *in*)
:column (.getColumnNumber *in*)
:offset (:offset *in*)}
(map (fn [v]
(let [m (meta v)]
[(symbol (name (ns-name (:ns m))) (name (:name m))) @v])))
(:prompt-vars @session-state))]))
:read (fn [request-prompt request-exit]
(blame :read (let [id (var-set eval-id (inc @eval-id))
line+col [(.getLineNumber *in*) (.getColumnNumber *in*)]
offset (:offset *in*)
r (m/repl-read request-prompt request-exit)
line+col' [(.getLineNumber *in*) (.getColumnNumber *in*)]
offset' (:offset *in*)
len (- offset' offset)]
(write [:read {:from line+col :to line+col'
:offset offset
:len (- offset' offset)}
id])
(if (and (seq? r) (= (first r) 'unrepl/do))
(let [write #(binding [p/*string-length* Integer/MAX_VALUE] (write %))]
(flushing [*err* (tagging-writer :err id write)
*out* (scheduled-writer :out id write)]
(eval (cons 'do (next r))))
request-prompt)
r))))
:eval (fn [form]
(let [id @eval-id
write #(binding [p/*string-length* Integer/MAX_VALUE] (write %))]
(flushing [*err* (tagging-writer :err id write)
*out* (scheduled-writer :out id write)]
(interruptible-eval form))))
:print (fn [x]
(write [:eval x @eval-id]))
:caught (fn [e]
(let [{:keys [::ex ::phase]
:or {ex e phase :repl}} (ex-data e)]
(write [:exception {:ex ex :phase phase} @eval-id]))))
(finally
(.setContextClassLoader (Thread/currentThread) cl))))
(write [:bye {:reason :disconnection
:outs :muted
:actions {:reattach-outs `(reattach-outs! ~session-id)}}])))))
(defn start-aux [session-id]
(let [cl (.getContextClassLoader (Thread/currentThread))]
(try
(some->> session-id session :class-loader (.setContextClassLoader (Thread/currentThread)))
(start)
(finally
(.setContextClassLoader (Thread/currentThread) cl)))))
(defmacro ensure-ns [[fully-qualified-var-name & args :as expr]]
`(do
(require '~(symbol (namespace fully-qualified-var-name)))
~expr))
<<<FIN
(clojure.core/ns user)
(unrepl.repl$bLuNN0FbPN9UYLG_Qi9W_0nokCo/start)
