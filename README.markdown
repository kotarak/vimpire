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

-- 
Meikel Branmdeyer <mb@kotka.de>
Erlensee, 2017
