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

import groovy.lang.Closure

import org.gradle.api.file.FileTree
import org.gradle.api.file.SourceDirectorySet
import org.gradle.api.internal.file.UnionFileTree
import org.gradle.api.internal.file.DefaultSourceDirectorySet
import org.gradle.api.internal.file.FileResolver
import org.gradle.api.tasks.util.PatternFilterable
import org.gradle.api.tasks.util.PatternSet
import org.gradle.util.ConfigureUtil

public class VimSourceSet {
    private final SourceDirectorySet vim
    private final UnionFileTree allVim
    private final PatternFilterable vimPatterns = new PatternSet()

    public VimSourceSet(String displayName, FileResolver fileResolver) {
        def String description = String.format("%s Vim source", displayName)
        vim = new DefaultSourceDirectorySet(description, fileResolver)
        vim.filter.include("**/*.vim")
        vimPatterns.include("**/*.vim")
        allVim = new UnionFileTree(description, vim.matching(vimPatterns))
    }

    public SourceDirectorySet getVim() {
        return vim
    }

    public VimSourceSet vim(Closure configureClosure) {
        ConfigureUtil.configure(configureClosure, this.vim)
        return this
    }

    public PatternFilterable getVimSourcePatterns() {
        return vimPatterns
    }

    public FileTree getAllVim() {
        return allVim
    }
}
