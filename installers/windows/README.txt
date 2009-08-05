VimClojure Box

h2. What is it?

In the spirit of "Lispbox":http://gigamonkeys.com/book/lispbox/ and "Clojure Box":http://clojure.bighugh.com/, VimClojureBox -is- hopes to be a single installer for Windows that will install the following.

# Clojure
# Clojure Contrib
# Vim
# VimClojure

I've successfully created an installer that, assuming you already installed
Vim, installs Clojure, Clojure Contrib, VimClojure, and adds entries to the
Start menu so you can start up the REPL or the Nailgun server.  It's just
the beginning.

h2. How do I build the installer?

First install the following:

# "JDK":http://java.sun.com/ 1.6 or greater
# "Ant":http://ant.apache.org/ 1.7 or greater
# "Null Soft Scriptable Installer":http://nsis.sourceforge.net/ 2.4.5 or greater
# "msysgit":http://code.google.com/p/msysgit/ 1.6.3 or greater
# "Mercurial":http://mercurial.berkwood.com/ 1.3.0 or greater

Then clone my github repository and run build.bat.

<pre>
 hg clone ...
 cd vimclojurebox
 build.bat
</pre>

When the build finishes you should see VimClojureBox.exe sitting in your
directory.  It is built with the latest development version of clojure,
clojure-contrib and vimclojure.

h2. What should I be aware of before installing VimClojureBox?

# VimClojureBox is currently super alpha.
# You have to install Vim yourself.
# If you have an existing _vimrc file in your home directory, it wil be
overwritten without backing it up first!
# The _vimrc file that gets installed is quite plain.
# It is a work in progress.  Feel free to send me suggestions.

