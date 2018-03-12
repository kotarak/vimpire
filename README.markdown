# Vimpire – a Clojure environment for Vim

Vimpire is the undead body of VimClojure which returned into the
Clojuresphere.

Vimpire is not intended to be an easy to use Clojure IDE, but a plugin
to make life easier for people already familiar with Vim. So you should
be familiar with Vim and/or Java. Eg. Vimpire won't help you in any way
to set up a correct classpath! This is the responsibility of the build
system of the given project. So before using the dynamic server make
yourself comfortable with Clojure, the JVM and Vim.

# Requirements

The plugin is ready to be used with pathogen.

It uses channels, so you'll need a Vim 8 or later.

On the Clojure side, you have to provide a socket repl. That means
either Clojure 1.8 or you'll have to backport the functionality, yourself.

# Here be Dragons

After starting Vim and ideally before editing Clojure code you have to
start the backend server connection.

        :VimpireBite <host>:<port>

No further setup is required. The backend part of Vimpire is completely
zero config and self contained. Also, there is no conflict of several
Vimpire instances connecting to the same backend server. They share code
in case of being of the same version. Otherwise they are completely
separated.

# Demo

I created a small [demo screencast](https://kotka.de/vimpire/demo.webm).

# FAQs

## Hey, I'd like nifty feature X to be supported!

Have fun implementing it. I'll support in providing extension points to
reuse Vimpire's infrastructure, but I don't care about including it in
Vimpire itself.

## Hey, why are there no default bindings set up?

Obviously the opinions are too different on this one. So pick your own
style.

## Hey, why is my repl messed up when I delete the prompt?

Because it's a buffer and not a terminal.

## Hey, why is the namespace loaded when I open a file? I got toplevel commands!

Don't have toplevel commands. Put them in a `(defn main …)` and use
`clj -m` to run the script. Starting the rockets on the toplevel is bad style.

## Hey, your plugin sucks because X!

Then don't use it.

-- 
Meikel Branmdeyer <mb@kotka.de>
Erlensee, 2018
