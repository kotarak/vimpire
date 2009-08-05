pushd ..\..
rmdir /s/q tmpvimfiles
echo vimdir=tmpvimfiles> local.properties
cmd /c ant
cmd /c ant install
cmd /c makensis installers\windows\VimClojureBox.nsi
rmdir /s/q tmpvimfiles
popd
