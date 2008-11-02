/**
 *   Copyright (c) Rich Hickey. All rights reserved.
 *   The use and distribution terms for this software are covered by the
 *   Common Public License 1.0 (http://opensource.org/licenses/cpl.php)
 *   which can be found in the file CPL.TXT at the root of this distribution.
 *   By using this software in any fashion, you are agreeing to be bound by
 * 	 the terms of this license.
 *   You must not remove this notice, or any other, from this software.
 *
 *   Modified by Meikel Brandmeyer to allow more than one REPL in one
 *   running in system for use with the Gorilla environment.
 *   -- Meikel Brandmeyer <mb@kotka.de> 02.11.2008
 **/

/* rich Oct 18, 2007 */

package de.kotka.socketrepl;

import clojure.lang.RT;
import clojure.lang.Var;
import clojure.lang.Symbol;
import clojure.lang.Compiler;
import clojure.lang.Namespace;
import clojure.lang.LispReader;
import clojure.lang.LineNumberingPushbackReader;

import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.PrintWriter;

public class Repl{
static final Symbol USER = Symbol.create("user");
static final Symbol CLOJURE = Symbol.create("clojure");

static final Var in = RT.var("clojure", "*in*");
static final Var out = RT.var("clojure", "*out*");
static final Var err = RT.var("clojure", "*err*");

static final Var in_ns = RT.var("clojure", "in-ns");
static final Var refer = RT.var("clojure", "refer");
static final Var ns = RT.var("clojure", "*ns*");
static final Var warn_on_reflection = RT.var("clojure", "*warn-on-reflection*");
static final Var print_meta = RT.var("clojure", "*print-meta*");
static final Var print_length = RT.var("clojure", "*print-length*");
static final Var print_level = RT.var("clojure", "*print-level*");
static final Var star1 = RT.var("clojure", "*1");
static final Var star2 = RT.var("clojure", "*2");
static final Var star3 = RT.var("clojure", "*3");
static final Var stare = RT.var("clojure", "*e");

private LineNumberingPushbackReader input;
private OutputStreamWriter output;
private Object EOF;

public Repl(InputStreamReader in, OutputStreamWriter out){
	//repl IO support
	input = new LineNumberingPushbackReader(in);
	output = out;
	EOF = new Object();
}

public void pushBindings() throws Exception{
	//*ns* must be thread-bound for in-ns to work
	//thread-bind *warn-on-reflection* so it can be set!
	//thread-bind *1,*2,*3,*e so each repl has its own history
	//must have corresponding popThreadBindings in finally clause
	Var.pushThreadBindings(
			RT.map(ns, ns.get(),
				warn_on_reflection, warn_on_reflection.get(),
				print_meta, print_meta.get(),
				print_length, print_length.get(),
				print_level, print_level.get(),
				in, input,
				out, output,
				err, new PrintWriter(output, true),
				star1, null,
				star2, null,
				star3, null,
				stare, null));
}

public void setupNamespace() throws Exception{
	//create and move into the user namespace
	in_ns.invoke(USER);
	refer.invoke(CLOJURE);
}

public void loadFiles(String[] args) throws Exception{
	//load any supplied files
	for(String file : RT.processCommandLine(args))
		try
			{
			Compiler.loadFile(file);
			}
		catch(Exception e)
			{
			e.printStackTrace((PrintWriter)RT.ERR.get());
			}
}

public void readEvalPrintLoop() throws Exception{
	//start the loop
	output.write("Clojure\n");
	for(; ;)
		{
		try
			{
			output.write("Gorilla=> ");
			output.flush();
			Object r = LispReader.read(input, false, EOF, false);
			if(r == EOF)
				{
				output.write("\n");
				output.flush();
				break;
				}
			Object ret = Compiler.eval(r);
			RT.print(ret, output);
			output.write('\n');
			star3.set(star2.get());
			star2.set(star1.get());
			star1.set(ret);
			}
		catch(Throwable e)
			{
			Throwable c = e;
			while(c.getCause() != null)
				c = c.getCause();
			((PrintWriter)RT.ERR.get()).println(e instanceof Compiler.CompilerException ? e : c);
			stare.set(e);
			}
		}
}

public void runWithFiles(String[] files) throws Exception{
	try
		{
		pushBindings();
		setupNamespace();
		loadFiles(files);
		readEvalPrintLoop();
		}
	catch(Exception e)
		{
		e.printStackTrace((PrintWriter)RT.ERR.get());
		}
	finally
		{
		Var.popThreadBindings();
		}
}

public void run() throws Exception{
	try
		{
		pushBindings();
		setupNamespace();
		readEvalPrintLoop();
		}
	catch(Exception e)
		{
		e.printStackTrace((PrintWriter)RT.ERR.get());
		}
	finally
		{
		Var.popThreadBindings();
		}
}

public static void main(String[] args) throws Exception{
	Repl repl = new Repl(new InputStreamReader(System.in, RT.UTF8),
					(OutputStreamWriter) RT.OUT.get());
	repl.runWithFiles(args);
	System.exit(0);
}

}
