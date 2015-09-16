#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; Don't warn; libraries we include have too many errors :|
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
; IMPORTANT: Needed in windowed mode to find the correct coordinates.
CoordMode, Pixel, Client
CoordMode, Mouse, Client

; Each key binding is given in AutoHotkey syntax.
; See <http://ahkscript.org/docs/KeyList.htm>

#Include <JSON>
; Include these here, otherwise it will try to include at the end and mess up because of our labels.
; It's hacky, but it seems to work.
#Include <Gdip>
#Include <sizeof>
#Include <_Struct>
#Include <WatchDirectory>
#Include <Gdip_ImageSearch>

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
 * Fullscreen
 *     Pass this as true to indicate you are playing in fullscreen mode. Pass as false to indicate
 *     windowed mode. This is used to determine which technique by which to retrieve the contents
 *     of the screen for filling potions.
 *
 * Return value: None
 */
Diablo2_Init(KeysConfigFilePath, SkillWeaponSetConfigFilePath := "", FillPotionConfigFilePath := "") {
	Diablo2_InitConstants()
	global Diablo2

	; Configuration
	Diablo2.Keys := Diablo2_Private_SafeParseJSONFile(KeysConfigFilePath)

	; Set up keyboard mappings
	Hotkey, IfWinActive, % Diablo2.HotkeyCondition

	if (SkillWeaponSetConfigFilePath != "") {
		Diablo2.Skills := {Max: 16
		, WeaponSetForKey: {}
		, SwapKey: Diablo2_Private_HotkeySyntaxToSendSyntax(Diablo2.Keys["Swap Weapons"])}

		; Read the config file and assign hotkeys
		WeaponSetForSkill := Diablo2_Private_SafeParseJSONFile(SkillWeaponSetConfigFilePath)
		Loop, % Diablo2.Skills.Max {
			Key := Diablo2.Keys.Skills[A_Index]
			if (Key != "") {
				Diablo2.Skills.WeaponSetForKey[Key] := WeaponSetForSkill[A_Index]
				; Make each skill a hotkey so we can track the current skill.
				Hotkey, %Key%, SkillHotkeyActivated
			}
		}

		; Macro state
		Diablo2.Skills.Current := {WeaponSet: 1, Skills: ["", ""]}
	}

	if (FillPotionConfigFilePath != "") {
		; Read the config file
		Diablo2.FillPotion := Diablo2_Private_SafeParseJSONFile(FillPotionConfigFilePath)
		Diablo2.FillPotion.Variation := 100

		if (Diablo2.FillPotion.Fullscreen) {
			; Ensure Screen Shot key is assigned
			if (Diablo2.Keys["Screen Shot"] == "") {
				MsgBox, Key for Screen Shot is not assigned; cannot capture screen.
				ExitApp
			}

			; Start GDI+ for full screen
			Diablo2.GdipToken := Gdip_Startup()
			if (!Diablo2.GdipToken) {
				MsgBox, GDI+ failed to start. Please ensure you have GDI+ on your system.
				ExitApp
			}
			OnExit("Diablo2_Private_Shutdown")

			; Find installation directory
			RegRead, InstallPath, % Diablo2.RegistryKey, InstallPath
			Diablo2.InstallPath := InstallPath
		}
		else {
			; Compensate for incorrect coordinates in windowed mode
			For Location in Diablo2.InventoryCoords {
				Diablo2.InventoryCoords[Location].Y += 25
			}
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

		; Assign function
		Diablo2.FillPotion.Function := Func(Diablo2.FillPotion.Fullscreen ? "Diablo2_Private_FillPotionFullscreenWatchDirectory" : "Diablo2_Private_FillPotionWindowed")

		; Assign hotkey
		Hotkey, % Diablo2.FillPotion.Key, FillPotionHotkeyActivated
	}

	; Turn off context-sensitive hotkey creation.
	Hotkey, IfWinActive
}

/**
  * Initialize constants used by the macros. If you are using Diablo2_Init(), this will be called
  * for you.
  *
  * Return value: None
  */
 Diablo2_InitConstants() {
	global Diablo2 := {HotkeyCondition: "ahk_classDiablo II"
		, InventoryCoords: {TopLeft: {X: 415, Y: 310}, BottomRight: {X: 710, Y: 435}}
		, ImagesDir: A_MyDocuments . "\AutoHotkey\Lib\Images"
		, RegistryKey: "HKEY_CURRENT_USER\Software\Blizzard Entertainment\Diablo II"}
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
	for _, Var in ["GamePath", "CmdLine"] {
		; CmdLine typically contains -skiptobnet, which is what we want. But this allows the user
		; to change it through the registry as well.
		RegRead, %Var%, % Diablo2.RegistryKey, %Var%
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
	global Diablo2
	; Suspend all hotkeys while assigning key bindings.
	Suspend On

	for KeyFunction, Value in Diablo2.Keys
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
 * Open the inventory.
 *
 * Return value: None
 */
Diablo2_OpenInventory() {
	global Diablo2
	Send, % Diablo2_Private_HotkeySyntaxToSendSyntax(Diablo2.Keys["Inventory Screen"])
}

/**
 * Clear the screen.
 *
 * Return value: None
 */
Diablo2_ClearScreen() {
	global Diablo2
	Send, % Diablo2_Private_HotkeySyntaxToSendSyntax(Diablo2.Keys["Clear Screen"])
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
Diablo2_Private_HotkeySyntaxToSendSyntax(HotkeyString) {
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
	global Diablo2
	if (KeyString == "") {
		Send, {Delete}
	}
	else {
		Send, % "{Enter}" Diablo2_Private_HotkeySyntaxToSendSyntax(KeyString)
	}
	Send, {Down}
}

/**
 * Activate the skill indicated by the hotkey pressed.
 *
 * Arguments:
 * Key
 *     The pressed skill hotkey.
 *
 * Return value: None
 */
Diablo2_Private_ActivateSkill(Key) {
	global Diablo2
	PreferredWeaponSet := Diablo2.Skills.WeaponSetForKey[Key]
	SwitchWeaponSet := (PreferredWeaponSet != "" and PreferredWeaponSet != Diablo2.Skills.Current.WeaponSet)

	; Suspend all hotkeys while this stuff is happening.
	; This decreases the chance of the game and macros getting out-of-sync.
	Suspend, On

	if (SwitchWeaponSet) {
		; Swap to the other weapon
		Send, % Diablo2.Skills.SwapKey
		Diablo2.Skills.Current.WeaponSet := PreferredWeaponSet
	}

	if (Diabl2.Skills.Current.Skills[Diablo2.Skills.Current.WeaponSet] != Key) {
		if (SwitchWeaponSet) {
			; If we just switched weapons, we need to sleep very slightly
			; while the game actually swaps weapons.
			Sleep, 70
		}

		Send, % Diablo2_Private_HotkeySyntaxToSendSyntax(Key)

		Diabl2.Skills.Current.Skills[Diablo2.Skills.Current.WeaponSet] := Key
	}

	; Turn on hotkeys.
	Suspend, Off
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
	return Format("{1}\{2}\{3}.png", Diablo2.ImagesDir, Type_, Size)
}

/**
 * Open inventory and prepare for potion belt insertion.
 *
 * Return value: None
 */
Diablo2_Private_FillPotionBegin() {
	Diablo2_OpenInventory()
	Send, {Shift down}
}

/**
 * Perform a click to insert a potion into the belt.
 *
 * Arguments:
 * Coords
 *     Coordinates of the intended click.
 *
 * Return value: None
 */
Diablo2_Private_FillPotionClick(X, Y) {
	; The sleeps here are totally emperical. Just seems to work best this way.
	;Sleep, 100
	MouseGetPos, MouseX, MouseY
	LButtonIsDown := GetKeyState("LButton")
	; Click doesn't support expressions (at all). Hence the use of X and Y above.
	Click, %X%, %Y%
	MouseMove, MouseX, MouseY
	if (LButtonIsDown) {
		Send, {LButton down}
	}
	Sleep, 100
}

/**
 * End potion belt insertion and clear the screen.
 *
 * Return value: None
 */
Diablo2_Private_FillPotionEnd() {
	Send, {Shift up}
	Diablo2_ClearScreen()
}

/**
 * Call the configured fill potion function.
 *
 * Return value: None
 */
Diablo2_Private_FillPotionActivated() {
	global Diablo2
	Diablo2.FillPotion.Function.Call()
}

/**
 * Fill the potion belt in windowed mode.
 *
 * Return value: None
 */
Diablo2_Private_FillPotionWindowed() {
	global Diablo2

	Diablo2_Private_FillPotionBegin()
	for Type_, Sizes in Diablo2.FillPotion.Potions {
		LastPotion := {X: -1, Y: -1}
		WindowedSizeLoop:
		for _, Size in Sizes {
			NeedlePath := Diablo2_Private_FillPotionImagePath(Type_, Size)
			Loop {
				ImageSearch, PotionX, PotionY, % Diablo2.InventoryCoords.TopLeft.X, % Diablo2.InventoryCoords.TopLeft.Y, % Diablo2.InventoryCoords.BottomRight.X, % Diablo2.InventoryCoords.BottomRight.Y, % Format("*{1} {2}", Diablo2.FillPotion.Variation, NeedlePath)
				if (ErrorLevel == 2) {
					MsgBox, % "Needle image file not found " . NeedlePath
					ExitApp
				}
				if (ErrorLevel == 1) {
					break ; Image not found on the screen.
				}
				if (LastPotion.X == PotionX and LastPotion.Y == PotionY) {
					break, WindowedSizeLoop ; Potion belt is full of potions of this type.
				}
				Diablo2_Private_FillPotionClick(PotionX, PotionY)
				LastPotion := {X: PotionX, Y: PotionY}
			}
		}
	}
	Diablo2_Private_FillPotionEnd()
}

/**
 * Watch the Diablo II installation directory for new screenshots.
 *
 * Return value: None
 */
Diablo2_Private_FillPotionFullscreenWatchDirectory() {
	global Diablo2

	Diablo2_Private_FillPotionBegin()
	; Note: InstallPath has a trailing slash
	; 0x10 is FILE_NOTIFY_CHANGE_LAST_WRITE, which gets called when Diablo II creates a screenshot.
	; Triple question marks ("???") don't seem to work, but "*" should be fine.
	WatchDirectory(Diablo2.InstallPath . "|Screenshot*.jpg", Func("Diablo2_Private_FillPotionFullscreen"), 0x10)
	Sleep, 100 ; Wait for the inventory to appear
	Send, % Diablo2_Private_HotkeySyntaxToSendSyntax(Diablo2.Keys["Screen Shot"])
}

/**
 * Fill the potion belt in fullscreen mode.
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

	WatchDirectory("") ; Stop watching directory

	; In the past, we tried tic's Gdip_ImageSearch. However, it is broken as reported in the bugs. w and h are supposed (?) to represent width and height; they are used as such in the AHK code but not the C code. This causes problems and an inability to find the needle. We are now using MasterFocus' Gdip_ImageSearch, which works well.
	; http://www.autohotkey.com/board/topic/71100-gdip-imagesearch/
	HaystackBitmap := Gdip_CreateBitmapFromFile(HaystackPath)
	for Type_, Sizes in Diablo2.FillPotion.Potions {
		for _, Size in Sizes {
			NeedlePath := Diablo2_Private_FillPotionImagePath(Type_, Size)
			NeedleBitmap := Gdip_CreateBitmapFromFile(NeedlePath)
			CoordsListString := ""
			; The last 0 instructs Gdip_ImageSearch to find all instances.
			NumImagesFound := Gdip_ImageSearch(HaystackBitmap, NeedleBitmap, CoordsListString, Diablo2.InventoryCoords.TopLeft.X, Diablo2.InventoryCoords.TopLeft.Y, Diablo2.InventoryCoords.BottomRight.X, Diablo2.InventoryCoords.BottomRight.Y, Diablo2.FillPotion.Variation, , , 0)
			if (NumImagesFound < 0) {
				; Anything less than 0 indicates an error.
				Log.Close()
				MsgBox, % "Call to Gdip_ImageSearch failed with error code " . Retval
				ExitApp
			}
			if (NumImagesFound > 0) {
				; XXX: Since it's not easy to get updating screenshots, just click all of the potions.
				for _, CoordsString in StrSplit(CoordsListString, "`n") {
					Coords := StrSplit(CoordsString, "`,")
					Potion := {X: Coords[1], Y: Coords[2]}
					Diablo2_Private_FillPotionClick(Potion.X, Potion.Y)
				}
			}
			Gdip_DisposeImage(NeedleBitmap)
		}
	}
	Diablo2_Private_FillPotionEnd()
	Gdip_DisposeImage(HaystackBitmap)
	; Remove the screen shot; it is not needed any more.
	FileDelete, %HaystackPath%
}

/**
 * Perform shutdown tasks (close GDI+).
 *
 * Return value: None
 */
Diablo2_Private_Shutdown() {
	global Diablo2
	Gdip_Shutdown(Diablo2.GdipToken)
}

goto, End

; Handle all skill hotkeys with a preferred weapon set.
SkillHotkeyActivated:
Diablo2_Private_ActivateSkill(A_ThisHotkey)
return

; Handle fill potion hotkey
FillPotionHotkeyActivated:
Diablo2_Private_FillPotionActivated()
return

End:
