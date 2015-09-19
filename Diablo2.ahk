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
 * KeysConfigPath
 *     Path to JSON config file containing key mappings
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
Diablo2_Init(KeysConfigPath, SkillsConfigPath := "", FillPotionConfigPath := "", LogPath := "") {
	Diablo2_InitConstants()
	global Diablo2

	Diablo2.ConfigFiles := {Keys: KeysConfigPath, Skills: SkillsConfigPath, FillPotion: FillPotionConfigPath}
	Diablo2["Log", "Path"] := LogPath
	Diablo2_Reinit()
}

/**
 * Re-read the configuration files passed to Diablo2_Init().
 *
 * Return value: None
 */
Diablo2_Reinit() {
	global Diablo2

	Diablo2.Log.Sep := "|"
	if (Diablo2.Log.Path == "") {
		Diablo2.Log.Func := Func("")
	}
	else {
		Diablo2.Log.FileObj := FileOpen(Diablo2.Log.Path, "a")
		; Separate this session from the last with a newline
		Diablo2.Log.FileObj.Write("`r`n")
		Diablo2.Log.Func := Func("Diablo2_Private_DoLogMessage")
	}
	Diablo2_LogMessage("Diablo2 AHK library initialized")

	; Configuration
	Diablo2.Keys := Diablo2_Private_SafeParseJSONFile(Diablo2.ConfigFiles.Keys)

	; Set up keyboard mappings
	Hotkey, IfWinActive, % Diablo2.HotkeyCondition

	if (Diablo2.ConfigFiles.Skills != "") {
		Diablo2.Skills := {Max: 16
		, WeaponSetForKey: {}
		, SwapKey: Diablo2_Private_RequireKey("Swap Weapons", "Skills")}

		; Read the config file and assign hotkeys
		WeaponSetForSkill := Diablo2_Private_SafeParseJSONFile(Diablo2.ConfigFiles.Skills)
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

		Diablo2_Private_SkillsLog("Enabled")
	}

	EnableFillPotion := true
	if (Diablo2.ConfigFiles.FillPotion != "") {
		for _, KeyName in ["Inventory Screen", "Clear Screen"] {
			Diablo2_Private_RequireKey(KeyName, "FillPotion")
		}

		; Read the config file
		Diablo2.FillPotion := Diablo2_Private_SafeParseJSONFile(Diablo2.ConfigFiles.FillPotion)

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

		if (Diablo2.FillPotion.Fullscreen) {
			Diablo2.FillPotion.ScreenShotKey := Diablo2_Private_RequireKey("Screen Shot", "FillPotion")

			; Start GDI+ for full screen
			Diablo2.GdipToken := Gdip_Startup()
			if (!Diablo2.GdipToken) {
				Diablo2_Fatal("GDI+ failed to start. Please ensure you have GDI+ on your system and that you are running a 32-bit version of AHK")
			}
			OnExit("Diablo2_Private_Shutdown")

			; Find installation directory
			RegRead, InstallPath, % Diablo2.RegistryKey, InstallPath
			Diablo2.InstallPath := InstallPath

			; Cache needle bitmaps
			BitmapLoop:
			For Type_, Sizes in Diablo2.FillPotion.Potions {
				For _, Size in Sizes {
					Bitmap := Gdip_CreateBitmapFromFile(Diablo2_Private_FillPotionImagePath(Type_, Size))
					if (Bitmap <= 0) {
						Diablo2_Private_FillPotionLog("Needle bitmaps not found; please generate them first")
						EnableFillPotion := false
						break, BitmapLoop
					}
					Diablo2.FillPotion["NeedleBitmaps", Type_, Size] := Bitmap
				}
			}
		}
		else {
			; Compensate for incorrect coordinates in windowed mode
			For Location in Diablo2.InventoryCoords {
				Diablo2.InventoryCoords[Location].Y += 25
			}
		}

		; Assign function
		Diablo2.FillPotion.Function := Func(Diablo2.FillPotion.Fullscreen ? "Diablo2_Private_FillPotionFullscreenBegin" : "Diablo2_Private_FillPotionWindowed")
	}
	if (EnableFillPotion) {
		; Assign hotkey
		Hotkey, % Diablo2.FillPotion.Key, FillPotionHotkeyActivated
		Diablo2_Private_FillPotionLog("Enabled")
	}
	else {
		Diablo2_Private_FillPotionLog("Disabled for now")
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
Diablo2_LogMessage(Message, Level := "DEBUG") {
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
	Diablo2_LogMessage(Message, "FATAL")
	ExitApp
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

	Diablo2_LogMessage("Assigning keys")

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

	Diablo2_LogMessage("Keys assigned")
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

/**
 * Create needle bitmaps from the contents of the screen.
 *
 * Return value: None
 */
Diablo2_FillPotionGenerateBitmaps() {
	Diablo2_OpenInventory()
	Sleep, 100 ; Wait for the inventory to appear
	Diablo2_Private_FillPotionFullscreenTakeScreenshot("Diablo2_Private_FillPotionGenerateBitmaps")
}

/**************************************************************************************************
 * BEGIN PRIVATE FUNCTIONS
 */

/**
 * Check to make sure a key is assigned, exiting with an error if not. The key is returned in Send
 * syntax.
 *
 * Arguments:
 * KeyName
 *     Name of the key
 * Feature
 *     Feature for which the key is needed
 *
 * Return value: Key in Send syntax
 */
Diablo2_Private_RequireKey(KeyName, Feature) {
	global Diablo2

	Key := Diablo2.Keys[KeyName]
	if (Key == "") {
		Diablo2_Fatal(Format("Key assignment for {} is required for {}", KeyName, Feature))
	}
	return Diablo2_Private_HotkeySyntaxToSendSyntax(Key)
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
Diablo2_Private_DoLogMessage(Message, Level) {
	global Diablo2

	FormatTime, TimeVar, , yyyy-MM-dd HH:mm:ss
	Diablo2.Log.FileObj.Write(Format("{1}.{2}{3}{4}{5}{6}`r`n"
		, TimeVar, A_Msec, Diablo2.Log.Sep, Level, Diablo2.Log.Sep, Message))
	Diablo2.Log.FileObj.Read(0) ; Seems like a hack, but this apparently flushes the write buffer
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
		Diablo2_Fatal("Error reading file " . FilePath)
	}
	; Pass jsonify=true as the second parameter to allow key-value pairs to be enumerated in the
	; order they were declared.
	; This is important for the key bindings, where the order does matter.
	return JSON.Load(FileContents, true)
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
		Diablo2_Fatal("Gdip_CreateBitmapFromFile failed to create bitmap from " . FilePath)
	}
	return Bitmap
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
 * Return the minimum of two parameters.
 */
Diablo2_Private_Min(A, B) {
	return A < B ? A : B
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

Diablo2_Private_SkillsLog(Message) {
	global Diablo2
	Diablo2_LogMessage("Skills" . Diablo2.Log.Sep . Message)
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
	ShouldSwapWeaponSet := (PreferredWeaponSet != "" and PreferredWeaponSet != Diablo2.Skills.Current.WeaponSet)

	; Suspend all hotkeys while this stuff is happening.
	; This decreases the chance of the game and macros getting out-of-sync.
	Suspend, On

	if (ShouldSwapWeaponSet) {
		; Swap to the other weapon
		Diablo2_Private_SkillsLog("Swapping to weapon set " . PreferredWeaponSet)
		Send, % Diablo2.Skills.SwapKey
		Diablo2.Skills.Current.WeaponSet := PreferredWeaponSet
	}

	if (Diabl2.Skills.Current.Skills[Diablo2.Skills.Current.WeaponSet] != Key) {
		if (ShouldSwapWeaponSet) {
			; If we just switched weapons, we need to sleep very slightly
			; while the game actually swaps weapons.
			Sleep, 70
		}
		Diablo2_Private_SkillsLog(Format("Switching to skill on '{}'", Key))
		Send, % Diablo2_Private_HotkeySyntaxToSendSyntax(Key)

		Diabl2.Skills.Current.Skills[Diablo2.Skills.Current.WeaponSet] := Key
	}

	; Turn on hotkeys.
	Suspend, Off
}

/**
 * Write needle bitmaps from a taken screenshot.
 *
 * Return value: None
 */
Diablo2_Private_FillPotionGenerateBitmaps(_1, _2, ScreenshotPath) {
	global Diablo2
	ScriptPath := Diablo2.AutoHotkeyLibDir . "\GenerateBitmaps.ps1"
	RunWait, powershell -NoLogo -NonInteractive -NoProfile -File "%ScriptPath%" "%ScreenshotPath%", %A_ScriptDir%
	if (ErrorLevel != 0) {
		Diablo2_Fatal("Generating fill potion bitmaps failed with exit code " . ErrorLevel)
	}
	Diablo2_LogMessage("Successfully generated fill potion needle bitmaps")
	WatchDirectory("") ; Stop watching directories
	Diablo2_Reinit()
}

/**
 * Call the configured fill potion function.
 *
 * Return value: None
 */
Diablo2_Private_FillPotionActivated() {
	global Diablo2
	Diablo2_Private_FillPotionLog("Starting run")
	Diablo2.FillPotion.Function.Call()
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
	return Format("{1}\Images\{2}\{3}.png", A_ScriptDir, Type_, Size)
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
	Sleep, 150
	MouseGetPos, MouseX, MouseY
	LButtonIsDown := GetKeyState("LButton")
	; Click doesn't support expressions (at all). Hence the use of X and Y above.
	Click, %X%, %Y%
	MouseMove, MouseX, MouseY
	if (LButtonIsDown) {
		Send, {LButton down}
	}
	Sleep, 150
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

Diablo2_Private_FillPotionLog(Message) {
	global Diablo2
	Diablo2_LogMessage("FillPotion" . Diablo2.Log.Sep . Message)
}

Diablo2_Private_FillPotionLogType(Type_, Message) {
	global Diablo2
	Diablo2_Private_FillPotionLog(Format("{1:-12}{2}{3}", Type_, Diablo2.Log.Sep, Message))
}

Diablo2_Private_FillPotionLogSize(Type_, Size, Message) {
	global Diablo2
	Diablo2_Private_FillPotionLogType(Type_, Format("{1:-7}{2}{3}", Size, Diablo2.Log.Sep, Message))
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
				ImageSearch, PotionX, PotionY, % Diablo2.InventoryCoords.TopLeft.X, % Diablo2.InventoryCoords.TopLeft.Y, % Diablo2.InventoryCoords.BottomRight.X, % Diablo2.InventoryCoords.BottomRight.Y, *120 %NeedlePath%
				if (ErrorLevel == 2) {
					Diablo2_Fatal(NeedlePath . Diablo2.Log.Sep . "Needle image file not found")
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
 * Take a screenshot and watch the Diablo II installation directory for it.
 *
 * Arguments:
 * Func
 *     Name of callback function (as string)
 *
 * Return value: None
 */
Diablo2_Private_FillPotionFullscreenTakeScreenshot(CallbackName) {
	global Diablo2

	; Note: InstallPath has a trailing slash
	; 0x10 is FILE_NOTIFY_CHANGE_LAST_WRITE, which gets called when Diablo II creates a screenshot.
	; Triple question marks ("???") don't seem to work, but "*" should be fine.
	WatchDirectory(Diablo2.InstallPath . "|Screenshot*.jpg", Func(CallbackName), 0x10)
	Send, % Diablo2.FillPotion.ScreenShotKey
}

/**
 * Fill the potion belt in fullscreen mode.
 *
 * Return value: None
 */
Diablo2_Private_FillPotionFullscreenBegin() {
	global Diablo2

	; Initialize structures
	for Type_ in Diablo2.FillPotion.Potions {
		Diablo2.FillPotion["State", Type_] := {SizeIndex: 1, Finished: false, PotionsClicked: []}
	}
	Diablo2_Private_FillPotionBegin()
	Sleep, 100 ; Wait for the inventory to appear
	Diablo2_Private_FillPotionFullscreenTakeScreenshot("Diablo2_Private_FillPotionFullscreen")
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
			Diablo2_Private_FillPotionLogSize(Type_, Size, "Searching")
			NumPotionsFound := Gdip_ImageSearch(HaystackBitmap
				, Diablo2.FillPotion.NeedleBitmaps[Type_][Size]
				, CoordsListString
				, Diablo2.InventoryCoords.TopLeft.X, Diablo2.InventoryCoords.TopLeft.Y
				, Diablo2.InventoryCoords.BottomRight.X, Diablo2.InventoryCoords.BottomRight.Y
				, 50 ; Variation; determined emperically
				; These two blank parameters are transparency color and search direction.
				, ,
				; For the number of instances to find, pass one more than the user requested so that we
				; can terminate early if possible. If they passed 0, find all instances with 0.
				, Diablo2.FillPotion.FullscreenPotionsPerScreenshot == 0 ? 0 : Diablo2.FillPotion.FullscreenPotionsPerScreenshot + 1)

			; Anything less than 0 indicates an error.
			if (NumPotionsFound < 0) {
				Diablo2_Fatal("Gdip_ImageSearch call failed with error code " . NumPotionsFound)
			}

			; Collect all the potions we found into an array.
			PotionsFound := []
			for _3, CoordsString in StrSplit(CoordsListString, "`n") {
				Coords := StrSplit(CoordsString, "`,")
				PotionFound := {X: Coords[1], Y: Coords[2]}
				Diablo2_Private_FillPotionLogSize(Type_, Size, Format("Found at {1},{2}", PotionFound.X, PotionFound.Y))
				; If any of the potions found were clicked before, the potion belt is already full
				; of this type and we are finished with it.
				for _4, PotionClicked in Diablo2.FillPotion.State[Type_].PotionsClicked {
					if (PotionFound.X == PotionClicked.X and PotionFound.Y == PotionClicked.Y) {
						Diablo2.FillPotion.State[Type_].Finished := true
						Diablo2_Private_FillPotionLogType(Type_, "Finished for run due to full belt")
						break, PotionSizeLoop
					}
				}
				PotionsFound.Push(PotionFound)
			}

			; Click potions.
			NumPotionsAllowedToClick := Diablo2.FillPotion.FullscreenPotionsPerScreenshot == 0 ? NumPotionsFound : (Diablo2.FillPotion.FullscreenPotionsPerScreenshot - PotionsClicked.Length())
			Loop, % Diablo2_Private_Min(NumPotionsAllowedToClick, NumPotionsFound) {
				Potion := PotionsFound[A_Index]
				Diablo2_Private_FillPotionLogSize(Type_, Size, Format("Clicking {1},{2}", Potion.X, Potion.Y))
				Diablo2_Private_FillPotionClick(Potion.X, Potion.Y)
				PotionsClicked.Push(Potion)
			}

			if (NumPotionsFound > NumPotionsAllowedToClick) {
				; If we found more potions than we are allowed to click, we are definitely not finished.
				; But we can't click any more potions of this type for this screenshot.
				Finished := false
				Diablo2_Private_FillPotionLogType(Type_, "Finished for screenshot")
				break
			}

			; Move on to the next size.
			++Diablo2.FillPotion.State[Type_].SizeIndex

			; Check to see if we have run out of potion sizes for this type. This has happened if
			; the size index has been incremented beyond the bounds of the size array.
			if Diablo2.FillPotion.State[Type_].SizeIndex > Sizes.Length() {
				Diablo2.FillPotion.State[Type_].Finished := true
				Diablo2_Private_FillPotionLogType(Type_, "Finished because no potions left")
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
		Diablo2_Private_FillPotionLog("Finishing run")
		WatchDirectory("") ; Stop watching directories
		Diablo2_Private_FillPotionEnd()
	}
	else {
		Diablo2_Private_FillPotionLog("Requesting updated screenshot")
		; Wait slightly for the game to update
		; Sleep, 100

		; Get the next screenshot
		Send, % Diablo2.FillPotion.ScreenShotKey
	}
}

/**
 * Perform shutdown tasks. Only needed for FillPotion Fullscreen mode.
 *
 * Return value: None
 */
Diablo2_Private_Shutdown() {
	global Diablo2
	WatchDirectory("") ; Stop watching all directories
	For Type_, Sizes in Diablo2.FillPotion.NeedleBitmaps {
		For _, Bitmap in Sizes {
			Gdip_DisposeImage(Bitmap)
		}
	}
	Gdip_Shutdown(Diablo2.GdipToken)
	if (Diablo2.Log.HasKey("FileObj")) {
		Diablo2.Log.FileObj.Close()
	}
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
