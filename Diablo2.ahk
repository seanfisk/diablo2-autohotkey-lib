#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
; IMPORTANT: Needed in windowed mode to find the correct coordinates.
CoordMode, Pixel, Client
CoordMode, Mouse, Client

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
 * KeysConfigFilePath
 *     A path to a JSON config file containing key mappings.
 * SkillWeaponSetConfigFilePath
 *     A path to a JSON config file containing weapon set preferences for each skill.
 *     Pass this as "" to disable skill/weapon set association.
 *
 * Return value: None
 */
Diablo2_Init(KeysConfigFilePath, SkillWeaponSetConfigFilePath) {
	; From the inventory image, the Y coordinates are 314, 435. But I think in windowed mode, it's counting the title bar in the coordinates.
	Global Diablo2 := {NumSkills: 16, HotkeyCondition: "ahk_classDiablo II", InventoryCoords: {TopLeft: {X: 418, Y: 342}, BottomRight: {X: 710, Y: 462}}, ImagesDir: A_MyDocuments . "\AutoHotkey\Lib\Images"}
	; Configuration
	Diablo2.KeysConfig := Diablo2_Private_SafeParseJSONFile(KeysConfigFilePath)

	if (SkillWeaponSetConfigFilePath != "") {
		; Read the config file
		Diablo2.SkillWeaponSetConfig := Diablo2_Private_SafeParseJSONFile(SkillWeaponSetConfigFilePath)
		Diablo2.SkillKeyToWeaponSetMapping := {}
		Diablo2.SwapWeaponsKey := Diablo2.KeysConfig["Swap Weapons"]

		; Set up the skill mappings
		Hotkey, IfWinActive, % Diablo2.HotkeyCondition

		Loop, % Diablo2.NumSkills {
			SkillKey := Diablo2.KeysConfig.Skills[A_Index]
			SkillWeaponSet := Diablo2.SkillWeaponSetConfig[A_Index]
			if (SkillKey != "") {
				Diablo2.SkillKeyToWeaponSetMapping[SkillKey] := SkillWeaponSet
				; Make each skill a hotkey so we can track the current skill.
				Hotkey, %SkillKey%, SkillHotkeyActivated
			}
		}

		; Turn off context-sensitive hotkey creation.
		Hotkey, IfWinActive

		; Macro state
		Diablo2.CurrentWeaponSet := 1
		Diablo2.CurrentSkills := ["", ""]
	}
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
	Global Diablo2
	for _, Var in ["GamePath", "CmdLine"] {
		; CmdLine typically contains -skiptobnet, which is what we want. But this allows the user
		; to change it through the registry as well.
		RegRead, %Var%, HKEY_CURRENT_USER\Software\Blizzard Entertainment\Diablo II, %Var%
	}
	SplitPath, GamePath, , GameDir
	Run, %GamePath% %CmdLine%, %GameDir%
	; We considered saving the PID from this and using ahk_pid to limit hotkeys to that, but it's
	; adding unnecessary complexity. There can be only one Diablo II instance running at a time
	; anyway.
}

/**
 * Set key bindings for the game.
 * To use, assign to a hotkey, visit "Configure Controls" screen, and press the hotkey.
 *
 * Return value: None
 */
Diablo2_SetKeyBindings() {
	Global Diablo2
	; Suspend all hotkeys while assigning key bindings.
	Suspend On

	for KeyFunction, Value in Diablo2.KeysConfig
	{
		if (KeyFunction == "Skills" or KeyFunction == "Belt") {
			; Each of these names contain a list of keys.
			for ListIndex, ListElement in Value {
				Diablo2_Private_AssignKeyAndAdvance(ListElement)
			}
		}
		else {
			Diablo2_Private_AssignKeyAndAdvance(Value)
		}
	}

	; Turn hotkeys back on.
	Suspend Off
}

/**
 * Fill the potion belt from the inventory.
 * Currently, the game must be windowed for this macro to work. There are plans to support full
 * screen in the future.
 *
 * Arguments:
 * Prefer
 *     Specify which size potions to prefer: "Greater" for potions with more points, "Lesser"
 *     for potions with less points.
 *
 * Return value: None
 */
Diablo2_FillPotion(Prefer := "Lesser") {
	global Diablo2
	; Save mouse position.
	MouseGetPos, OldMouseX, OldMouseY
	; Open inventory and ready for insertion into potion belt.
	Send, % Diablo2_Private_HotkeySyntaxToSendKeySyntax(Diablo2.KeysConfig["Inventory Screen"]) "{Shift down}"
	; Fill potions of each type.
	for _, Type_ in ["Healing", "Mana"] {
		Diablo2_Private_FillPotionType(Type_, ["Minor", "Light", "Regular", "Greater", "Super"], Prefer)
	}
	Diablo2_Private_FillPotionType("Rejuvenation", ["Regular", "Full"], Prefer)

	; End insertion and clear screen
	Send, % "{Shift up}" Diablo2_Private_HotkeySyntaxToSendKeySyntax(Diablo2.KeysConfig["Clear Screen"])
	; Move the mouse back.
	MouseMove, OldMouseX, OldMouseY
}

