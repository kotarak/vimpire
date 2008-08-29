" Vim syntax file
" Language:	   Clojure
" Last Change: 2008-08-24
" Maintainer:  Toralf Wittner <toralf.wittner@gmail.com>

if version < 600
    syntax clear
elseif exists("b:current_syntax")
    finish
endif

if exists("g:clj_highlight_builtins")
	" Boolean
	syn keyword clojureBoolean true false

	" Predicates and Tests
	syn keyword clojureFunc = not= none= not nil? false? true? complement identical? string? symbol? map? seq? vector? keyword? special-symbol? var?
	syn keyword clojureMacro and or

	" Conditionals
	syn keyword clojureCond if if-let when when-not when-let when-first cond
	syn keyword clojureException try catch finally throw

	" Functionals
	syn keyword clojureFunc apply partial comp constantly identity comparator
	syn keyword clojureMacro fn

	" Regular Expressions
	syn keyword clojureFunc re-matcher re-find re-matches re-groups re-seq re-pattern

	" Define
	syn keyword clojureDefine def def- defn defn- defmacro let

	" Other Functions
	syn keyword clojureFunc str time pr prn print println pr-str prn-str print-str println-str newline macroexpand macroexpand-1 monitor-enter monitor-exit doc eval find-doc file-seq flush hash load load-file print-doc read read-line scan slurp subs sync test
	syn keyword clojureMacro -> assert with-out-str with-in-str with-open locking do quote var loop destructure
	syn keyword clojureRepeat recur
	syn keyword clojureComment comment
	syn keyword clojureVariable *in* *out* *command-line-args* *print-meta* *print-readably*

	" Nil
	syn keyword clojureConstant nil

	" Number Functions
	syn keyword clojureFunc + - * / < <= == >= > dec inc min max neg? pos? quot rem zero? rand rand-int

	" Bit Functions
	syn keyword clojureFunc bit-and bit-or bit-xor bit-not bit-shift-left bit-shift-right

	" Symbols
	syn keyword clojureFunc symbol keyword gensym

	" Collections
	syn keyword clojureFunc count conj seq first rest ffirst frest rfirst rrest second every? not-every? some not-any? concat reverse cycle interleave interpose split-at split-with take take-nth take-while drop drop-while repeat replicate iterate range into distinct sort sort-by zipmap fnseq lazy-cons lazy-cat line-seq butlast last nth nthrest repeatedly tree-seq
	syn keyword clojureRepeat map mapcat reduce filter for doseq dorun doall dotimes

	" Lists
	syn keyword clojureFunc list list* cons peek pop

	" Vectors
	syn keyword clojureFunc vec vector peek pop rseq subvec

	" Maps
	syn keyword clojureFunc array-map hash-map sorted-map sorted-map-by assoc dissoc get contains? find select-keys key val keys vals merge merge-with max-key min-key

	" Struct-Maps
	syn keyword clojureFunc create-struct struct-map struct accessor
	syn keyword clojureDefine defstruct

	" Sets
	syn keyword clojureFunc hash-set sorted-set set disj union difference intersection select index rename join map-invert project

	" Multimethods
	syn keyword clojureDefine defmulti defmethod
	syn keyword clojureFunc remove-method

	" Metadata
	syn keyword clojureFunc meta with-meta

	" Namespaces
	syn keyword clojureFunc in-ns clojure/in-ns refer clojure/refer create-ns find-ns all-ns remove-ns import ns-name ns-map ns-interns ns-publics ns-imports ns-refers ns-resolve resolve ns-unmap name namespace require use
	syn keyword clojureMacro ns clojure/ns
	syn keyword clojureVariable *ns*

	" Vars and Environment
	syn keyword clojureMacro binding with-local-vars
	syn keyword clojureFunc set! find-var var-get var-set

	" Refs and Transactions
	syn keyword clojureFunc ref deref ensure alter ref-set commute
	syn keyword clojureMacro dosync

	" Agents
	syn keyword clojureFunc agent send send-off agent-errors clear-agent-errors await await-for
	syn keyword clojureVariable *agent*

	" Java Interaction
	syn keyword clojureSpecial . new
	syn keyword clojureMacro .. doto memfn proxy
	syn keyword clojureFunc instance? bean alength aget aset aset-boolean aset-byte aset-char aset-double aset-float aset-int aset-long aset-short areduce make-array to-array to-array-2d into-array int long float double char boolean short byte parse add-classpath cast class get-proxy-class proxy-mappings update-proxy
	syn keyword clojureVariable *warn-on-reflection* *proxy-classes* this

	" Zip
	syn keyword clojureFunc append-child branch? children up down edit end? insert-child insert-left insert-right left lefts right rights make-node next node path remove replace root seq-zip vector-zip xml-zip zipper
endif

syn keyword clojureTodo contained FIXME XXX
syn match clojureComment contains=clojureTodo ";.*$"

syn match clojureKeyword ":\a[a-zA-Z0-9?!\-_+*\./=<>]*"

syn region clojureString start=/"/ end=/"/ skip=/\\"/

syn match clojureCharacter "\\."
syn match clojureCharacter "\\[0-7]\{3\}"
syn match clojureCharacter "\\u[0-9]\{4\}"
syn match clojureCharacter "\\space"
syn match clojureCharacter "\\tab"
syn match clojureCharacter "\\newline"
syn match clojureCharacter "\\backspace"
syn match clojureCharacter "\\formfeed"

syn match clojureNumber "\<-\?[0-9]\+\>"
syn match clojureRational "\<-\?[0-9]\+/[0-9]\+\>"
syn match clojureFloat "\<-\?[0-9]\+\.[0-9]\+\([eE][-+]\=[0-9]\+\)\=\>"

syn match clojureQuote "\('\|`\)"
syn match clojureUnquote "\(\~@\|\~\)"
syn match clojureDispatch "\(#^\|#'\)"

syn match clojureAnonArg contained "%\(\d\|&\)\?"
syn match clojureVarArg contained "&"

syn region clojureSexp matchgroup=Delimiter start="(" matchgroup=Delimiter end=")" contains=TOP
syn region clojureAnonFn matchgroup=Delimiter start="#(" matchgroup=Delimiter end=")" contains=ALLBUT,clojureVarArg
syn region clojureVector matchgroup=Delimiter start="\[" matchgroup=Delimiter end="\]" contains=ALLBUT,clojureAnonArg
syn region clojureMap matchgroup=Delimiter start="{" matchgroup=Delimiter end="}" contains=TOP
syn region clojureSet matchgroup=Delimiter start="#{" matchgroup=Delimiter end="}" contains=TOP
syn region clojurePattern start=/#"/ end=/"/ skip=/\\"/

highlight default link clojureConstant  Constant
highlight default link clojureBoolean   Boolean
highlight default link clojureCharacter Character
highlight default link clojureKeyword   Operator
highlight default link clojureNumber    Number
highlight default link clojureRational  Number
highlight default link clojureFloat     Float
highlight default link clojureString    String
highlight default link clojurePattern   Constant

highlight default link clojureVariable  Identifier
highlight default link clojureCond      Conditional
highlight default link clojureDefine    Define
highlight default link clojureException Exception
highlight default link clojureFunc      Function
highlight default link clojureMacro     Macro
highlight default link clojureRepeat    Repeat

highlight default link clojureQuote     Special
highlight default link clojureUnquote   Special
highlight default link clojureDispatch  Special
highlight default link clojureAnonArg   Special
highlight default link clojureVarArg    Special
highlight default link clojureSpecial   Special

highlight default link clojureComment   Comment
highlight default link clojureTodo      Todo

let b:current_syntax = "clojure"
