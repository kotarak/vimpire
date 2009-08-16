; VimClojure.nsi
;--------------------------------

; Needed for setting env vars.
!include "nsh\EnvVarUpdate.nsh"
!include "nsh\TextReplace.nsh"
!include "nsh\ReplaceInFileWithTextReplace.nsh"

; The name of the installer
Name "VimClojure"

; The file to write
OutFile "VimClojure.exe"

LicenseText "VimClojure License"
LicenseData "..\LICENSE.rtf"

; The default installation directory
InstallDir $PROGRAMFILES\VimClojure

; Registry key to check for directory (so if you install again, it will 
; overwrite the old one automatically)
InstallDirRegKey HKLM "Software\VimClojure" "Install_Dir"

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
Section "VimClojure (required)"

  SectionIn RO

  ; Set output path to the installation directory.
  CreateDirectory "$INSTDIR"
  SetOutPath $INSTDIR
  File "..\LICENSE.rtf"

  ; Write the installation path into the registry
  WriteRegStr HKLM SOFTWARE\VimClojure "Install_Dir" "$INSTDIR"

  ; Write the uninstall keys for Windows
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VimClojure" "DisplayName" "VimClojure"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VimClojure" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VimClojure" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VimClojure" "NoRepair" 1
  WriteUninstaller "uninstall.exe"

  ; Jar files
  CreateDirectory "$INSTDIR\jars"
  SetOutPath $INSTDIR\jars
  File "..\..\build\vimclojure.jar"
  File "..\..\lib\clojure-*.jar"

  ; Executables
  CreateDirectory "$INSTDIR\bin"
  SetOutPath $INSTDIR\bin
  File "bin\*.*"

  ; clj.bat
  ${ReplaceInFile} "$INSTDIR\bin\clj.bat" "VIMCLOJURE_DIR" "$INSTDIR"

  ; ng-server.bat
  ${ReplaceInFile} "$INSTDIR\bin\ng-server.bat" "VIMCLOJURE_DIR" "$INSTDIR"
  
  ; Set output path to the vimfiles directory in the user's home directory.
  ; This is where VIM plugins should be installed.
  ReadEnvStr $R0 "HOMEDRIVE"
  ReadEnvStr $R1 "HOMEPATH"
  SetOutPath "$R0$R1\vimfiles"
  File /r "..\..\tmpvimfiles\*.*"
  IfFileExists "_vimrc" append_vimrc copy_vimrc

  copy_vimrc:
    ; Create a starter _vimrc with no vimclojure settings.
    File /r "_vimrc"

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

  CreateDirectory "$SMPROGRAMS\VimClojure"
  CreateShortCut "$SMPROGRAMS\VimClojure\Clojure REPL.lnk" "$INSTDIR\bin\clj.bat" "" "$INSTDIR\bin\clj.bat" 0
  CreateShortCut "$SMPROGRAMS\VimClojure\Start Nailgun Server.lnk" "$INSTDIR\bin\ng-server.bat" "" "$INSTDIR\bin\ng-server.bat" 0

  ; Add bin dir to path
  ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "$INSTDIR\bin"

SectionEnd

;--------------------------------

; Uninstaller

Section "Uninstall"

  ; Remove registry keys
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\VimClojure"
  DeleteRegKey HKLM SOFTWARE\VimClojure

  ; Remove uninstaller
  Delete $INSTDIR\uninstall.exe

  ; Remove shortcuts, if any
  Delete "$SMPROGRAMS\VimClojure\*.*"

  ; Remove bin dir from path
  ${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR\bin"

  ; Remove directories used
  RMDir /r "$SMPROGRAMS\VimClojure"
  RMDir /r "$INSTDIR"

  ; FIXME: Isn't that a bit unconditional?
  ReadEnvStr $R0 "HOMEDRIVE"
  ReadEnvStr $R1 "HOMEPATH"
  RMDir /r "$R0$R1vimfiles"
  Delete "$R0$R1_vimrc"

SectionEnd

