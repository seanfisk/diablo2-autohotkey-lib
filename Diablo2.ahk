#NoEnv
; XXX WatchDirectory has some unset locals. Eventually would be nice to fix.
#Warn, UseUnsetLocal, Off

; Set up CoordMode in the auto-execute section. Because of this,
; scripts which use this library MUST include it instead of just using
; the implicit import from the library of functions feature and MUST
; NOT override CoordMode or SendMode. Use with:
;
;     #Include <Diablo2>

; For windowed mode; doesn't affect fullscreen mode
for __, Category in ["Pixel", "Mouse"] {
	CoordMode, %Category%, Client
}
; Despite what the docs say, there appears to be no way to send clicks
; using SendInput other than the following:
;
;     SendMode, Input
;     Click, X, Y
;
; I believe this is a bug in AutoHotkey. See
; 'source/keyboard_mouse.cpp' in the AutoHotkey source tree for more
; details on when SendInput falls back to other methods.
;
; Here are other options we've tried that don't work:
;
;     SendInput, {Click X, Y}
;
;     SendMode, Input
;     SendInput, {Click X, Y}
;
;     SendMode, Input
;     Send, {Click X, Y}
SendMode, Input

; Each key binding is given in AutoHotkey syntax.
; See <http://ahkscript.org/docs/KeyList.htm>

#Include <JSON>

/**************************************************************************************************
 * BEGIN PUBLIC FUNCTIONS
 */

/**
 * Initialize macros by reading the configuration files and setting up hotkeys. Call this before
 * calling any other Diablo2 functions!
 *
 * Arguments:
 * ControlsConfigPath
 *     Path to JSON config file containing key bindings. This is required.
 * SkillsConfigPath
 *     Path to JSON config file containing weapon set preferences for each skill. Pass as "" to
 *     disable.
 * FillPotionConfigPath
 *     Path to JSON config file for fill potion. Pass as "" to disable.
 * LogPath
 *     Path to log file to create. Pass as "" to disable logging.
 *
 * Return value: None
 */
Diablo2_Init(ControlsConfigPath
	, SkillsConfigPath := ""
	, FillPotionConfigPath := ""
	, LogPath := ""
	, EnableVoiceAlerts := false) {
	Diablo2_InitConstants()
	global Diablo2

	Diablo2.ConfigFiles := {Controls: ControlsConfigPath, Skills: SkillsConfigPath, FillPotion: FillPotionConfigPath}
	Diablo2["Log", "Path"] := LogPath
	Diablo2["Voice", "Enable"] := EnableVoiceAlerts
	Diablo2_Reset("initialized")
}

/**
 * Reset the macros by re-reading the configuration files passed to Diablo2_Init() and resetting
 * internal macro structures.
 *
 * Arguments:
 * Action
 *     Reason why this function is being called
 *
 * Return value: None
 */
Diablo2_Reset(Action := "reset") {
	global Diablo2

	Diablo2.Log.Sep := "|"
	if (Diablo2.Log.Path == "") {
		Diablo2.Log.Func := Func("")
	}
	else {
		Diablo2.Log.FileObj := FileOpen(Diablo2.Log.Path, "a")
		; Separate this session from the last with a newline
		Diablo2.Log.FileObj.Write("`r`n")
		Diablo2.Log.Func := Func("Diablo2_Private_DoLog")
	}
	Diablo2_Log("Logging " . Action)

	; Set up voice
	if (Diablo2.Voice.Enable) {
		Diablo2.Voice.SpVoice := ComObjCreate("SAPI.SpVoice")
		Voices := Diablo2.Voice.SpVoice.GetVoices
		Loop, % Voices.Count {
			; Prefer Hazel (case-insensitive) because I like her voice :)
			Voice := Voices.Item(A_Index - 1)
			if InStr(Voice.GetAttribute("Name"), "Hazel", false) {
				Diablo2.Voice.SpVoice.Voice := Voice
				break
			}
		}

		Diablo2.Voice.Func := Func("Diablo2_Private_DoSpeak")
	}
	else {
		Diablo2.Voice.Func := Func("")
	}
	Diablo2_Log("Voice " . (Diablo2.Voice.Enable ? Action : "disabled"))

	; Configuration
	Diablo2.Controls := Diablo2_Private_SafeParseJSONFile(Diablo2.ConfigFiles.Controls)

	if (Diablo2.ConfigFiles.Skills != "") {
		Diablo2.Skills := {Max: 16
		, WeaponSetForKey: {}
		, SwapKey: Diablo2_Private_RequireControl("Swap Weapons", "Skills")}

		; Turn on context-sensitive hotkey creation
		Hotkey, IfWinActive, % Diablo2.HotkeyCondition

		; Read the config file and assign hotkeys
		WeaponSetForSkill := Diablo2_Private_SafeParseJSONFile(Diablo2.ConfigFiles.Skills)
		Loop, % Diablo2.Skills.Max {
			Key := Diablo2.Controls.Skills[A_Index]
			if (Key != "") {
				Diablo2.Skills.WeaponSetForKey[Key] := WeaponSetForSkill[A_Index]
				; Make each skill a hotkey so we can track the current skill.
				Hotkey, %Key%, SkillHotkeyActivated
			}
		}

		; Turn off context-sensitivity
		Hotkey, IfWinActive

		; Macro state
		Diablo2.Skills.State := {WeaponSet: 1, Skills: ["", ""]}

		Diablo2_Private_SkillsLog("Enabled")
	}
	else {
		Diablo2_Private_SkillsLog("Disabled")
	}

	Diablo2_Private_FillPotionReset()

	; XXX Make setting of this key optional
	Diablo2.MassItem := {StandStillKey: Diablo2_Private_RequireControl("Stand Still", "MassItem")}

	; Set shutdown function
	OnExit("Diablo2_Private_Shutdown")

	if (Action != "initialized") {
		Diablo2_Speak("Macros " . Action)
	}
}

