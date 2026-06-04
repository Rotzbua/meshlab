; Must modify:
; - MESHLAB_VERSION
; - DISTRIB_PATH

Unicode true
ManifestDPIAware true
ManifestSupportedOS Win10
;ManifestSupportedOS all

!define PRODUCT_NAME "MeshLab"
!define PRODUCT_VERSION "MESHLAB_VERSION"
!define PRODUCT_PUBLISHER "Paolo Cignoni - VCG - ISTI - CNR"
!define PRODUCT_WEB_SITE "https://www.meshlab.net"
!define PRODUCT_DIR_REGKEY "Software\Microsoft\Windows\CurrentVersion\App Paths\meshlab.exe"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
!define DISTRIB_FOLDER "DISTRIB_PATH"

!define MAINDIR $PROGRAMFILES64

Name "${PRODUCT_NAME} ${PRODUCT_VERSION}"
OutFile "MeshLab${PRODUCT_VERSION}-windows.exe"
InstallDir "${MAINDIR}\VCG\MeshLab"
ShowInstDetails show
ShowUnInstDetails show

; Set compression to highest available 2026.
SetCompressor /SOLID /FINAL lzma

; ---------- Multi-User Configuration ----------
; Must be defined before include.
!define MULTIUSER_EXECUTIONLEVEL Highest
!define MULTIUSER_MUI
!define MULTIUSER_INSTALLMODE_COMMANDLINE
!define MULTIUSER_INSTALLMODE_INSTDIR "$(^Name)"
!define MULTIUSER_INSTALLMODE_DEFAULT_CURRENTUSER ; Set default to a per-user installation, even if the rights for a per-machine installation are available.
!define MULTIUSER_USE_PROGRAMFILES64 ; Use $PROGRAMFILES64 instead of $PROGRAMFILES as the default all users directory.
!define MULTIUSER_INSTALLMODE_FUNCTION onMultiUserModeChanged

!define MULTIUSER_INSTALLMODE_DEFAULT_REGISTRY_KEY ${PRODUCT_UNINST_KEY}
!define MULTIUSER_INSTALLMODE_DEFAULT_REGISTRY_VALUENAME "CurrentUser"

; Use MUI v2 -----
!include MUI2.nsh
!include "MultiUser.nsh"
!include LogicLib.nsh
!include FileFunc.nsh
!include x64.nsh
; Custom scripts
!include FileAssociation.nsh
!include ExecWaitJob.nsh

; MUI Settings
!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"

; Welcome page
!insertmacro MUI_PAGE_WELCOME
; License page
!insertmacro MUI_PAGE_LICENSE "${DISTRIB_FOLDER}\LICENSE.txt"
; License page
!insertmacro MUI_PAGE_LICENSE "${DISTRIB_FOLDER}\privacy.txt"
; Per-user/-machine choice.
!insertmacro MULTIUSER_PAGE_INSTALLMODE
; Directory page
!insertmacro MUI_PAGE_DIRECTORY
; Instfiles page
!insertmacro MUI_PAGE_INSTFILES


; Finish page
!define MUI_FINISHPAGE_RUN "$INSTDIR\meshlab.exe"
!insertmacro MUI_PAGE_FINISH

; Uninstaller pages
!insertmacro MUI_UNPAGE_INSTFILES

; Language files
!insertmacro MUI_LANGUAGE "English"

; Add macro for meta data installation size.
!insertmacro GetSize

; MUI end ------
!define /date NOW "%Y_%m_%d"

Function onMultiUserModeChanged
${If} $MultiUser.InstallMode == "CurrentUser"
    StrCpy $InstDir "$LocalAppdata\Programs\${MULTIUSER_INSTALLMODE_INSTDIR}"
${EndIf}
FunctionEnd