/**************************************************************************************************
 * BEGIN PRIVATE FUNCTIONS
 */

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
		; FileRead is supposed to throw if placed inside a try block, but it doesn't seem to do so.
		; We will just throw our own helpful error.
		FileRead, FileContents, %FilePath%
	}
	catch, e {
		throw, Exception("Error reading file: " FilePath)
	}
	; Pass jsonify=true as the second parameter to allow key-value pairs to be enumerated in the
	; order they were declared.
	; This is important for the key bindings, where the order does matter.
	return JSON.Load(FileContents, true)
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
Diablo2_Private_HotkeySyntaxToSendKeySyntax(HotkeyString) {
	if (StrLen(HotkeyString) > 1) {
		return "{" HotkeyString "}"
	}
	return HotkeyString
}

/**
 * Assign a single key binding in the "Configure Controls" screen, advancing to the next control
 * afterward.
 *
 * Arguments:
 * KeyString
 *     The key to assign to the current control, in Hotkey syntax.
 *
 * Return value: None
 */
Diablo2_Private_AssignKeyAndAdvance(KeyString) {
	Global Diablo2
	if (KeyString == "") {
		Send, {Delete}
	}
	else {
		Send, % "{Enter}" Diablo2_Private_HotkeySyntaxToSendKeySyntax(KeyString)
	}
	Send, {Down}
}

/**
 * Activate the skill indicated by the hotkey pressed.
 *
 * Arguments:
 * SkillKey
 *     The pressed skill hotkey.
 *
 * Return value: None
 */
Diablo2_Private_ActivateSkill(SkillKey) {
	Global Diablo2
	PreferredWeaponSet := Diablo2.SkillKeyToWeaponSetMapping[SkillKey]
	SwitchWeaponSet := (PreferredWeaponSet != ""
		and PreferredWeaponSet != Diablo2.CurrentWeaponSet)

	; Suspend all hotkeys while this stuff is happening.
	; This decreases the chance of the game and macros getting out-of-sync.
	Suspend, On

	if (SwitchWeaponSet) {
		; Swap to the other weapon
		SwapWeaponsKey := Diablo2.SwapWeaponsKey
		Send, % Diablo2.SwapWeaponsKey
		Diablo2.CurrentWeaponSet := PreferredWeaponSet
	}

	if (Diablo2.CurrentSkills[Diablo2.CurrentWeaponSet] != SkillKey) {
		if (SwitchWeaponSet) {
			; If we just switched weapons, we need to sleep very slightly
			; while the game actually swaps weapons.
			Sleep, 70
		}

		Send, % Diablo2_Private_HotkeySyntaxToSendKeySyntax(SkillKey)

		Diablo2.CurrentSkills[Diablo2.CurrentWeaponSet] := SkillKey
	}

	; Turn on hotkeys.
	Suspend, Off
}

/**
 * Fill the potion belt with potions of a specified type.
 *
 * Arguments:
 * Type
 *     The type of potion, either "Healing", "Mana", or "Rejuvenation".
 * Sizes
 *     Array of potion sizes to insert.
 *
 * Return value: None
 */
Diablo2_Private_FillPotionType(Type_, Sizes, Prefer) {
	global Diablo2
	if (Prefer == "Greater") {
		; Reverse the array
		; Hints here: http://www.autohotkey.com/board/topic/45876-ahk-l-arrays/
		Loop, % Sizes.Length() {
			Sizes.InsertAt(0, Sizes.Pop())
		}
	}

	LastPotion := {X: -1, Y: -1}
	; Get the mouse out of the way; it can interfere with the ImageSearch. This position is just above the inventory.
	NonInterferenceCoords := {X: 550, Y: 310}
	MouseMove, % NonInterferenceCoords.X, % NonInterferenceCoords.Y
	SizeLoop:
	For _, Size in Sizes {
		ImagePath := Format("{1}\{2}\{3}.png", Diablo2.ImagesDir, Type_, Size)
		Loop {
			ImageSearch, PotionX, PotionY, % Diablo2.InventoryCoords.TopLeft.X, % Diablo2.InventoryCoords.TopLeft.Y, % Diablo2.InventoryCoords.BottomRight.X, % Diablo2.InventoryCoords.BottomRight.Y, *130 %ImagePath%
			if (ErrorLevel == 2) {
				MsgBox, % "Image file not found " . ImagePath
				ExitApp
			}
			if (ErrorLevel == 1) {
				break ; Image not found on the screen.
			}
			if (LastPotion.X == PotionX and LastPotion.Y == PotionY) {
				break, SizeLoop ; Potion belt is full of potions of this type.
			}
			; The sleeps here are totally emperical. Just seems to work best this way.
			Sleep, 100
			Click, %PotionX%, %PotionY%
			MouseMove, % NonInterferenceCoords.X, % NonInterferenceCoords.Y
			Sleep, 100
			LastPotion := {X: PotionX, Y: PotionY}
		}
	}
}

goto, End

; Handle all skill hotkeys with a preferred weapon set.
SkillHotkeyActivated:
Diablo2_Private_ActivateSkill(A_ThisHotkey)
return

End:
