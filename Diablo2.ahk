#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.

; Each key binding is given in AutoHotkey syntax.
; See <http://ahkscript.org/docs/KeyList.htm>

#Include <JSON>

/**************************************************************************************************
 * BEGIN PUBLIC FUNCTIONS
 *************************************************************************************************/

/**
 * Initialize macros. Call this before calling any other Diablo2 functions!
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
	Global Diablo2 :=  {NumSkills: 16, WindowClass: "Diablo II"}
	; Configuration
	Diablo2.KeysConfig := Diablo2_Private_SafeParseJSONFile(KeysConfigFilePath)

	if (SkillWeaponSetConfigFilePath != "") {
		; Read the config file
		Diablo2.SkillWeaponSetConfig := Diablo2_Private_SafeParseJSONFile(SkillWeaponSetConfigFilePath)
		Diablo2.SkillKeyToWeaponSetMapping := {}
		Diablo2.SwapWeaponsKey := Diablo2.KeysConfig["Swap Weapons"]

		; Set up the skill mappings

		; Make hotkeys created in the loop only active in the "Diablo II" window.
		Hotkey, IfWinActive, % "ahk_class" Diablo2.WindowClass

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

/**************************************************************************************************
 * BEGIN PRIVATE FUNCTIONS
 *************************************************************************************************/

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
	return JSON.parse(FileContents, true)
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

goto, End

; Handle all skill hotkeys with a preferred weapon set.
SkillHotkeyActivated:
Diablo2_Private_ActivateSkill(A_ThisHotkey)
return

End:
