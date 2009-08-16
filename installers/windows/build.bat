rmdir /s/q bin
mkdir bin
pushd ..\..
rmdir /s/q tmpvimfiles
echo vimdir=tmpvimfiles> local.properties
cmd /c ant
cmd /c ant install
copy ng.exe installers\windows\bin\ng.exe
cmd /c makensis installers\windows\VimClojure.nsi
rmdir /s/q tmpvimfiles
popd
