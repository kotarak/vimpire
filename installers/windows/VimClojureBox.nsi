; VimClojureBox.nsi
;--------------------------------

; Needed for setting env vars.
!include "installers\windows\EnvVarUpdate.nsh"

; The name of the installer
Name "VimClojureBox"

; The file to write
OutFile "VimClojureBox.exe"

LicenseText "VimClojure Box License"
LicenseData "installers\LICENSE.rtf"

; The default installation directory
InstallDir $PROGRAMFILES\VimClojureBox

; Registry key to check for directory (so if you install again, it will 
; overwrite the old one automatically)
InstallDirRegKey HKLM "Software\VimClojureBox" "Install_Dir"

; Request application privileges for Windows Vista
RequestExecutionLevel admin

;--------------------------------
; Pages

Page license
Page components
Page directory
Page instfiles

UninstPage uninstConfirm
UninstPage instfiles

;--------------------------------

; The stuff to install
Section "VimClojureBox (required)"

  SectionIn RO

  ; Set output path to the installation directory.
  CreateDirectory "$INSTDIR"
  SetOutPath $INSTDIR
  File "installers\LICENSE.rtf"

  ; Write the installation path into the registry
  WriteRegStr HKLM SOFTWARE\VimClojureBox "Install_Dir" "$INSTDIR"

  ; Write the uninstall keys for Windows
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VimClojureBox" "DisplayName" "VimClojureBox"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VimClojureBox" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VimClojureBox" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VimClojureBox" "NoRepair" 1
  WriteUninstaller "uninstall.exe"

  ; Jar files
  CreateDirectory "$INSTDIR\jars"
  SetOutPath $INSTDIR\jars
  File "lib\*.jar"
  File "lib\vimclojure.jar"

  ; Executables
  CreateDirectory "$INSTDIR\bin"
  SetOutPath $INSTDIR\bin
  File "bin\*.*"
  ; Create batch files ; Batch files

  ; clj.bat
  FileOpen "$0" "clj.bat" "w"
  FileWrite "$0" "@echo off$\r$\n"
  FileWrite "$0" "setlocal ENABLEDELAYEDEXPANSION$\r$\n"
  FileWrite "$0" "for %%I IN ($\"$INSTDIR\jars\*.jar$\") DO SET CP=!CP!;%%~fI$\r$\n"
  FileWrite "$0" "java -cp $\"%CP%$\" clojure.main %1 %2 %3 %4 %5 %6 %7 %8 %9$\r$\n"
  FileClose "$0"
  ; ng-server.bat
  FileOpen "$0" "ng-server.bat" "w"
  FileWrite "$0" "@echo off$\r$\n"
  FileWrite "$0" "setlocal ENABLEDELAYEDEXPANSION$\r$\n"
  FileWrite "$0" "for %%I IN ($\"$INSTDIR\jars\*.jar$\") DO SET CP=!CP!;%%~fI$\r$\n"
  FileWrite "$0" "java -cp $\"%CP%$\" com.martiansoftware.nailgun.NGServer 127.0.0.1 %1 %2 %3 %4 %5 %6 %7 %8 %9$\r$\n"
  FileClose "$0"
  
  ; Set output path to the vimfiles directory in the user's home directory.
  ; This is where VIM plugins should be installed.
  ReadEnvStr $R0 "HOMEDRIVE"
  ReadEnvStr $R1 "HOMEPATH"
  SetOutPath "$R0$R1\vimfiles"
  File /r "tmpvimfiles\*.*"
  IfFileExists "_vimrc" append_vimrc copy_vimrc

  copy_vimrc:
    ; Create a starter _vimrc with no vimclojure settings.
    File /r "installers\windows\_vimrc"

  ; Add vimclojure settings, including short path to ng.exe.
  ; We have to use the short path because spaces cause vimclojure to puke.
  append_vimrc:
    GetFullPathName /SHORT $1 "$INSTDIR\bin\ng.exe"
    FileOpen "$0" "_vimrc" "a"
    FileSeek "$0" 0, END
    FileWrite "$0" "$\r$\n$\" vimclojure settings$\r$\n"
    FileWrite "$0" "filetype plugin indent on$\r$\n"
    FileWrite "$0" "syntax on$\r$\n"
    FileWrite "$0" "let clj_highlight_builtins = 1$\r$\n"
    FileWrite "$0" "let clj_highlight_contrib = 1$\r$\n"
    FileWrite "$0" "let clj_paren_rainbow = 1$\r$\n"
    FileWrite "$0" "let clj_want_gorilla = 1$\r$\n"
    ; Now that we added bin to the path we don't really need the full
    ; path to ng.exe.  I'll keep it anyway for now unless it causes problems.
    FileWrite "$0" "let g:vimclojure#NailgunClient='$1'$\r$\n"
    FileClose "$0"

  CreateDirectory "$SMPROGRAMS\VimClojureBox"
  CreateShortCut "$SMPROGRAMS\VimClojureBox\Clojure REPL.lnk" "$INSTDIR\bin\clj.bat" "" "$INSTDIR\bin\clj.bat" 0
  CreateShortCut "$SMPROGRAMS\VimClojureBox\Start Nailgun Server.lnk" "$INSTDIR\bin\ng-server.bat" "" "$INSTDIR\bin\ng-server.bat" 0

  ; Add bin dir to path
  ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "$INSTDIR\bin"

SectionEnd

;--------------------------------

; Uninstaller

Section "Uninstall"

  ; Remove registry keys
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VimClojureBox"
  DeleteRegKey HKLM SOFTWARE\VimClojureBox

  ; Remove uninstaller
  Delete $INSTDIR\uninstall.exe

  ; Remove shortcuts, if any
  Delete "$SMPROGRAMS\VimClojureBox\*.*"

  ; Remove bin dir from path
  ${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR\bin"

  ; Remove directories used
  RMDir /r "$SMPROGRAMS\VimClojureBox"
  RMDir /r "$INSTDIR"

  ; FIXME: Isn't that a bit unconditional?
  ReadEnvStr $R0 "HOMEDRIVE"
  ReadEnvStr $R1 "HOMEPATH"
  RMDir /r "$R0$R1vimfiles"
  Delete "$R0$R1_vimrc"

SectionEnd