Function .onInit
  ; Just install on 64-bit Windows.
  ${IfNot} ${RunningX64}
    MessageBox  MB_ICONEXCLAMATION|MB_YESNO  "This installer requires 64-bit Windows.$\n$\nContinue anyway?" IDYES allowInstall IDNO exitInstaller
    allowInstall:
      Return
    exitInstaller:
      Quit
  ${EndIf}
  ; Set to 64‑bit registry.
  SetRegView 64

  ; Require at least Windows 10.
  ${IfNot} ${AtLeastWin10}
    MessageBox MB_ICONEXCLAMATION|MB_YESNO "This installer requires Windows 10 or newer.$\n$\nContinue anyway?" IDYES allowInstall IDNO exitInstaller
    allowInstall:
      Return
    exitInstaller:
      Quit
  ${EndIf}

  ; Macro sets correct SetShellVarContext.
  !insertmacro MULTIUSER_INIT

  ReadRegStr $0 SHCTX "${PRODUCT_UNINST_KEY}" "UninstallString"
  ${If} $0 != "" ;2020.0x...
    ${IfNot} ${Silent}
      MessageBox MB_OK "Please first uninstall old MeshLab version. Starting uninstaller now..."
    ${EndIf}
    StrCpy $8 '"$0"'
    ${If} ${Silent}
      StrCpy $8 "$8 /S"
    ${EndIf}
    !insertmacro ExecWaitJob r8
  ${Else}
    ReadRegStr $0 SHCTX "Software\Microsoft\Windows\CurrentVersion\Uninstall\MeshLab_64b" "UninstallString"
    ${If} $0 != "" ;2016.12
      ${IfNot} ${Silent}
        MessageBox MB_OK "Please first uninstall old MeshLab version. Starting uninstaller now..."
      ${EndIf}
      StrCpy $8 '"$0"'
      ${If} ${Silent}
        StrCpy $8 "$8 /S"
      ${EndIf}
      !insertmacro ExecWaitJob r8
    ${EndIf}
  ${EndIf}
FunctionEnd

Section "MainSection" SEC01
  SetOutPath "$INSTDIR"
  ;Let's delete all the dangerous stuff from previous releases.
  ;Shortcuts for currentuser shell context
  RMDir /r "$SMPROGRAMS\MeshLab"
  Delete "$DESKTOP\MeshLab.lnk"

  ;Shortcuts for allusers
  ;SetShellVarContext all ;Set alluser context. Icons created later are in allusers
  ;RMDir /r "$SMPROGRAMS\MeshLab"
  ;Delete "$DESKTOP\MeshLab.lnk"

  DeleteRegKey SHCTX "${PRODUCT_UNINST_KEY}"
  DeleteRegKey SHCTX "${PRODUCT_DIR_REGKEY}"
  ;DeleteRegKey SHCTX "${PRODUCT_DIR_REGKEY_S}"

  Delete "$INSTDIR\*"

  SetOverwrite on
  File "${DISTRIB_FOLDER}\meshlab.exe"
  ;File "${DISTRIB_FOLDER}\meshlabserver.exe"
  CreateDirectory "$SMPROGRAMS\MeshLab"
  CreateShortCut "$SMPROGRAMS\MeshLab\MeshLab.lnk" "$INSTDIR\meshlab.exe"
  CreateShortCut "$DESKTOP\MeshLab.lnk" "$INSTDIR\meshlab.exe"
  ;CreateShortCut '$SMPROGRAMS\MeshLab\MeshLabServer.lnk' 'powershell.exe -noexit -command "cd $INSTDIR\ " '

  ;Copy everything inside DISTRIB
  SetOutPath "$INSTDIR"
  File /nonfatal /a /r "${DISTRIB_FOLDER}\"

  ;Association to extensions:
  ;${registerExtension} "$INSTDIR\meshlab.exe" ".obj" "OBJ File"
  ;${registerExtension} "$INSTDIR\meshlab.exe" ".ply" "PLY File"
  ;${registerExtension} "$INSTDIR\meshlab.exe" ".stl" "STL File"
  ;${registerExtension} "$INSTDIR\meshlab.exe" ".qobj" "QOBJ File"
  ;${registerExtension} "$INSTDIR\meshlab.exe" ".off" "OFF File"
  ;${registerExtension} "$INSTDIR\meshlab.exe" ".ptx" "PTX File"
  ;${registerExtension} "$INSTDIR\meshlab.exe" ".vmi" "VMI File"
  ;${registerExtension} "$INSTDIR\meshlab.exe" ".fbx" "FBX File"

SectionEnd

