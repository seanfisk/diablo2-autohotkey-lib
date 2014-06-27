#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

Diablo2_Init("Keys.json", "SkillWeaponSets.json")

#IfWinActive ahk_class Diablo II

/::Diablo2_SetKeyBindings()

#IfWinActive

F11::Suspend
F12::ExitApp