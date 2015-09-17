#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Enable warnings to assist with detecting common errors.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

; Install the Diablo2 library and its dependency, JSON, to the AutoHotkey user library.

AutoHotkeyLibDir = %A_MyDocuments%\AutoHotkey\Lib
RegRead, Ahk2ExePath, HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Ahk2Exe.exe ; Get default value
RegRead, GamePath, HKEY_CURRENT_USER\Software\Blizzard Entertainment\Diablo II, GamePath

FileCreateDir, %AutoHotkeyLibDir%

InstallFile(SourcePath) {
	Global AutoHotkeyLibDir
	FileCopy, %SourcePath%, %AutoHotkeyLibDir%, true
}

InstallFile("Diablo2.ahk")
InstallFile("Vendor\JSON\JSON.ahk")
InstallFile("Vendor\WatchDirectory\WatchDirectory.ahk")
For _, BaseName in ["_Struct", "sizeof"] {
	InstallFile(Format("Vendor\_Struct\{}.ahk", BaseName))
}
InstallFile("Vendor\Gdip\Gdip.ahk")
;InstallFile("Vendor\MasterFocus\Functions\Gdip_ImageSearch\Gdip_ImageSearch.ahk")
; TODO: Correctly integrate our modifications to MasterFocus's Gdip_ImageSearch
InstallFile("Vendor\Gdip_ImageSearch.ahk")
FileCopyDir, Images, %AutoHotkeyLibDir%\Images, true
; Compile after installing, as Diablo2Run.ahk makes use of Diablo2.ahk.
RunWait, %Ahk2ExePath% /in Diablo2Run.ahk /out %AutoHotkeyLibDir%\Diablo2Run.exe /icon D2.ico

MsgBox, Install successful!`n`nInstalled to %AutoHotkeyLibDir%.