/**
  * Initialize constants used by the macros. If you are using Diablo2_Init(), this will be called
  * for you.
  *
  * Return value: None
  */
Diablo2_InitConstants() {
	global Diablo2 := {HotkeyCondition: "ahk_classDiablo II"
		, Inventory: {TopLeft: {X: 415, Y: 310}, BottomRight: {X: 710, Y: 435}, CellSize: 29}
		, RegistryKey: "HKEY_CURRENT_USER\Software\Blizzard Entertainment\Diablo II"
		, AutoHotkeyLibDir : A_MyDocuments . "\AutoHotkey\Lib"}
}

/**
 * Log a message to the Diablo2 log file. Useful for debugging in this script and your own.
 *
 * Arguments:
 * Message
 *     Message to log
 * Level
 *     Log level to write to output file
 *
 * Return value: None
 */
Diablo2_Log(Message, Level := "DEBUG") {
	global Diablo2
	Diablo2.Log.Func.Call(Message, Level)
}

/**
 * Exit the program with a fatal error, logging the message to the log file.
 *
 * Arguments:
 * Message
 *     Explanation of the error
 *
 * Return value: None
 */
Diablo2_Fatal(Message) {
	Diablo2_Log(Message, "FATAL")
	ExitApp 1
}

/**
 * Speak some text with the configured voice.
 *
 * Argument:
 * Text
 *     String to pronounce
 * Async
 *     Whether to speak asynchronously
 *
 * Return value: None
 */
Diablo2_Speak(Text, Async := True) {
	global Diablo2
	Diablo2.Voice.Func.Call(Text, Async)
}

/**
 * Run the game. There are command-line parameters stored in the registry, but the game seems not
 * to use them. This function reads them and starts the game with them. Typically this contains
 * just -skiptobnet, which starts the game right at the Battle.Net login screen. Calling this in
 * your personal macro file is optional.
 *
 * Return value: None
 */
Diablo2_StartGame() {
	Diablo2_InitConstants()
	global Diablo2
	; XXX: Don't use CmdLine from the registry -- the game modifies this
	; when run. When we pass -skiptobnet, it adds this to CmdLine,
	; too... not sure how to avoid this.
	RegRead, GamePath, % Diablo2.RegistryKey, GamePath
	SplitPath, GamePath, , GameDir
	Run, "%GamePath%" -skiptobnet, %GameDir%
	; We considered saving the PID from this and using ahk_pid to limit hotkeys to that, but it's
	; adding unnecessary complexity. There can be only one Diablo II instance running at a time
	; anyway.
}

/**
 * Auto-configure control for the game.
 * To use, assign to a hotkey, visit "Configure Controls" screen, and press the hotkey.
 *
 * Return value: None
 */
Diablo2_ConfigureControls() {
	global Diablo2

	Diablo2_Log("Configuring controls")

	Diablo2_Private_SuspendAndBlock(true)

	; Flatten the control list for easier duplicate detection.
	FlatControls := []
	for Function, Value in Diablo2.Controls {
		if (Function == "Skills" or Function == "Belt") {
			; Each of these names contain a list of keys.
			for ListIndex, ListElement in Value {
				FlatControls.Push({Function: Format("{} {}", Function, ListIndex), Key: ListElement})
			}
		}
		else {
			FlatControls.Push({Function: Function, Key: Value})
		}
	}

	KeyFunctions := {}
	for _, Control_ in FlatControls {
		Function := Control_.Function
		Key := Control_.Key

		; If the user passed null in the JSON file, delete the binding.
		if (Key == "") {
			Diablo2_Send("{Delete}")
		}
		else {
			; Check for duplicates
			DuplicateKeyFunction := KeyFunctions[Key]
			if (DuplicateKeyFunction != "") {
				Diablo2_Speak(Format("Duplicate key {} for {} and {}"
					, Key, DuplicateKeyFunction, Function), false)
				Diablo2_Fatal(Format("Duplicate key binding '{}' for '{}' and '{}'"
					, Key, DuplicateKeyFunction, Function))
			}
			KeyFunctions[Key] := Function

			; Assign the key binding
			Diablo2_Send("{Enter}" . Diablo2_HotkeySyntaxToSendSyntax(Key))
		}
		Diablo2_Send("{Down}")
	}

	Diablo2_Private_SuspendAndBlock(false)

	Diablo2_Log("Controls assigned")
}

/**
 * Open the inventory.
 *
 * Return value: None
 */
Diablo2_OpenInventory() {
	global Diablo2
	Diablo2_Send(Diablo2_HotkeySyntaxToSendSyntax(Diablo2.Controls["Inventory Screen"]))
}

/**
 * Show the potion belt.
 *
 * Return value: None
 */
Diablo2_ShowBelt() {
	global Diablo2
	Diablo2_Send(Diablo2_HotkeySyntaxToSendSyntax(Diablo2.Controls["Show Belt"]))
}

/**
 * Clear the screen.
 *
 * Return value: None
 */
Diablo2_ClearScreen() {
	global Diablo2
	Diablo2_Send(Diablo2_HotkeySyntaxToSendSyntax(Diablo2.Controls["Clear Screen"]))
}

/**
 * Get the current skill (represented by its hotkey).
 *
 * Return value: the current skill key
 */
Diablo2_SkillGet() {
	global Diablo2
	return Diablo2.Skills.State.Skills[Diablo2.Skills.State.WeaponSet]
}

/**
 * Activate the skill assigned to the specific key.
 *
 * Arguments:
 * Key
 *     The skill hotkey
 *
 * Return value: None
 */