Section -Prerequisites
  ${If} $MultiUser.InstallMode == "AllUsers"
    ExecWait '"$INSTDIR\vc_redist.x64.exe" /q /norestart'
  ${EndIf}
    ;always install vc_redist
	;ReadRegStr $1 HKLM "SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" "Installed"
	;${If} $1 <> 0
	;	Goto endPrerequisites
	;${Else}
	;	ExecWait '"$INSTDIR\vc_redist.x64.exe" /q /norestart'
	;${EndIf}
	;endPrerequisites:
SectionEnd

Section -Post
  WriteUninstaller "$INSTDIR\uninstall.exe"
  WriteRegStr SHCTX "${PRODUCT_DIR_REGKEY}" "" "$INSTDIR\meshlab.exe"
  ;WriteRegStr SHCTX "${PRODUCT_DIR_REGKEY_S}" "" "$INSTDIR\meshlabserver.exe"

  ; Metadata for Windows "Installed Apps".
  WriteRegStr SHCTX "${PRODUCT_UNINST_KEY}" "DisplayName" "$(^Name)"
  WriteRegStr SHCTX "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\uninstall.exe"
  WriteRegStr SHCTX "${PRODUCT_UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\uninstall.exe" /S'
  WriteRegStr SHCTX "${PRODUCT_UNINST_KEY}" "DisplayIcon" "$INSTDIR\meshlab.exe"
  WriteRegStr SHCTX "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr SHCTX "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
  WriteRegStr SHCTX "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegDWORD SHCTX "${PRODUCT_UNINST_KEY}" "NoRepair" 1
  WriteRegDWORD SHCTX "${PRODUCT_UNINST_KEY}" "NoModify" 1
  ; Calculate installation size (KB)
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  WriteRegDWORD SHCTX "${PRODUCT_UNINST_KEY}" "EstimatedSize" $0
SectionEnd

Section -AdditionalIcons
  ;WriteIniStr "$INSTDIR\${PRODUCT_NAME}.url" "InternetShortcut" "URL" "${PRODUCT_WEB_SITE}"
  ;CreateShortCut "$SMPROGRAMS\MeshLab\Website.lnk" "$INSTDIR\${PRODUCT_NAME}.url"
  CreateShortCut "$SMPROGRAMS\MeshLab\Uninstall.lnk" "$INSTDIR\uninstall.exe"
SectionEnd


Function un.onInit ;before uninstall starts
  ; Set to 64‑bit registry.
  SetRegView 64

  !insertmacro MULTIUSER_UNINIT

  ${If} ${Silent}
    Return
  ${Else}
	MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "Are you sure you want to completely remove $(^Name) and all of its components?" IDYES +2
	Abort
  ${EndIf}
FunctionEnd

Section Uninstall ;uninstall instructions
  RMDir /r "$INSTDIR"

  ;Remove shortcuts in currentuser profile
  RMDir /r "$SMPROGRAMS\MeshLab"
  Delete "$DESKTOP\MeshLab.lnk"

  ;Remove shortcuts in allusers profile
  ;SetShellVarContext all
  ;RMDir /r "$SMPROGRAMS\MeshLab"
  ;Delete "$DESKTOP\MeshLab.lnk"

  DeleteRegKey SHCTX "${PRODUCT_UNINST_KEY}"
  DeleteRegKey SHCTX "${PRODUCT_DIR_REGKEY}"
  ;DeleteRegKey SHCTX "${PRODUCT_DIR_REGKEY_S}"

  ;Unregistering file association
  ;${unregisterExtension} ".obj" "OBJ File"
  ;${unregisterExtension} ".ply" "PLY File"
  ;${unregisterExtension} ".stl" "STL File"
  ;${unregisterExtension} ".qobj" "QOBJ File"
  ;${unregisterExtension} ".off" "OFF File"
  ;${unregisterExtension} ".ptx" "PTX File"
  ;${unregisterExtension} ".vmi" "VMI File"
  ;${unregisterExtension} ".fbx" "FBX File"

  SetAutoClose true
SectionEnd

Function un.onUninstSuccess ;after uninstall
  HideWindow
  ${If} ${Silent}
    Return
  ${Else}
    MessageBox MB_ICONINFORMATION|MB_OK "$(^Name) was successfully removed from your computer."
  ${EndIf}
FunctionEnd
