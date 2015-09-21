; Recommended for performance and compatibility with future AutoHotkey
; releases.
#NoEnv
; Replace an old instance of the macros with a new one.
#SingleInstance Force
; Allow AutoHotkey to find the config files in this directory.
SetWorkingDir %A_ScriptDir%

; AutoHotkey uses the name of script in the system tray. We name the
; script D2Macros so that its purpose is obvious when looking in the
; tray.

; Initialize the macros by giving the paths to the configuration
; files.
;
; Passing "Log.txt" creates that file in this directory and logs
; information to it. I *highly recommend* leaving logging on, as it
; makes debugging problems with the macros much easier.
Diablo2_Init("Controls.json", "Skills.json", "FillPotion.json", "Log.txt")

; Activate the following hotkeys only in the Diablo II game itself.
#IfWinActive ahk_class Diablo II

; Ctrl+Alt+a to auto-configure controls.
; '^' is Control, '!' is Alt, and 'a' is the a key.
^!a::Diablo2_ConfigureControls()
^!b::Diablo2_FillPotionGenerateBitmaps()
^!r::Diablo2_Reset()
; Just 'f' runs FillPotion.
f::Diablo2_FillPotion()

; Activate the following hotkeys in any application.
#IfWinActive

; Don't use a key used for Diablo II, as the hotkey for suspend itself
; won't be suspended. Ideally, use a hotkey that won't be used in any
; applications globally.
^!s::Suspend
; Quit the macros
^!x::ExitApp
