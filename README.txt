            _________            ________________
            __  ____/_______________(_)__  /__  /_____ _
            _  / __ _  __ \_  ___/_  /__  /__  /_  __ `/
            / /_/ / / /_/ /  /   _  / _  / _  / / /_/ /
            \____/  \____//_/    /_/  /_/  /_/  \__,_/

Gorilla - a Clojure environment for Vim

Gorilla provides a similar, although as sophisticated environment for
Vim as SLIME does for Emacs. It uses a modified Repl, which is provides
a network interface to a running Clojure.

To build gorilla, create a local.properties file that contains the path to
your clojure.jar and clojure-contrib.jar. Also, include standalone=true if you
want a standalone gorilla.jar, which runs without further dependencies.
The file should look similar to:

--8<----8<----8<--
clojure.jar=/path/to/clojure.jar
clojure-contrib.jar=/path/to/clojure-contrib.jar
--8<----8<----8<--

Once you have created this file, simply run the following command:

ant clean jar

To run Gorilla you need the clojure.jar, clojure-contrib.jar and
gorilla.jar in your Classpath:

java -cp /path/to/clojure.jar:/path/to/clojure-contrib.jar:gorilla.jar de.kotka.gorilla

For standalone version use:

ant -Dstandalone=true clean jar

This creates gorilla.jar which can be launched by typing:

java -jar gorilla.jar

Please refer to the online documentation in the doc folder for further
information on how to use Gorilla, its features and its caveats.

Meikel Branmdeyer <mb@kotka.de>
Frankfurt am Main, 2008
