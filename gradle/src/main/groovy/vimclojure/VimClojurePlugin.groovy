/*-
 * Copyright 2011 © Meikel Brandmeyer.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

package vimclojure

import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.api.tasks.JavaExec

public class VimClojurePlugin implements Plugin<Project> {
    class Convention {
        def String nailgunServer = "127.0.0.1"
        def String nailgunPort = "2113"
    }

    public void apply(Project project) {
        project.convention.plugins.vimclojure = new Convention()

        project.tasks.add(name: 'runNailgun') {
            dependsOn project.classes
        } << {
            project.javaexec {
                classpath = project.files(
                    project.sourceSets.main.clojure.srcDirs,
                    project.sourceSets.main.classesDir,
                    project.configurations.testRuntime,
                    project.configurations.development
                )
                main = 'vimclojure.nailgun.NGServer'
                args = [ project.nailgunServer + ":" + project.nailgunPort ]
            }
        }
    }
}
