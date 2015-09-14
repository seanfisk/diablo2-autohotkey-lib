#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Enable warnings to assist with detecting common errors.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

; Install the Diablo2 library and its dependency, JSON, to the AutoHotkey user library.

AutoHotkeyLibDir = %A_MyDocuments%\AutoHotkey\Lib
RegRead, Ahk2ExePath, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Ahk2Exe.exe ; Get default value
RegRead, GamePath, HKEY_CURRENT_USER\Software\Blizzard Entertainment\Diablo II, GamePath

FileCreateDir, %AutoHotkeyLibDir%

FileCopy, Diablo2.ahk, %AutoHotkeyLibDir%, true
FileCopy, Vendor\JSON\JSON.ahk, %AutoHotkeyLibDir%, true
; Compile after installing, as Diablo2Run.ahk makes use of Diablo2.ahk.
RunWait, %Ahk2ExePath% /in Diablo2Run.ahk /out %AutoHotkeyLibDir%\Diablo2Run.exe /icon D2.ico
; Passing 1 overwrites existing files.
FileCopyDir, Images, %AutoHotkeyLibDir%\Images, 1

MsgBox, Install successful!`n`nInstalled to %AutoHotkeyLibDir%.