Diablo2_SkillActivate(Key) {
	global Diablo2
	PreferredWeaponSet := Diablo2.Skills.WeaponSetForKey[Key]
	ShouldSwapWeaponSet := (PreferredWeaponSet != "" and PreferredWeaponSet != Diablo2.Skills.State.WeaponSet)

	if (ShouldSwapWeaponSet) {
		; Swap to the other weapon
		Diablo2_Private_SkillsLog("Swapping to weapon set " . PreferredWeaponSet)
		Diablo2_Send(Diablo2.Skills.SwapKey)
		Diablo2.Skills.State.WeaponSet := PreferredWeaponSet
	}

	if (Diablo2.Skills.State.Skills[Diablo2.Skills.State.WeaponSet] != Key) {
		if (ShouldSwapWeaponSet) {
			; If we just switched weapons, we need to sleep very slightly
			; while the game actually swaps weapons.
			Sleep, 70
		}
		Diablo2_Private_SkillsLog(Format("Switching to skill on '{}'", Key))
		Diablo2_Send(Diablo2_HotkeySyntaxToSendSyntax(Key))

		Diablo2.Skills.State.Skills[Diablo2.Skills.State.WeaponSet] := Key
	}
}

/**
 * Perform a one-off skill.
 * This is done by switching to the skill, right-clicking,
 * and switching back to the old skill. For best performance, this
 * skill should not have a weapon set associated with it. But it
 * will work with or without it.
 *
 * Arguments:
 * Key
 *     The skill hotkey
 *
 * Return value: None
 */
Diablo2_SkillOneOff(Key) {
	LButtonIsDown := GetKeyState("LButton")
	CurrentSkill := Diablo2_SkillGet()
	Diablo2_SkillActivate(Key)
	Click, Right
	Diablo2_SkillActivate(CurrentSkill)
	; There are probably times when this isn't necessary, but it's
	; really useful, for example, to keep moving after performing a
	; Teleport. It's useful enough that it's included as the default
	; behavior.
	if (LButtonIsDown) {
		; SendInput is so fast that the game needs time to react.
		Sleep, 20
		Diablo2_Send("{LButton down}")
	}
}

/**
 * Fill the potion belt.
 *
 * Return value: None
 */
Diablo2_FillPotion() {
	global Diablo2
	Diablo2_Private_FillPotionLog("Starting run")
	Diablo2_ClearScreen()
	Diablo2_OpenInventory()
	Diablo2_ShowBelt()
	Diablo2.FillPotion.Function.Call()
}

/**
 * Create needle bitmaps from the contents of the screen.
 *
 * Return value: None
 */
Diablo2_FillPotionGenerateBitmaps() {
	Diablo2_Private_FillPotionLog("Generating new needle bitmaps")
	Diablo2_ClearScreen()
	Diablo2_OpenInventory()
	Sleep, 100 ; Wait for the inventory to appear
	Diablo2_Private_FillPotionTakeScreenshot("Diablo2_Private_FillPotionGenerateBitmaps")
}

/**
 * Send keys in our specific format.
 *
 * Note: Do not use this method to click! See auto-execute section
 * (top of this file) for an explanation.
 *
 * Arguments:
 * Keys
 *     Sequence of keys to send
 */
 Diablo2_Send(Keys) {
	; In the past, we attempted to use this function to send all keys
	; using SendInput so we didn't have to set SendMode. Well, that
	; didn't work (see top of file). But it's benefical that all
	; keystrokes pass through this function, so we could potentially
	; log, etc. in the future with no additional changes.
	SendInput, %Keys%
}

/**
 * Right-click while keeping the left mouse button down.
 *
 * Diablo II has an annoying behavior where right-clicking causes the
 * left mouse button not to be considered as held down. This function
 * fixes that behavior.
 *
 * You can enable this fix globally in your own configuration with:
 *
 *     RButton::Diablo2_RightClick()
 *
 * Return value: None
 */
Diablo2_RightClick() {
	LButtonIsDown := GetKeyState("LButton")
	Diablo2_Send("{RButton down}")
	KeyWait, RButton
	Diablo2_Send("{RButton up}")
	if (LButtonIsDown) {
		Diablo2_Send("{LButton down}")
	}
}

/**
 * Begin an item selection.
 *
 * Return value: None
 */
Diablo2_MassItemSelectStart() {
	global Diablo2
	MouseGetPos, StartX, StartY
	Diablo2_Private_MassItemLog(Format("Selection start is {},{}", StartX, StartY))
	Diablo2.MassItem := {Start: {X: StartX, Y: StartY}}
	Diablo2_Speak("Select")
}

/**
 * Finish definition of an item selection.
 *
 * Return value: None
 */
Diablo2_MassItemSelectEnd() {
	global Diablo2
	Start := Diablo2.MassItem.Start
	if (!Start.X) {
		Message := "No selection started"
		Diablo2_Private_MassItemLog(Message, "ERROR")
		Diablo2_Speak(Message)
		return
	}

	MouseGetPos, EndX, EndY
	End_ := {X: EndX, Y: EndY}
	Size := {}
	TopLeft := {}
	BottomRight := {}
	for Dim in Start {
		TopLeft[Dim] := Diablo2_Private_Min(Start[Dim], End_[Dim])
		BottomRight[Dim] := Diablo2_Private_Max(Start[Dim], End_[Dim])
		Size[Dim] := ((BottomRight[Dim] - TopLeft[Dim]) // Diablo2.Inventory.CellSize) + 1
	}
	NumSelected := Size.X * Size.Y
	Diablo2.MassItem.TopLeft := TopLeft
	Diablo2.MassItem.Size := Size
	Diablo2_Private_MassItemLog(Format("Selected {} cells (start: {},{}; end: {},{}; size: {}x{})"
		, NumSelected, Start.X, Start.Y, End_.X, End_.Y, Size.X, Size.Y))
	Diablo2_Speak(NumSelected)
}

/**
 * Drop items in selection at current mouse position.
 *
 * Return value: None
 */
Diablo2_MassItemDrop() {
	global Diablo2
	if (!Diablo2_Private_MassItemHasSelection()) {
		return
	}
	Size := Diablo2.MassItem.Size
	TopLeft := Diablo2.MassItem.TopLeft

	Diablo2_Private_MassItemLog(Format("Dropping {} cells at {},{}", Size.X * Size.Y, TopLeft.X, TopLeft.Y))
	Diablo2_Speak("Drop")

	MouseGetPos, DestX, DestY
	Offsets := {}

	Diablo2_Private_SuspendAndBlock(true)
	Loop, % Size.Y {
		Offsets.Y := A_Index
		Loop, % Size.X {
			Offsets.X := A_Index
			Source := {}
			for Dim, Offset in Offsets {
				; We need unwrapped (non-object) variables for Click because it sucks
				Source%Dim% := TopLeft[Dim] + (Offset - 1) * Diablo2.Inventory.CellSize
			}
			Click, %SourceX%, %SourceY%
			; Sleep for this much for the Horadric Cube, which takes forever
			; to accept drops apparently.
			Sleep, 300
			; When there is no item in the source cell, a click in the main area will cause the character to move.
			; Send the StandStill key so the character doesn't
			Diablo2_Send(Format("{{}{} down{}}", StandStillKey))
			Click, %DestX%, %DestY%
			Diablo2_Send(Format("{{}{} up{}}", StandStillKey))
			Sleep, 300
		}
	}
	Diablo2_Private_SuspendAndBlock(false)
	Diablo2_Private_MassItemResetVars()
}

/**
 * Move a block of single-cell items to set of empty cells.
 *
 * Return value: None
 */
Diablo2_MassItemMoveSingleCellItems() {
	global Diablo2
	if (!Diablo2_Private_MassItemHasSelection()) {
		return
	}
	Size := Diablo2.MassItem.Size
	MouseGetPos, DestX, DestY
	TopLefts := {Source: Diablo2.MassItem.TopLeft, Dest: {X: DestX, Y: DestY}}

	Diablo2_Private_MassItemLog(Format("Moving {} cells to {},{}"
		, Size.X * Size.Y, Diablo2.MassItem.TopLeft.X, Diablo2.MassItem.TopLeft.Y))
	Diablo2_Speak("Move")

	Offsets := {}

	Diablo2_Private_SuspendAndBlock(true)
	Loop, % Size.Y {
		Offsets.Y := A_Index
		Loop, % Size.X {
			Offsets.X := A_Index
			for Location, TopLeft in TopLefts {
				for Dim, Offset in Offsets {
					; We need unwrapped (non-object) variables for Click because it sucks
					%Location%%Dim% := TopLeft[Dim] + (Offset - 1) * Diablo2.Inventory.CellSize
				}
			}
			Click, %SourceX%, %SourceY%
			Sleep, 300
			Click, %DestX%, %DestY%
			Sleep, 300
		}
	}
	Diablo2_Private_SuspendAndBlock(false)
	Diablo2_Private_MassItemResetVars()
}

/**
 * Convert a key in Hotkey syntax to Send syntax.
 * Currently, if the string is more than one character, we throw curly braces around it. I'm sure
 * this doesn't account for every possible case, but it seems to work.
 *
 * Arguments:
 * HotkeyString
 *     A key string in Hotkey syntax, i.e., with unescaped special keys (e.g. F1 instead of {F1}).
 *
 * Return value: The key in Send syntax.
 */
Diablo2_HotkeySyntaxToSendSyntax(HotkeyString) {
	if (StrLen(HotkeyString) > 1) {
		return "{" HotkeyString "}"
	}
	return HotkeyString
}

/**
 * Suspend the macros.
 *
 * Arguments:
 * Mode
 *     Passed directly to Suspend command
 *
 * Return value: None
 */
Diablo2_Suspend(Mode := "Toggle") {
	Suspend, %Mode%
	Diablo2_Speak(A_IsSuspended ? "Suspended" : "Resumed")
}

/**
 * Exit the macros.
 *
 * Return value: None
 */
Diablo2_Exit() {
	Suspend, Permit
	Diablo2_Speak("Exiting", false)
	ExitApp
}

/**************************************************************************************************
 * BEGIN PRIVATE FUNCTIONS
 */

/**
 * Check to make sure a control is assigned, exiting with an error if not. The key binding is returned in Send
 * syntax.
 *
 * Arguments:
 * Function
 *     Action the control performs
 * Feature
 *     Feature for which the control is needed
 *
 * Return value: Key in Send syntax
 */
Diablo2_Private_RequireControl(Function, Feature) {
	global Diablo2

	Key := Diablo2.Controls[Function]
	if (Key == "") {
		Diablo2_Speak(Format("Control {} required for {}", Function, Feature), false)
		Diablo2_Fatal(Format("Control assignment for {} is required for {}", Function, Feature))
	}
	return Diablo2_HotkeySyntaxToSendSyntax(Key)
}

/**
 * Perform logging of a message.
 *
 * Arguments:
 * Message
 *     Message to log
 * Level
 *     Log level to write to output file
 *
 * Return value: None
 */
Diablo2_Private_DoLog(Message, Level) {
	global Diablo2

	FormatTime, TimeVar, , yyyy-MM-dd HH:mm:ss
	Diablo2.Log.FileObj.Write(Format("{1}.{2}{3}{4}{5}{6}`r`n"
		, TimeVar, A_Msec, Diablo2.Log.Sep, Level, Diablo2.Log.Sep, Message))
	Diablo2.Log.FileObj.Read(0) ; Seems like a hack, but this apparently flushes the write buffer
}

/**
 * Perform speaking of text.
 *
 * Argument:
 * Text
 *     String to pronounce
 * Async
 *     Whether to speak asynchronously
 *
 * Return value: None
 */
Diablo2_Private_DoSpeak(Text, Async) {
	; Include here and not in the auto-execute section ("top of the
	; script"). This is because the auto-execute section is not run when
	; the main script does not use #Include <Diablo2> but does implicit
	; inclusion via the library of functions.
	#Include <TTSConstants>
	global Diablo2
	Flags := SVSFDefault
	if (Async) {
		Flags |= SVSFlagsAsync
	}
	Diablo2.Voice.SpVoice.Speak(Text, Flags)
}

/**
 * Parse a JSON file, checking for existence first.
 *
 * Arguments:
 * FilePath
 *     Path to file containing JSON format.
 *
 * Return value: The top-level object parsed from the JSON file.
 */
Diablo2_Private_SafeParseJSONFile(FilePath) {
	try {
		FileRead, FileContents, %FilePath%
	}
	catch, e {
		Diablo2_Speak("Error reading config file", false)
		Diablo2_Fatal("Error reading file " . FilePath)
	}
	; Pass jsonify=true as the second parameter to allow key-value pairs to be enumerated in the
	; order they were declared.
	; This is important for the controls, where the order does matter.
	return JSON.Load(FileContents, true)
}

/**
 * Turn on/off suspesion of hotkeys and input blocking.
 *
 * Return value: None
 */
Diablo2_Private_SuspendAndBlock(Enable) {
	Mode := Enable ? "On": "Off"
	Suspend, %Mode%
	BlockInput, %Mode%
}

/**
 * Safely create a bitmap from a file.
 *
 * Arguments:
 * FilePath
 *     Path to image file.
 *
 * Return value: The created bitmap
 */
Diablo2_Private_CreateBitmapFromFile(FilePath) {
	global Diablo2
	Bitmap := Gdip_CreateBitmapFromFile(FilePath)
	if (Bitmap <= 0) {
		Diablo2_Speak("Bitmap creation failed", false)
		Diablo2_Fatal("Gdip_CreateBitmapFromFile failed to create bitmap from " . FilePath)
	}
	return Bitmap
}

/**
 * Return the minimum of two parameters.
 */
Diablo2_Private_Min(A, B) {
	return A < B ? A : B
}

/**
* Return the maximum of two parameters.
*/
Diablo2_Private_Max(A, B) {
	return A > B ? A : B
}

Diablo2_Private_SkillsLog(Message) {
	global Diablo2
	Diablo2_Log("Skills" . Diablo2.Log.Sep . Message)
}

Diablo2_Private_MassItemLog(Message, Level := "DEBUG") {
	global Diablo2
	Diablo2_Log("MassItem" . Diablo2.Log.Sep . Message, Level)
}

/**
 * Initialize or reset FillPotion.
 *
 * Arguments:
 * VoiceAlert
 *     Announce status of the reset
 *
 * Return value: None
 */
Diablo2_Private_FillPotionReset(VoiceAlert := false) {
	global Diablo2

	if (Diablo2.ConfigFiles.FillPotion == "") {
		return
	}

	for _, Function in ["Inventory Screen", "Show Belt", "Clear Screen"] {
		Diablo2_Private_RequireControl(Function, "Fill Potion")
	}
	; Read the config file
	Diablo2.FillPotion := Diablo2_Private_SafeParseJSONFile(Diablo2.ConfigFiles.FillPotion)
	; We use screen shots in both windowed and fullscreen to generate
	; bitmaps, so we need the key and installation path for both.
	Diablo2.FillPotion.ScreenShotKey := Diablo2_Private_RequireControl("Screen Shot", "Fill Potion")
	; Find installation directory
	RegRead, InstallPath, % Diablo2.RegistryKey, InstallPath
	Diablo2.InstallPath := InstallPath
	; Set variation if it wasn't provided
	if (Diablo2.FillPotion.Variation == "") {
		; Variation defaults are recommend; they were determined emperically
		Diablo2.FillPotion.Variation := Diablo2.FillPotion.Fullscreen ? 50 : 120
	}
	; Prepare potion structures
	for _, Type_ in ["Healing", "Mana"] {
		Diablo2.FillPotion.Potions[Type_] := ["Minor", "Light", "Regular", "Greater", "Super"]
	}
	Diablo2.FillPotion.Potions["Rejuvenation"] := ["Regular", "Full"]
	; Reverse preference if necessary
	if (!Diablo2.FillPotion.LesserFirst) {
		for Type_, Sizes in Diablo2.FillPotion.Potions {
			; Reverse the array
			; Hints here: http://www.autohotkey.com/board/topic/45876-ahk-l-arrays/
			NewSizes := []
			Loop, % Length := Sizes.Length() {
				NewSizes.Push(Sizes[Length - A_Index + 1])
			}
			Diablo2.FillPotion.Potions[Type_] := NewSizes
		}
	}
	EnableFillPotion := true
	if (Diablo2.FillPotion.Fullscreen) {
		; Start GDI+ for full screen
		Diablo2.GdipToken := Gdip_Startup()
		if (!Diablo2.GdipToken) {
			Diablo2_Speak("GDI+ failed", false)
			Diablo2_Fatal("GDI+ failed to start. Please ensure you have GDI+ on your system and that you are running a 32-bit version of AHK")
		}
		; Cache needle bitmaps
		BitmapLoop:
		for Type_, Sizes in Diablo2.FillPotion.Potions {
			for _, Size in Sizes {
				Bitmap := Gdip_CreateBitmapFromFile(Diablo2_Private_FillPotionImagePath(Type_, Size))
				if (Bitmap <= 0) {
					Diablo2_Private_FillPotionLog("Needle bitmaps not found; please generate them first")
					Diablo2_Speak("Please generate potion bitmaps")
					EnableFillPotion := false
					break, BitmapLoop
				}
				Diablo2.FillPotion["NeedleBitmaps", Type_, Size] := Bitmap
			}
		}
	}
	; Assign function
	Diablo2.FillPotion.Function := Func(EnableFillPotion
		? (Diablo2.FillPotion.Fullscreen
			? "Diablo2_Private_FillPotionFullscreenBegin"
			: "Diablo2_Private_FillPotionWindowed")
		: "")
	Action := EnableFillPotion ? "Enabled" : "Disabled"
	Diablo2_Private_FillPotionLog(Action)
	if (VoiceAlert) {
		Diablo2_Speak("Fill Potion " . Action)
	}
}

/**
 * Write needle bitmaps from a taken screenshot.
 *
 * Return value: None
 */
Diablo2_Private_FillPotionGenerateBitmaps(_1, _2, ScreenshotPath) {
	global Diablo2

	Diablo2_Private_StopWatchDirectory()
	; If we are in fullscreen, dispose the bitmaps so that our
	; PowerShell script can access those paths. The bitmaps will be
	; re-created when calling Diablo2_Reset(). If we are in windowed
	; mode, this is a no-op.
	Diablo2_Private_GdipShutdown()
	Diablo2_Private_FillPotionLog("Running bitmap generation script")
	ScriptPath := Diablo2.AutoHotkeyLibDir . "\GenerateBitmaps.ps1"
	LogPath := A_WorkingDir . "\GenerateBitmaps.log"
	; Don't use -File: https://connect.microsoft.com/PowerShell/feedback/details/750653/powershell-exe-doesn-t-return-correct-exit-codes-when-using-the-file-option
	;
	; The goal is to capture stdout and stderr. RunWait internally uses
	; Wscript.Shell.Run, which doesn't capture the standard streams.
	; Wscript.Shell.Exec does capture the standard streams, but raises a
	; PowerShell console, kicking a fullscreen user to the desktop when
	; it runs. This isn't acceptable, so in lieu of complicated
	; solutions that would drop down to CreateProcess(), we've just
	; decided to write to a temporary file.
	RunWait, powershell -NoLogo -NonInteractive -NoProfile -Command "Start-Transcript '%LogPath%'; & '%ScriptPath%' -Verbose '%ScreenshotPath%'; Stop-Transcript", %A_WorkingDir%, Hide
	ExitCode := ErrorLevel

	; Remove the screen shot; it is not needed any more.
	FileDelete, %ScreenshotPath%

	; Log status
	FileRead, Output, %LogPath%
	FileDelete, %LogPath%
	Diablo2_Private_FillPotionLog(Format("Bitmap generation finished with exit code {} and output:`r`n{}", ExitCode, RTrim(Output, "`r`n")))
	; Check for success
	Status := ExitCode == 0 ? "succeeded" : "failed"
	Diablo2_Private_FillPotionLog("Needle bitmap generation " . Status)
	Diablo2_Speak("Bitmap generation " . Status)
	if (ExitCode == 0) {
		Diablo2_ClearScreen()
		Diablo2_Private_FillPotionReset(true)
	}
}

/**
 * Return the potion image path for a specified type and size.
 *
 * Arguments:
 * Type
 *     Potion type (Healing, Mana, Rejuvenation)
 * Size
 *     Potion size (Minor, Light, Regular, Greater, Super)
 *
 * Return value: the image path
 */
Diablo2_Private_FillPotionImagePath(Type_, Size) {
	global Diablo2
	return Format("{1}\Images\{2}\{3}.png", A_WorkingDir, Type_, Size)
}

/**
 * Perform a click to insert a potion into the belt.
 *
 * Arguments:
 * Coords
 *     The coordinates of the intended click
 *
 * Return value: None
 */
Diablo2_Private_FillPotionClick(Coords) {
	; The sleeps here are totally emperical. Just seems to work best this way.
	Sleep, 150
	MouseGetPos, MouseX, MouseY
	LButtonIsDown := GetKeyState("LButton")

	Diablo2_Send("{Shift down}")
	; Click doesn't support expressions (at all)
	X := Coords.X, Y := Coords.Y
	Click, %X%, %Y%
	Diablo2_Send("{Shift up}")
	MouseMove, MouseX, MouseY
	if (LButtonIsDown) {
		Diablo2_Send("{LButton down}")
	}
	Sleep, 150
}

/**
 * End potion belt insertion and clear the screen.
 *
 * Return value: None
 */
Diablo2_Private_FillPotionEnd() {
	Diablo2_Private_FillPotionLog("Finishing run")
	Diablo2_ClearScreen()
}

Diablo2_Private_FillPotionLog(Message) {
	global Diablo2
	Diablo2_Log("FillPotion" . Diablo2.Log.Sep . Message)
}

Diablo2_Private_FillPotionLogWithType(Type_, Message) {
	global Diablo2
	Diablo2_Private_FillPotionLog(Format("{1:-12}{2}{3}", Type_, Diablo2.Log.Sep, Message))
}

Diablo2_Private_FillPotionLogWithSize(Type_, Size, Message) {
	global Diablo2
	Diablo2_Private_FillPotionLogWithType(Type_, Format("{1:-7}{2}{3}", Size, Diablo2.Log.Sep, Message))
}

/**
 * Fill the potion belt in windowed mode.
 *
 * Return value: None
 */
Diablo2_Private_FillPotionWindowed() {
	global Diablo2

	for Type_, Sizes in Diablo2.FillPotion.Potions {
		LastPotion := {X: -1, Y: -1}
		WindowedSizeLoop:
		for _, Size in Sizes {
			NeedlePath := Diablo2_Private_FillPotionImagePath(Type_, Size)
			Loop {
				ImageSearch, PotionX, PotionY, % Diablo2.Inventory.TopLeft.X, % Diablo2.Inventory.TopLeft.Y, % Diablo2.Inventory.BottomRight.X, % Diablo2.Inventory.BottomRight.Y, % Format("*{} {}", Diablo2.FillPotion.Variation, NeedlePath)
				if (ErrorLevel == 2) {
					Diablo2_Speak("Fill potion error", false)
					Diablo2_Fatal(NeedlePath . Diablo2.Log.Sep . "Needle image file not found")
				}
				if (ErrorLevel == 1) {
					break ; Image not found on the screen.
				}
				Potion := {X: PotionX, Y: PotionY}
				if (LastPotion.X == Potion.X and LastPotion.Y == Potion.Y) {
					Diablo2_Private_FillPotionLogWithType(Type_, "Finished for run due to full belt")
					break, WindowedSizeLoop
				}
				Diablo2_Private_FillPotionLogWithSize(Type_, Size, Format("Clicking {1},{2}", Potion.X, Potion.Y))
				Diablo2_Private_FillPotionClick(Potion)
				LastPotion := Potion
			}
		}
		if (LastPotion.X == -1) {
			Diablo2_Private_FillPotionLogWithType(Type_, "Finished because no potions left")
		}
	}
	Diablo2_Private_FillPotionEnd()
}

/**
 * Take a screenshot and watch the Diablo II installation directory for it.
 *
 * Arguments:
 * Func
 *     Name of callback function (as string)
 *
 * Return value: None
 */
Diablo2_Private_FillPotionTakeScreenshot(CallbackName) {
	global Diablo2

	; Note: InstallPath has a trailing slash
	; 0x10 is FILE_NOTIFY_CHANGE_LAST_WRITE, which gets called when Diablo II creates a screenshot.
	; Triple question marks ("???") don't seem to work, but "*" should be fine.
	WatchDirectory(Diablo2.InstallPath . "|Screenshot*.jpg", Func(CallbackName), 0x10)
	Diablo2_Send(Diablo2.FillPotion.ScreenShotKey)
}

/**
 * Being filling the potion belt in fullscreen mode.
 *
 * Return value: None
 */
Diablo2_Private_FillPotionFullscreenBegin() {
	global Diablo2

	; Initialize structures
	for Type_ in Diablo2.FillPotion.Potions {
		Diablo2.FillPotion["State", Type_] := {SizeIndex: 1, Finished: false, PotionsClicked: []}
	}
	Sleep, 100 ; Wait for the inventory to appear
	Diablo2_Private_FillPotionTakeScreenshot("Diablo2_Private_FillPotionFullscreen")
}

/**
 * Process screenshot to fill the potion belt in fullscreen mode.
 *
 * Return value: None
 */
Diablo2_Private_FillPotionFullscreen(_1, _2, HaystackPath) {
	; In both master (which has incorrect docs) and v2-alpha (which has correct docs), the callback
	; function takes three arguments:
	;
	; - WatchDirectory "this" object (not quite sure what this is)
	; - "from path"
	; - "to path"
	;
	; Both the "from" and "to" paths will be populated for FILE_NOTIFY_CHANGE_LAST_WRITE, but
	; we'll just use the latter.
	global Diablo2

	Diablo2_Private_FillPotionLog("Processing " . HaystackPath)

	; In the past, we tried tic's Gdip_ImageSearch. However, it is broken as reported in the bugs. w and h are supposed (?) to represent width and height; they are used as such in the AHK code but not the C code. This causes problems and an inability to find the needle. We are now using MasterFocus' Gdip_ImageSearch, which works well.
	; http://www.autohotkey.com/board/topic/71100-gdip-imagesearch/
	HaystackBitmap := Diablo2_Private_CreateBitmapFromFile(HaystackPath)
	; Assume we are finished for now; invalidate later if we are not.
	Finished := true

	for Type_, Sizes in Diablo2.FillPotion.Potions {
		if (Diablo2.FillPotion.State[Type_].Finished) {
			; We have already finished finding potions of this type.
			continue
		}
		PotionsClicked := []
		PotionSizeLoop:
		Loop {
			Size := Sizes[Diablo2.FillPotion.State[Type_].SizeIndex]
			Diablo2_Private_FillPotionLogWithSize(Type_, Size, "Searching")
			NumPotionsFound := Gdip_ImageSearch(HaystackBitmap
				, Diablo2.FillPotion.NeedleBitmaps[Type_][Size]
				, CoordsListString
				, Diablo2.Inventory.TopLeft.X, Diablo2.Inventory.TopLeft.Y
				, Diablo2.Inventory.BottomRight.X, Diablo2.Inventory.BottomRight.Y
				, Diablo2.FillPotion.Variation
				; These two blank parameters are transparency color and search direction.
				, ,
				; For the number of instances to find, pass one more than the user requested so that we
				; can terminate early if possible. If they passed 0, find all instances with 0.
				, Diablo2.FillPotion.FullscreenPotionsPerScreenshot == 0 ? 0 : Diablo2.FillPotion.FullscreenPotionsPerScreenshot + 1)

			; Anything less than 0 indicates an error.
			if (NumPotionsFound < 0) {
				Diablo2_Speak("Fill potion error", false)
				Diablo2_Fatal("Gdip_ImageSearch call failed with error code " . NumPotionsFound)
			}

			; Collect all the potions we found into an array.
			PotionsFound := []
			for _3, CoordsString in StrSplit(CoordsListString, "`n") {
				Coords := StrSplit(CoordsString, "`,")
				PotionFound := {X: Coords[1], Y: Coords[2]}
				Diablo2_Private_FillPotionLogWithSize(Type_, Size, Format("Found at {1},{2}", PotionFound.X, PotionFound.Y))
				; If any of the potions found were clicked before, the potion belt is already full
				; of this type and we are finished with it.
				for _4, PotionClicked in Diablo2.FillPotion.State[Type_].PotionsClicked {
					if (PotionFound.X == PotionClicked.X and PotionFound.Y == PotionClicked.Y) {
						Diablo2.FillPotion.State[Type_].Finished := true
						Diablo2_Private_FillPotionLogWithType(Type_, "Finished for run due to full belt")
						break, PotionSizeLoop
					}
				}
				PotionsFound.Push(PotionFound)
			}

			; Click potions.
			NumPotionsToClick := (Diablo2.FillPotion.FullscreenPotionsPerScreenshot == 0
				? NumPotionsFound
				: Diablo2_Private_Min(NumPotionsFound
					, Diablo2.FillPotion.FullscreenPotionsPerScreenshot - PotionsClicked.Length()))
			Loop, % NumPotionsToClick {
				Potion := PotionsFound[A_Index]
				Diablo2_Private_FillPotionLogWithSize(Type_, Size, Format("Clicking {1},{2}", Potion.X, Potion.Y))
				Diablo2_Private_FillPotionClick(Potion)
				PotionsClicked.Push(Potion)
			}

			if (Diablo2.FillPotion.FullscreenPotionsPerScreenshot > 0
				and PotionsClicked.Length() >= Diablo2.FillPotion.FullscreenPotionsPerScreenshot) {
				; We can't click any more potions for this screenshot.
				Finished := false
				Diablo2_Private_FillPotionLogWithType(Type_, "Finished for screenshot")
				break
			}

			; Move on to the next size.
			++Diablo2.FillPotion.State[Type_].SizeIndex

			; Check to see if we have run out of potion sizes for this type. This has happened if
			; the size index has been incremented beyond the bounds of the size array.
			if Diablo2.FillPotion.State[Type_].SizeIndex > Sizes.Length() {
				Diablo2.FillPotion.State[Type_].Finished := true
				Diablo2_Private_FillPotionLogWithType(Type_, "Finished because no potions left")
				break
			}
		}

		; Record all the potions of this type we clicked for this screenshot.
		Diablo2.FillPotion.State[Type_].PotionsClicked := PotionsClicked
	}

	Gdip_DisposeImage(HaystackBitmap)
	; Remove the screen shot; it is not needed any more.
	FileDelete, %HaystackPath%

	if (Finished) {
		; If we are still considered finished, check to see if every type has finished.
		for Type_, Obj in Diablo2.FillPotion.State {
			if (!Obj.Finished) {
				; We still have potions over which to iterate.
				Finished := false
			}
		}
	}
	if (Finished) {
		Diablo2_Private_StopWatchDirectory()
		Diablo2_Private_FillPotionEnd()
	}
	else {
		Diablo2_Private_FillPotionLog("Requesting updated screenshot")
		; Wait slightly for the game to update
		; Sleep, 100

		; Get the next screenshot
		Diablo2_Send(Diablo2.FillPotion.ScreenShotKey)
	}
}

/**
 * Determine if there is an existing item selection.
 *
 * Return value: Boolean indicating existence of selection
 */
Diablo2_Private_MassItemHasSelection() {
	global Diablo2
	HasSelection := Diablo2.MassItem.Size.X and Diablo2.MassItem.TopLeft.X
	if (!HasSelection) {
		Message := "No selection found"
		Diablo2_Private_MassItemLog(Message, "ERROR")
		Diablo2_Speak(Message)
	}
	return HasSelection
}

/**
 * Reset item selection.
 *
 * Return value: None
 */
Diablo2_Private_MassItemResetVars() {
	global Diablo2
	Diablo2.MassItem.Start := {}
	Diablo2.MassItem.Size := {}
	Diablo2.MassItem.TopLeft := {}
}

/**
 * Stop watching for new screenshots.
 *
 * Return value: None
 */
Diablo2_Private_StopWatchDirectory() {
	WatchDirectory("")
}

/**
 * Dispose images and shut down GDI+.
 *
 * Return value: None
 */
Diablo2_Private_GdipShutdown() {
	global Diablo2
	if (Diablo2.HasKey("GdipToken")) {
		For Type_, Sizes in Diablo2.FillPotion.NeedleBitmaps {
			For _, Bitmap in Sizes {
				Gdip_DisposeImage(Bitmap)
			}
		}
		Gdip_Shutdown(Diablo2.GdipToken)
	}
}

/**
 * Perform shutdown tasks. Only needed for FillPotion Fullscreen mode.
 *
 * Return value: None
 */
Diablo2_Private_Shutdown() {
	global Diablo2
	Diablo2_Log("Shutting down")
	Diablo2_Log("Stopping directory watches")
	Diablo2_Private_StopWatchDirectory()
	Diablo2_Private_GdipShutdown()
	if (Diablo2.Log.HasKey("FileObj")) {
		Diablo2_Log("Closing log")
		Diablo2.Log.FileObj.Close()
	}
}

goto, End

; Handle all skill hotkeys with a preferred weapon set.
SkillHotkeyActivated:
Diablo2_SkillActivate(A_ThisHotkey)
return

End:
