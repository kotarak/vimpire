/*-
 * Copyright 2012 © Meikel Brandmeyer.
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

package vimclojure.gradle

import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.api.internal.project.ProjectInternal
import org.gradle.api.plugins.JavaPlugin

public class VimPlugin implements Plugin<Project> {
    public void apply(Project project) {
        project.apply plugin: JavaPlugin.class

        configureSourceSets(project)
        configureTests(project)
    }

    private void configureSourceSets(Project project) {
        ProjectInternal projectInternal = (ProjectInternal)project

        project.sourceSets.each { sourceSet ->
            VimSourceSet vimSourceSet =
                new VimSourceSet(sourceSet.name, projectInternal.fileResolver)

            sourceSet.convention.plugins.vim = vimSourceSet
            sourceSet.vim.srcDirs = [ String.format("src/%s/vim", sourceSet.name) ]
            sourceSet.allSource.source(vimSourceSet.vim)
        }
    }

    private void configureTests(Project project) {
        VimTestTask vimTest = project.tasks.add(name: "vimTest",
                type: VimTestTask.class) {
            source project.sourceSets.test.vim
            testRoots = project.sourceSets.test.vim
            description = "Run Vim tests in src/test."
        }
        project.tasks.build.dependsOn vimTest
    }
}
