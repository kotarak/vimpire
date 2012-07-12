/*-
 * Copyright 2009-2011 (c) Meikel Brandmeyer.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

package vimclojure;

import clojure.lang.RT;
import clojure.lang.Symbol;
import clojure.lang.Var;

import vimclojure.nailgun.NGContext;

public class Nail {
    /* Load up vimclojure */
    static Var nailDriver;

    static {
        try {
            final Var require = RT.var("clojure.core", "require");
            require.invoke(Symbol.create("vimclojure.connector.nailgun"));

            nailDriver = RT.var("vimclojure.connector.nailgun", "nailgun-driver");
        } catch (Exception exc) {
            Throwable e = exc;
            System.err.println("A crisis has arisen:");
            e.printStackTrace();
        }
    }

    public static void nailMain(NGContext ctx) throws Exception {
        nailDriver.invoke(ctx);
    }
}
