#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

; AutoHotkey uses the name of script in the system tray.
; We name the script D2Macros so that its purpose is obvious when looking in the tray.

Diablo2_Init("Keys.json", "SkillWeaponSets.json")

#IfWinActive ahk_class Diablo II

; Ctrl+Alt+a to assign key bindings.
^!a::Diablo2_SetKeyBindings()

#IfWinActive

; Don't use a key used for Diablo II, as the hotkey for suspend won't be suspended when running
; 'Suspend On'. Ideally, use a hotkey that won't be used in any applications globally.

; Ctrl+Alt+s to suspend.
^!s::Suspend
; Ctrl+Alt+x to exit.
^!x::ExitApp
