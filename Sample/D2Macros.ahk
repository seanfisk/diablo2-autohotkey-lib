; AutoHotkey uses the name of script in the system tray. We name the
; script D2Macros so that its purpose is obvious when looking in the
; tray.

; Replace an old instance of the macros with a new one.
#SingleInstance Force
; Allow the library to find the config files in this directory.
SetWorkingDir %A_ScriptDir%

#Include <Diablo2>

; Initialize the macros by giving the paths to the configuration
; files.
Diablo2_Init("Controls.json"
	, "Skills.json"
	, "FillPotion.json"
	; Passing "Log.txt" creates that file in this directory and logs
	; information to it. I *highly recommend* leaving logging on, as it
	; makes debugging problems with the macros much easier.
	, "Log.txt"
	; Enable voice alerts. Helpful for feedback from the macro while
	; in-game.
	, true)

; Activate the following hotkeys only in the Diablo II game itself.
#IfWinActive ahk_class Diablo II

; Ctrl+Alt+a to auto-configure controls.
; '^' is Control, '!' is Alt, and 'a' is the a key.
^!a::Diablo2_ConfigureControls()
^!b::Diablo2_FillPotionGenerateBitmaps()
^!r::Diablo2_Reset()
; Just 'f' runs FillPotion.
f::Diablo2_FillPotion()
; Assign Town Portal to F8 in the game. Now F8 will activate Town
; Portal, use it, and switch back to the last skill.
F8::Diablo2_SkillOneOff("F8")
; Enable the right-click fix globally.
RButton::Diablo2_RightClick()

; Activate the following hotkeys in any application.
#IfWinActive

; Don't use a key used for Diablo II, as the hotkey for suspend itself
; won't be suspended. Ideally, use a hotkey that won't be used in any
; applications globally.
^!s::Diablo2_Suspend()
; Quit the macros
^!x::Diablo2_Exit()
