This archive contains a syntax file, a filetype plugin and an indent plugin
for clojure.

The syntax is maintained by Toralf Wittner <toralf.wittner@gmail.com>. I
included it with his permission. All kudos for the highlighting go to Toralf.

Additionally I created a (currently relatively simple) filetype and indent
plugin. The blame for those go to me.

To setup the plugins copy the contents of this archive to your ~/.vim directory.
The ftdetect/clojure.vim sets up an autocommand to automatically detect .clj
files as clojure files. The rest works automagically when you enabled the
corresponding features (see :help :filetype).

-- Meikel Brandmeyer <mb@kotka.de>
   Frankfurt am Main, June 21st 2008
