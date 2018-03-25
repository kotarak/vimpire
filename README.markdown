# Vimpire – a Clojure environment for Vim

Vimpire is the undead body of VimClojure which returned into the
Clojuresphere.

```
                            _..._
                          .'     '.
                         ; __   __ ;
                         |/  \ /  \|
                       |\| -- ' -- |/|
                       |(| \o| |o/ |)|
                       _\|     >   |/_
                    .-'  | ,.___., |  '-.
                    \    ;  V'-'V  ;    /
                     `\   \       /   /`
                       `\  '-...-'  /`
                         `\  / \  /`
                    jgs    `\\_//`
```

Vimpire is not intended to be an easy to use Clojure IDE, but a plugin
to make life easier for people already familiar with Vim. So you should
be familiar with Vim and/or Java. Eg. Vimpire won't help you in any way
to set up a correct classpath! This is the responsibility of the build
system of the given project. So before using the dynamic server make
yourself comfortable with Clojure, the JVM and Vim.

# Requirements

The plugin is ready to be used as a package. Regarding package managers
you'll have to figure things out yourself.

It uses channels, so you'll need a Vim 8 or later.

On the Clojure side, you have to provide a socket repl. That means
either Clojure 1.8 or you'll have to backport the functionality yourself.

# Here be Dragons

After starting Vim and ideally before editing Clojure code you have to
start the backend server connection.

        :VimpireBite <host>:<port>

No further setup is required. The backend part of Vimpire is completely
zero config and self contained. Also, there is no conflict of several
Vimpire instances connecting to the same backend server. They share code
in case of being of the same version. Otherwise they are completely
separated.

When you got fangs, the connection is ready. Be aware that the first
connect is slow, because things have to be prepared like starting the
side-loader and injecting the venom. Don't bother me with trivial
nonsense like “start-up time.”

# Demos

I created a small set of short demos:

* [Stalking the prey](https://kotka.de/vimpire/vimpire_bite.webm)
* [Dynamic highlighting](https://kotka.de/vimpire/vimpire_dynamic_highlighting.webm)
* [Documentation lookup](https://kotka.de/vimpire/vimpire_doclookup.webm)
* [Goto and show source](https://kotka.de/vimpire/vimpire_source_operators.webm)
* [Eval operators](https://kotka.de/vimpire/vimpire_eval.webm)
* [Macro expansion](https://kotka.de/vimpire/vimpire_macro_expansion.webm)
* [Async completion](https://kotka.de/vimpire/vimpire_completion.webm)
* [The repl](https://kotka.de/vimpire/vimpire_repl.webm)

# FAQs

- **Hey, I'd like nifty feature X to be supported!**<br>
  Have fun implementing it. I'll support in providing extension points to
  reuse Vimpire's infrastructure, but I don't care about including it in
  Vimpire itself.

- **Hey, why are there no default bindings set up?**<br>
  Obviously the opinions are too different on this one. So pick your own
  style.

- **Hey, why is my repl messed up when I delete the prompt?**<br>
  Because it's a buffer and not a terminal.

- **Hey, why is the namespace loaded when I open a file? I got toplevel commands!**<br>
  Don't have toplevel commands. Put them in a `(defn main …)` and use
  `clj -m` to run the script. Starting the rockets on the toplevel is bad
  style. There are exceptions. I don't optimise for exceptions.

- **Hey, your plugin sucks because X!** <br>
  Then don't use it.

# Sources

The ASCII art was taken from [here](http://www.chris.com/ascii/joan/www.geocities.com/SoHo/7373/haloween.html).
Take care. It tries to play a midi.

```
-- 
Meikel Branmdeyer <mb@kotka.de>
Erlensee, 2018
```
