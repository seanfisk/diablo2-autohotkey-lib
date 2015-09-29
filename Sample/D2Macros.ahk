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
Diablo2.Init("Controls.json"
	; An empty object means "enable the feature with the default settings".
	;
	; Enable logging to create a file in this directory and log information to it. I *highly
	; recommend* leaving logging on, as it makes debugging problems with the macros much easier.
	, {Log: {}
		; Enable voice alerts. Helpful for feedback from the macro while in-game.
		, Voice: {}
		, Skills: "Skills.json"
		, MassItem: {}
		, FillPotion: {Fullscreen: true}})

; Ctrl+Alt+a to auto-configure controls.
; '^' is Control, '!' is Alt, and 'a' is the a key.
Diablo2.AssignMultiple({"^!a": "Controls.AutoAssign"
		, "^!b": "FillPotion.GenerateBitmaps"
		, "^!r": "Reset"
		, "^!t": "Status"
		; Just 'f' runs FillPotion.
		, "f": "FillPotion.Activate"
		; Enable the right-click fix globally.
		, "RButton": "RightClick"
		; Mass item macros
		, "6": "MassItem.SelectStart"
		, "7": "MassItem.SelectEnd"
		, "8": "MassItem.Drop"
		, "9": "MassItem.MoveSingleCellItems"}
	; Means activate in the game only.
	, true)

; Activate any new hotkeys created with the Hotkey command only in the Diablo II game itself.
Hotkey, IfWinActive, % Diablo2.HotkeyCondition

; Assign Town Portal to F8 in the game. Now F8 will activate Town Portal, use it, and switch back to
; the last skill.
Key := "F8"
Function := ObjBindMethod(Diablo2.Skills, "OneOff", Key)
Hotkey, %Key%, %Function%

; Activate any new hotkeys created with the Hotkey command in any application.
Hotkey, IfWinActive

; These hotkeys are assigned through a Diablo2 wrapper because they should be activated even under
; suspension.
;
; Don't use a key used for Diablo II, as the hotkey for suspend itself won't be suspended. Ideally,
; use a hotkey that won't be used in any applications globally.
Diablo2.AssignMultiple({"^!s": "Suspend"
		; Quit the macros
		, "^!x": "Exit"}
	; Means activate in any application.
	, false)

; An alternate way to assign custom hotkeys. Unlike Hotkey, this has to be at the end of the file.
;#IfWinActive ahk_class Diablo II

;F8::Diablo2.Skills.OneOff("F8")

;#IfWinActive
