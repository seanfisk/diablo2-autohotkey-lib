#NoEnv
; XXX WatchDirectory has some unset locals. Eventually would be nice to fix.
#Warn, UseUnsetLocal, Off

; Set up CoordMode in the auto-execute section. Because of this, scripts which use this library MUST
; include it instead of just using the implicit import from the library of functions feature and
; MUST NOT override CoordMode or SendMode. Use with:
;
;     #Include <Diablo2>

; For windowed mode; doesn't affect fullscreen mode
for __, Category in ["Pixel", "Mouse"] {
	CoordMode, %Category%, Client
}
; Despite what the docs say, there appears to be no way to send clicks using SendInput other than
; the following:
;
;     SendMode, Input
;     Click, X, Y
;
; I believe this is a bug in AutoHotkey. See 'source/keyboard_mouse.cpp' in the AutoHotkey source
; tree for more details on when SendInput falls back to other methods.
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
;
SendMode, Input

#Include <JSON>
#Include <TTSConstants>
#Include <vtype>

; This is a static namespace class which serves to contain all the library features and functions.
; It is not intended to be subclassed via the 'new' operator.
class Diablo2 {
	; Public constants
	static AutoHotkeyLibDir := A_MyDocuments . "\AutoHotkey\Lib"
	static HotkeyCondition := "ahk_classDiablo II"
	static Inventory := {TopLeft: {X: 415, Y: 310}
		, BottomRight: {X: 710, Y: 435}
	, CellSize: 29}
	static RegistryKey := "HKEY_CURRENT_USER\Software\Blizzard Entertainment\Diablo II"

	; Private constants
	static _OptionalFeaturesDisabledClasses := {Log: "Noop"
		, Voice: "Noop"
		, Skills: "ExitThread"
		, MassItem: "ExitThread"
		, FillPotion: "ExitThread"
		, Steam: "ExitThread"}
	; Use an object for HasKey because arrays don't have a Contains-type method presumably, HasKey
	; operates in O(1) and would be faster than writing our own Contains.
	static _SuspendPermit := {"Suspend": ""
		, "Exit": ""
		, "Status": ""
		, "Steam.OverlayToggle": ""
		, "Steam.BrowserOpenTabs": ""}

	; Private vars
	static _Features := {}

	; Public methods

	; Initialize the macros. Call this before calling any other functions!
	;
	; Parameters:
	; ControlsConfig
	;     An object or a path to a JSON file containing key bindings
	; OptionalConfig
	;     Configuration for optional features as an object. Valid keys are Log, Voice, Skills,
	;    	FillPotion, and MassItem. If a key is not present, that feature will be disabled. Values
	;    	should be an object or path to a JSON file containing the configuration.
	Init(ControlsConfig, OptionalConfig := "") {
		; Note: OptionalConfig can't default to {}, otherwise we'd let it
		this.Config := OptionalConfig == "" ? {} : OptionalConfig
		this.Config.Controls := ControlsConfig
		OnExit(ObjBindMethod(this, "_Shutdown"))
		this._Init()
	}

	; Assign a hotkey to a library function with optional arguments. This is a wrapper around the
	; Hotkey command intended to make assignment of hotkeys simpler.
	;
	; Parameters:
	; Key
	;     Key to bind
	; Binding
	;     This can be one of three things:
	;     - A function name to assign to hotkey (no arguments passed)
	;     - An object with Function and Args key-value pairs. Function is a string representing the
	;       name of the function to assign, and Args is an array of arguments.
	;     - A Func or BoundFunc object (arguments must already be bound)
	; GameOnly
	;     Whether the hotkey should be activated only in-game (default: true)
	;
	; Examples:
	;
	; ; Assign Ctrl-Alt-x to Diablo2.Exit()
	; Diablo2.Assign("^!x", "Exit")
	;
	; ; Assign F8 to a one-off town portal
	; Key := "F8"
	; Diablo2.Assign(Key, {Function: "Skills.OneOff", Args: [Key]})
	;
	Assign(Key, Binding, GameOnly := true) {
		if (vtype(Binding) == "Object") {
			if (!(Binding.HasKey("Function") and Binding.HasKey("Args"))) {
				this._Throw("Invalid object giving for Binding; must have ""Function"" and ""Args"" keys")
			}
			Function := Binding.Function
			Args := Binding.Args
		}
		else {
			Function := Binding
			Args := []
		}
		FunctionType := vtype(Function)
		if (Key == "") {
			this._Throw("Empty key for function: " . (FunctionType == "String" ? Function : Function.Name))
		}
		if (FunctionType == "String" and this._SuspendPermit.HasKey(Function)) {
			; Due to AHK limitations, "Suspend, *" doesn't work in a function reference. A suspend permit
			;  function therefore cannot support arguments.
			if (Args.Length() > 0) {
				this._Throw("Arguments not supported for suspend permit function: " . Function)
			}
			; Convert the function name to a matching suspend permit function.
			Function := "_Diablo2_" . StrReplace(Function, ".", "_")
		}
		else {
			; Resolve the function and bind arguments if it is a string.
			if (FunctionType == "String") {
				Components := StrSplit(Function, ".")
				MethodName := Components.Pop()
				Obj := this
				for _, Component in Components {
					if (!Obj.HasKey(Component)) {
						this._Throw("Invalid component: " . Component)
					}
					Obj := Obj[Component]
				}
				Function := ObjBindMethod(Obj, MethodName, Args*)
			}
			; Wrap the function to catch all exceptions.
			Function := ObjBindMethod(Diablo2, "_CatchExceptions", Function)
		}
		if (GameOnly) {
			HCC := new this._HotkeyConditionContext()
		}
		Hotkey, %Key%, %Function%
	}

	; Assign mulitple hotkeys to library functions. This is a wrapper around the Hotkey command
	; intended to make assignment of hotkeys simpler.
	;
	; Parameters:
	; Bindings
	;     Mapping of hotkey to library function. Keys of Bindings are strings representing the hotkey
	;     to bind. Values can be any valid Bind argument to Diablo2.Assign() [a function name,
	;     function object, or object with Function and Args keys].
	; GameOnly
	;     Whether the hotkey should be activated only in-game
	AssignMultiple(Bindings, GameOnly := true) {
		for Key, Binding in Bindings {
			this.Assign(Key, Binding, GameOnly)
		}
	}

	; Reset the state of the macros.
	Reset() {
		this.Voice.Speak("Macros reset", true)
		this._Init()
	}

	; Exit the entire program from within a created Battle.Net game.
	QuitBattleNetGame() {
		this.ClearScreen()
		this.Send("{Escape}") ; Bring up the menu
		Sleep, 50
		Click, 392, 259 ; "Save and Exit Game" on the in-game menu
		Sleep, 9000 ; This can take forever
		Click, 734, 479 ; "Quit" on the game create/join screen
		Sleep, 1000
		Click, 94, 553 ; "Exit" on the character selection screen
		Sleep, 1000
		Click, 405, 550 ; "Exit Diablo II" on the title screen
	}

	; Return the keybinding for a certain control, throwing if it is not assigned.
	;
	; Parameters:
	; Function
	;     Action the control performs
	; SendSyntax
	;     Pass true to return in Send syntax. The default is to return in Hotkey syntax.
	;
	; Return value: the key binding
	GetControl(Function, SendSyntax := false) {
		Key := Diablo2.Controls[Function]
		if (Key == "") {
			this._Throw("Control assignment required: " . Function, Function . " key required")
		}
		if (SendSyntax) {
			return this.HotkeySyntaxToSendSyntax(Key)
		}
		return Key
	}

	; Send keys in our specific format.
	;
	; Note: Do not use this method to click! See auto-execute section
	; (top of this file) for an explanation.
	;
	; Parameters:
	; Keys
	;     Sequence of keys to send
	Send(Keys) {
	 ; In the past, we attempted to use this function to send all keys
	 ; using SendInput so we didn't have to set SendMode. Well, that
	 ; didn't work (see top of file). But it's benefical that all
	 ; keystrokes pass through this function, so we could potentially
	 ; log, etc. in the future with no additional changes.
	 SendInput, %Keys%
	}

	; Throw an exception with an optional speaking string.
	;
	; Parameters:
	; Message
	;     Exception message
	; SpeakStr
	;     String to speak when exception is caught. Pass as false to explicitly disable speech.
	_Throw(Message, SpeakStr := "") {
		; The Exception constructor DOES NOT support objects as the Extra argument!!!
		Exc := Exception(Message
			, -1) ; Don't include this function in the stack trace
		if (SpeakStr != "") {
			Exc["Extra", "Speak"] := SpeakStr
		}
		throw Exc
	}

	; Perform a right-click while keeping the left mouse button down.
	;
	; Diablo II has an annoying behavior whereby right-clicking causes the left mouse button not to be
	; considered as held down. This function fixes that behavior.
	;
	; You can enable this fix globally in your own configuration with:
	;
	;     RButton::Diablo2_RightClick()
	;
	RightClick() {
		LBRestore := new this._LButtonRestore()
		this.Send("{RButton down}")
		KeyWait, RButton
		this.Send("{RButton up}")
	}

	; Convert a key in Hotkey syntax to Send syntax. Currently, if the string is more than one
	; character, we throw curly braces around it. This definitely doesn't account for every possible
	; case, but it seems to work alright for the single-key bindings which are most common.
	;
	; Parameters:
	; HotkeyString
	;     A key string in Hotkey syntax, i.e., with unescaped special keys (e.g. F1 instead of {F1}).
	;
	; Returns: The key in Send syntax
	HotkeySyntaxToSendSyntax(HotkeyString) {
		if (StrLen(HotkeyString) > 1) {
			return "{" . HotkeyString . "}"
		}
		return HotkeyString
	}

	; Run the game, disabling the macros until the user has joined a game.
	;
	; Also see Steam.LaunchGame() for launching the game through Steam (which enables the Steam
	; overlay).
	LaunchGame() {
		this._RunGame()
		this._SuspendUntilGameJoined()
	}

	; Open the inventory.
	OpenInventory() {
		this.Send(this.GetControl("Inventory Screen", true))
	}

	; Show the belt.
	ShowBelt() {
		this.Send(this.GetControl("Show Belt", true))
	}

	; Clear the screen.
	ClearScreen() {
		this.Send(this.GetControl("Clear Screen", true))
	}

	; Take a screenshot, watch the Diablo II installation directory for it, and call the callback when
	; the screenshot is available.
	;
	; Parameters:
	; CallbackFunc
	;     Function to call when the screenshot is written to the directory. The function can be a
	;     value of type Func or BoundFunc and is called with one argument, the path to the screenshot
	;     image.
	TakeScreenshot(CallbackFunc) {
		ScreenShotKey := this.GetControl("Screen Shot", true)
		; WatchDirectory doesn't support callbacks of type BoundFunc, only Func. Deploy workaround.
		this._ScreenshotCallback := ObjBindMethod(Diablo2, "_CatchExceptions", CallbackFunc)
		; Note: InstallPath has a trailing slash
		; Triple question marks ("???") don't seem to work, but "*" should be fine.
		RetCode := WatchDirectory(this._InstallPath . "|Screenshot*.jpg"
			, Func("_Diablo2_ScreenshotCallback")
			; 0x10 is FILE_NOTIFY_CHANGE_LAST_WRITE, which gets called when Diablo II creates a
			; screenshot.
			, 0x10)
		if (RetCode < 0) {
			this._Throw("WatchDirectory exited with " . RetCode)
		}
		this.Send(ScreenShotKey)
	}

	; Safely create a bitmap from a file.
	;
	; Parameters:
	; FilePath
	;     Path to image file.
	;
	; Returns: The created bitmap
	SafeCreateBitmapFromFile(FilePath) {
		Bitmap := Gdip_CreateBitmapFromFile(FilePath)
		if (Bitmap <= 0) {
			this._Throw("Gdip_CreateBitmapFromFile failed to create bitmap from " . FilePath)
		}
		return Bitmap
	}

	; Private methods

	; Perform initialization of the macros.
	_Init() {
		; Do not omit 'this' in the 'new' expression! Bad things happen.
		this.Controls := new this._ControlsFeature(this._LoadConfig(this.Config.Controls))
		this._Features.Controls := this.Controls
		for Name, DisabledClassName in this._OptionalFeaturesDisabledClasses {
			Feature := {}
			if (this.Config.HasKey(Name)) {
				; We must manually initialize instead of using the 'new' operator because we do not know the
				; base class in advance.
				Feature.base := this[Format("_{}Feature", Name)]
				Feature.__Init()
				Feature.__New(this._LoadConfig(this.Config[Name]))
			}
			else {
				Feature.base := this[Format("_{}Feature", DisabledClassName)]
			}
			; Declare public API
			this[Name] := Feature
			; Internally store in private map of features
			this._Features[Name] := Feature
		}
		for Name, Feature in this._Features {
			this.Log.Message(Name, Feature.Enabled ? "Enabled" : "Disabled")
		}

		; Find installation directory; this is used for TakeScreenshot()
		RegRead, InstallPath, % this.RegistryKey, InstallPath
		this._InstallPath := InstallPath
	}

	; Load or return a feature configuration.
	;
	; Parameters:
	; PathOrObject
	;     Possible path or object. If path, load the JSON file. If object, return unchanged.
	;
	; Returns: The feature configuration
	_LoadConfig(PathOrObject) {
		if (IsObject(PathOrObject)) {
			return PathOrObject
		}
		try {
			FileRead, FileContents, %PathOrObject%
		}
		catch {
			this._Throw("Error reading file " . PathOrObject)
		}
		return JSON.Load(FileContents, true)
	}

	; Macro shutdown function
	_Shutdown() {
		this.Log.Message("Global", "Shutting down")
	}

		; Return the minimum of two parameters.
	_Min(A, B) {
		return A < B ? A : B
	}

	; Return the maximum of two parameters.
	_Max(A, B) {
		return A > B ? A : B
	}

	; Call a BoundFunc, catching all exceptions and logging/announcing them then exiting the current
	; thread. This is intended to be used by any function that is called in-game. Using "throw" in
	; this way has several advantages:
	;
	; Over returning directly from the function:
	;
	; - Functions deeper in the stack can throw and it will be handled in the same way as if the
	;		hotkey function had thrown. This means the hotkey function itself can safely ignore (not
	;		catch) any of those errors; they will be logged without any additional work.
	;
	; Over a global exit function (previously Diablo2.Fatal()):
	;
	; - Throw utilizes an existing language feature; it is not specific to this library. Therefore,
	;   any existing libraries using it will happily work without modification.
	; - Functions used both inside and outside of the game will work the same: outside the game, a
	;   dialog will result; inside the game, the error will be logged and announced.
	;
	; Disadvantages:
	;
	; - The call interception code is a bit more complex than either of the other solutions.
	;
	;
	; Parameters:
	; Function
	;     The Func or BoundFunc to call
	; Args*
	;     Any extra arguments to pass to the function
	;
	; Returns: the return value of the function, if it didn't throw
	_CatchExceptions(Function, Args*) {
		try {
			return Function.Call(Args*)
		}
		catch Exc {
			; Feature are used in-game, so don't display a dialog. Instead, write to the log, announce
			; via speech, and exit the current thread.
			Message := Exc.Message
			if (A_ThisHotkey != "") {
				Message .= Format(" [Hotkey: {}]", A_ThisHotkey)
			}
			; If the Exception has an Extra key, use it for more information.
			Feature := Exc.Extra.Feature ? Exc.Extra.Feature : "Global"
			Diablo2.Log.Message(Feature, Message, "FATAL")
			; Speaking asynchronously when the current thread is exiting causes inconsistent results.
			; Just speak synchronously to be sure.
			Speak := Exc.Extra.Speak
			if (Speak != false) {
				Diablo2.Voice.Speak(Speak ? Speak : (Feature . " error"), true)
			}
		}
	}

	; Run the game with the command-line flag -skiptobnet, which starts the game right at the
	; Battle.Net login screen. Used by the RunGame.ahk wrapper.
	_RunGame() {
		; XXX: Don't use CmdLine from the registry -- the game modifies this
		; when run. When we pass -skiptobnet, it adds this to CmdLine,
		; too... not sure how to avoid this.
		RegRead, GamePath, % this.RegistryKey, GamePath
		SplitPath, GamePath, , GameDir
		Run, "%GamePath%" -skiptobnet, %GameDir%
		; We considered saving the PID from this and using ahk_pid to limit hotkeys to that, but it's
		; adding unnecessary complexity. There can be only one Diablo II instance running at a time
		; anyway.
	}

	; Suspend hotkeys until the user logs into Battle.Net and joins a game.
	_SuspendUntilGameJoined() {
		; Suspend immediately, because the user will have to type in credentials for Battle.Net.
		_Diablo2_Suspend("On")
		; Wait for Battle.Net login, character choice, and game creation/join
		Loop, 3 {
			; Down (D) and up (the default) constitutes an individual press
			KeyWait, Enter, D
			KeyWait, Enter
		}
		_Diablo2_Suspend("Off")
	}

	; Private classes
	class _HotkeyConditionContext {
		; Use RAII to manage hotkey context.
		__New() {
			; Turn on context-sensitive hotkey creation
			Hotkey, IfWinActive, % Diablo2.HotkeyCondition
		}

		__Delete() {
			Hotkey, IfWinActive
		}
	}

	class _LButtonRestore {
		_IsDown := false
		; Use RAII to save and restore the state of LButton.
		__New() {
			this._IsDown := GetKeyState("LButton")
		}

		__Delete() {
			if (this._IsDown) {
				; When using SendInput, it is so fast that the game needs time to react.
				Sleep, 50
				Diablo2.Send("{LButton down}")
			}
		}
	}

	class _MousePosRestore {
		_Pos := {X: -1, Y: -1}
		; Use RAII to save and restore the mouse position.
		__New() {
			MouseGetPos, MouseX, MouseY
			this._Pos := {X: MouseX, Y: MouseY}
		}

		__Delete() {
			MouseMove, this._Pos.X, this._Pos.Y
		}
	}

	class _MouseRestore {
		; Use RAII to save and restore the mouse position and LButton state.
		__New() {
			this._PosRestore := new Diablo2._MousePosRestore()
			this._LBRestore := new Diablo2._LButtonRestore()
		}

		__Delete() {
			; Restore the position first.
			this._PosRestore := ""
			; Sleep slightly so that LButton doesn't accidentally take effect in the old position.
			Sleep, 100
			this._LBRestore := ""
		}
	}

	class _Feature {
		; Log a message on behalf of this feature.
		_Log(Message, Level := "DEBUG") {
			Diablo2.Log.Message(this._Name, Message, Level)
		}

		_Name[] {
			get {
				; Extract the feature name from the class name, if possible.
				; O tells RegExMatch to return a match object.
				; S tells RegExMatch to study the expression and cache it.
				ClassName := this.__Class
				if (RegExMatch(ClassName, "OS)_([a-zA-Z0-9]+)Feature$", MatchObject)) {
					return MatchObject.Value(1)
				}
				else {
					return ClassName
				}
			}
		}
	}

	class _EnabledFeature extends Diablo2._Feature {
		static Enabled := true

		; Intercept all calls and redirect to a function with "g" as a prefix. A "g" prefix means the
		; function is intended to be assigned to an in-game hotkey. In this case, we'll catch all
		; exceptions and tack on the name of the feature. If the hotkey was assigned with
		; Diablo2.Assign(), the exception will be caught and logged/announced.
		__Call(Name, Params*) {
			RealName := "g" . Name
			if (IsFunc(this[RealName])) {
				try {
					return this[RealName](Params*)
				}
				catch Exc {
					; Tack on the feature name and re-throw.
					Exc["Extra", "Feature"] := this._Name
					throw Exc
				}
			}
		}
	}

	; We make the Enabled variable static so that it does not have to be initialized by __Init, a call
	; which gets intercepted by __Call.
	class _DisabledFeature extends Diablo2._Feature {
		static Enabled := false
	}

	class _NoopFeature extends Diablo2._DisabledFeature {
		__Call(Args*) {
			; No-op
		}
	}

	class _ExitThreadFeature extends Diablo2._DisabledFeature {
		__Call(Name, Args*) {
			Exc := Exception(Format("Feature with method ""{}"" unavailable", Name))
			Exc.Extra := {Feature: this._Name, Speak: this._Name . " unavailable"}
			throw Exc
		}
	}

	class _ControlsFeature extends Diablo2._EnabledFeature {
		; Constants
		_NumMultiControl := {Skills: 16, Belt: 4}
		_AvailableFunctions := ["Character Screen"
			, "Inventory Screen"
			, "Party Screen"
			, "Hireling Screen"
			, "Message Log"
			, "Quest Log"
			, "Help Screen"
			, "Skill Tree"
			, "Skill Speed Bar"
			, "Select Previous Skill"
			, "Select Next Skill"
			, "Show Belt"
			, "Swap Weapons"
			, "Chat"
			, "Run"
			, "Toggle Run/Walk"
			, "Stand Still"
			, "Show Items"
			, "Show Portraits"
			, "Automap"
			, "Center Automap"
			, "Fade Automap"
			, "Party on Automap"
			, "Names on Automap"
			, "Toggle MiniMap"
			, "Say 'Help'"
			, "Say 'Follow me'"
			, "Say 'This is for you'"
			, "Say 'Thanks'"
			, "Say 'Sorry'"
			, "Say 'Bye'"
			, "Say 'Now you die'"
			, "Say 'Retreat'"
			, "Screen Shot"
			, "Clear Screen"
			, "Clear Messages"]

		__New(Config) {
			; Regular controls
			for _, Function in this._AvailableFunctions {
				this[Function] := Config.HasKey(Function) ? Config[Function] : ""
			}
			; Skills and Belt
			for ControlType, ControlSize in this._NumMultiControl {
				this[ControlType] := []
				; Initialize default of "" (which means "no assignment")
				Loop, %ControlSize% {
					this[ControlType].Push("")
				}
				; Assign all controls the user has set
				if Config.HasKey(ControlType) {
					Loop, % Config[ControlType].Length() {
						this[ControlType][A_Index] := Config[ControlType][A_Index]
					}
				}
			}
		}

		; Auto-configure control for the game. To use, assign to a hotkey, visit "Configure Controls"
		; screen, and press the hotkey.
		gAutoAssign() {
			this._Log("Auto-assigning")

			; Flatten the control list for easier duplicate detection.
			FlatControls := []
			CurrentIndex := 1
			; Regular controls beginning
			Loop, 9 {
				Function := this._AvailableFunctions[CurrentIndex]
				FlatControls.Push({Function: Function, Key: this[Function]})
				CurrentIndex += 1
			}
			; Skills
			Loop, % this._NumMultiControl.Skills {
				FlatControls.Push({Function: "Skill " . A_Index, Key: this.Skills[A_Index]})
			}
			; More regular
			Loop, 3 {
				Function := this._AvailableFunctions[CurrentIndex]
				FlatControls.Push({Function: Function, Key: this[Function]})
				CurrentIndex += 1
			}
			; Belt
			Loop, % this._NumMultiControl.Belt {
				FlatControls.Push({Function: "Use Belt " . A_Index, Key: this.Belt[A_Index]})
			}
			; Regular controls end
			Loop, 24 {
				Function := this._AvailableFunctions[CurrentIndex]
				FlatControls.Push({Function: Function, Key: this[Function]})
				CurrentIndex += 1
			}

			KeyFunctions := {}
			; Wait for all modifiers to be released. If they are down, it can cause interference.
			for _, Modifier in ["LWin", "RWin", "Control", "Alt", "Shift"] {
				if (GetKeyState(Modifier)) {
					KeyWait, %Modifier%
				}
			}
			SendStr := ""
			for _, Control_ in FlatControls {
				Function := Control_.Function
				Key := Control_.Key

				; If "" (corresponding to "" or null in the JSON file), delete the binding.
				if (Key == "") {
					SendStr .= "{Delete}"
				}
				else {
					; Check for duplicates
					DuplicateKeyFunction := KeyFunctions[Key]
					if (DuplicateKeyFunction != "") {
						Diablo2._Throw(Format("Duplicate key binding '{}' for '{}' and '{}'"
								, Key, DuplicateKeyFunction, Function)
							, Format("Duplicate key, {}; for {} and {}" , Key, DuplicateKeyFunction, Function))
					}
					KeyFunctions[Key] := Function

					; Assign the key binding
					SendStr .= "{Enter}" . Diablo2.HotkeySyntaxToSendSyntax(Key)
				}
				SendStr .= "{Down}"
			}

			Diablo2.Send(SendStr)

			this._Log("Controls assigned")
		}
	}

	class _LogFeature extends Diablo2._EnabledFeature {
		; Defaults
		Path := A_WorkingDir . "\" . StrReplace(A_ScriptName, ".ahk", "Log.txt")
		Sep := "|"

		__New(Config) {
			for Key in this {
				if Config.HasKey(Key) {
					this[Key] := Config[Key]
				}
			}

			FileExisted := FileExist(this.Path)
			this._FileObj := FileOpen(this.Path, "a")
			; Separate this session from the last with a newline if the log file already existed and is
			; not STDOUT (*) or STDERR (**).
			if (FileExisted and !(this.Path == "*" or this.Path == "**")) {
				this.Write("")
			}
		}

		__Delete() {
			this._Log("Closing log")
			this._FileObj.Close()
		}

		; Write a line of text to the log file and flush.
		;
		; Parameters:
		; Text
		;     Line string to write
		Write(Text) {
			this._FileObj.Write(Text . "`r`n")
			; Seems like a hack, but this apparently flushes the write buffer.
			this._FileObj.Read(0)
		}

		; Log a message to the log file. Useful for debugging in this script and your own.
		;
		; Parameters:
		; Feature
		;     Feature upon whose behalf the message is being written
		; Message
		;     Message to log
		; Level
		;     Log level to write to output file
		Message(Feature, Message, Level := "DEBUG") {
			FormatTime, TimeVar, , yyyy-MM-dd HH:mm:ss
			this.Write(Format("{}.{}", TimeVar, A_Msec) . this.Sep . Level . this.Sep . Feature . this.Sep . Message)
		}
	}

	class _VoiceFeature extends Diablo2._EnabledFeature {
		_SpVoice := ComObjCreate("SAPI.SpVoice")

		__New() {
			; Prefer Hazel (case-insensitive) because I like her voice :)
			Voices := this._SpVoice.GetVoices
			Loop, % Voices.Count {
				Voice := Voices.Item(A_Index - 1)
				if InStr(Voice.GetAttribute("Name"), "Hazel", false) {
					this._SpVoice.Voice := Voice
					break
				}
				; Up the rate a bit (default is 0)
				this._SpVoice.Rate := 3
			}
		}

		; Speak some text with the configured voice.
		;
		; Parameters:
		; Text
		;     String to pronounce
		; Synchronous
		;     Whether to speak synchronously
		Speak(Text, Synchronous := false) {
			global SVSFDefault, SVSFlagsAsync
			Flags := SVSFDefault
			if (!Synchronous) {
				Flags |= SVSFlagsAsync
			}
			this._SpVoice.Speak(Text, Flags)
		}
	}

	class _SkillsFeature extends Diablo2._EnabledFeature {
		_Max := 16
		_WeaponSetForKey := {}
		_SwapDisabled := false
		_SwapWaitingKey := ""
		_WeaponSet := 1
		_Skills := ["", ""]

		__New(WeaponSetForSkill) {
			this._SwapKey := Diablo2.GetControl("Swap Weapons", true)

			; Read the config file and assign hotkeys
			HotkeyFunc := ObjBindMethod(this, "_HotkeyActivated")
			Hotkeys := {}
			Loop, % this._Max {
				Key := Diablo2.Controls.Skills[A_Index]
				if (Key != "") {
					WeaponSet := WeaponSetForSkill[A_Index]
					this._WeaponSetForKey[Key] := WeaponSet
					this._WeaponSetKeys[WeaponSet].Push(Key)
					; Make each skill a hotkey so we can track the current skill.
					Hotkeys[Key] := HotkeyFunc
				}
			}
			Diablo2.AssignMultiple(Hotkeys)
		}

		; Get the current skill (represented by its hotkey).
		;
		; Returns: The current skill key
		Get() {
			return this._Skills[this._WeaponSet]
		}

		; Activate the skill assigned to the specific key.
		;
		; Parameters:
		; Key
		;     The skill hotkey
		Activate(Key) {
			PreferredWeaponSet := this._WeaponSetForKey[Key]
			ShouldSwapWeaponSet := (PreferredWeaponSet != "" and PreferredWeaponSet != this._WeaponSet)
			; Activating any skill hotkey cancels any previous key waiting for swap to be re-enabled.
			this._SwapWaitingKey := ""

			if (ShouldSwapWeaponSet) {
				; If the skill requested needs to swap weapons but swapping is currently disabled, set the
				; skill to be activated after a timeout.
				if (this._SwapDisabled) {
					this._SwapWaitingKey := Key
					Diablo2._Throw(Format("Swapping disabled; will activate '{}' when ready" , Key), false)
				}
				; Temporarily disable swapping so that the user cannot immediately cause a swap back to the
				; other weapon set, which tends to de-synchronize the macros and the game.
				this._DisableSwap()
				; Swap to the other weapon set.
				this._Log("Swapping to weapon set " . PreferredWeaponSet)
				Diablo2.Send(this._SwapKey)
				this._WeaponSet := PreferredWeaponSet
			}

			if (this._Skills[this._WeaponSet] != Key) {
				if (ShouldSwapWeaponSet) {
					; If we just switched weapons, we need to sleep very slightly
					; while the game actually swaps weapons.
					Sleep, 70
				}
				this._Log(Format("Switching to skill on '{}'", Key))
				Diablo2.Send(Diablo2.HotkeySyntaxToSendSyntax(Key))

				this._Skills[this._WeaponSet] := Key
			}
		}

		; Block the user from swapping weapons.
		_DisableSwap() {
			this._SwapDisabled := true
			this._Log("Swapping disabled")
			; Now set up a timer to re-enable swapping.
			Function := ObjBindMethod(this, "_EnableSwap")
			; A negative period sets up a one-off timer.
			SetTimer, %Function%, -1200
		}

		; Unblock the user from swapping weapons, activated a swap-required skill if it was the
		; requested.
		_EnableSwap() {
			this._SwapDisabled := false
			this._Log("Swapping enabled")
			if (this._SwapWaitingKey) {
				this._Log(Format("Activating '{}' which required swap", this._SwapWaitingKey))
				this.Activate(this._SwapWaitingKey)
			}
		}

		; Activate the skill represented by the assigned hotkey.
		g_HotkeyActivated() {
			this.Activate(A_ThisHotkey)
		}

		; Perform a one-off skill.
		;
		; This is done by switching to the skill, right-clicking, and switching back to the old skill.
		; For best performance, this skill should not have a weapon set associated with it. But it will
		; work with or without it.
		;
		; Parameters:
		; Key
		;     The skill hotkey
		;
		gOneOff(Key) {
			; There are times when it isn't necessary to save the state of LButton, but it's really
			; useful, for example, to keep moving after performing a Teleport. It's useful enough that
			; it's included as the default behavior.
			LBRestore := new LButtonRestore()
			OldSkill := this.Get()
			OldWeaponSet := this._WeaponSet
			this.Activate(Key)
			; If we had to swap weapons to use the one-off skill, we need to wait a bit. These sleeps are
			; the only way it works reliably.
			HadToSwap := this._WeaponSet != OldWeaponSet
			if (HadToSwap) {
				Sleep, 600
			}
			Click, Right
			if (HadToSwap) {
				Sleep, 600
			}
			this.Activate(OldSkill)
		}
	}

	class _MassItemFeature extends Diablo2._EnabledFeature {
		_Start := {}
		_TopLeft := {}
		_Size := {}

		__New(_) {
			this._StandStillKey := Diablo2.GetControl("Stand Still", true)
		}

		; Begin an item selection.
		gSelectStart() {
			MouseGetPos, StartX, StartY
			this._Log(Format("Selection start is {},{}", StartX, StartY))
			this._Start := {X: StartX, Y: StartY}
			Diablo2.Voice.Speak("Select")
		}

		; Finish definition of an item selection.
		gSelectEnd() {
			Start := this._Start
			if (!Start.HasKey("X")) {
				Message := "No selection started"
				this._Log(Message, "ERROR")
				Diablo2.Voice.Speak(Message)
				return
			}

			MouseGetPos, EndX, EndY
			End_ := {X: EndX, Y: EndY}
			Size := {}
			TopLeft := {}
			BottomRight := {}
			for Dim in Start {
				TopLeft[Dim] := Diablo2._Min(Start[Dim], End_[Dim])
				BottomRight[Dim] := Diablo2._Max(Start[Dim], End_[Dim])
				Size[Dim] := ((BottomRight[Dim] - TopLeft[Dim]) // Diablo2.Inventory.CellSize) + 1
			}
			NumSelected := Size.X * Size.Y
			this._TopLeft := TopLeft
			this._Size := Size
			this._Log(Format("Selected {} cells (start: {},{}; end: {},{}; size: {}x{})"
				, NumSelected, Start.X, Start.Y, End_.X, End_.Y, Size.X, Size.Y))
			Diablo2.Voice.Speak(NumSelected)
		}

		; Drop items in selection at current mouse position.
		gDrop() {
			if (!this._HasSelection()) {
				return
			}
			Size := this._Size
			TopLeft := this._TopLeft

			this._Log(Format("Dropping {} cells at {},{}", Size.X * Size.Y, TopLeft.X, TopLeft.Y))
			Diablo2.Voice.Speak("Drop")

			MouseGetPos, DestX, DestY
			Offsets := {}

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
					; When there is no item in the source cell, a click in the main area will cause the
					; character to move. Send the Stand Still key so the character doesn't move.
					; XXX This is causing some trouble, so disabled for now
					; Diablo2.Send(Format("{{}{} down{}}", this._StandStillKey))
					Click, %DestX%, %DestY%
					; Diablo2.Send(Format("{{}{} up{}}", this._StandStillKey))
					Sleep, 300
				}
			}

			this._Reset()
		}

		; Move a block of single-cell items to set of empty cells.
		gMoveSingleCellItems() {
			if (!this._HasSelection()) {
				return
			}
			Size := this._Size
			MouseGetPos, DestX, DestY
			TopLefts := {Source: this._TopLeft, Dest: {X: DestX, Y: DestY}}

			this._Log(Format("Moving {} cells to {},{}"
				, Size.X * Size.Y, this._TopLeft.X, this._TopLeft.Y))
			Diablo2.Voice.Speak("Move")

			Offsets := {}

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

			this._Reset()
		}

		; Determine if there is an existing item selection.
		;
		; Returns: Boolean indicating existence of selection
		_HasSelection() {
			HasSelection := this._TopLeft.HasKey("X")
			if (!HasSelection) {
				Message := "No selection found"
				this._Log(Message, "ERROR")
				Diablo2.Voice.Speak(Message)
			}
			return HasSelection
		}

		; Reset item selection.
		_Reset() {
			this._Start := {}
			this._Size := {}
			this._TopLeft := {}
		}
	}

	class _FillPotionFeature extends Diablo2._EnabledFeature {
		; Defaults
		_Fullscreen := true
		_LesserFirst := true
		_FullscreenPotionsPerScreenshot := 3

		_Potions := {}
		_NeedleBitmaps := {}
		_HasBitmaps := true

		__New(Config) {
			; Require necessary controls
			for _, Function in ["Inventory Screen", "Show Belt", "Clear Screen", "Screen Shot"] {
				; Don't save the return value; we just want to check that these keys are set.
				Diablo2.GetControl(Function)
			}
			for _, Key in ["Fullscreen", "LesserFirst", "FullscreenPotionsPerScreenshot"] {
				if Config.HasKey(Key) {
					this["_" . Key] := Config[Key]
				}
			}
			; Set variation if it wasn't provided
			; Variation defaults are recommend; they were determined emperically
			this._Variation := Config.HasKey("Variation")
				? Config.Variation
				: (this._Fullscreen ? 50 : 120)
			; Prepare potion structures
			for _, Type_ in ["Healing", "Mana"] {
				this._Potions[Type_] := ["Minor", "Light", "Regular", "Greater", "Super"]
			}
			this._Potions.Rejuvenation := ["Regular", "Full"]
			; Reverse preference if necessary
			if (!this._LesserFirst) {
				for Type_, Sizes in this._Potions {
					; Reverse the array
					; Hints here: http://www.autohotkey.com/board/topic/45876-ahk-l-arrays/
					NewSizes := []
					Loop, % Length := Sizes.Length() {
						NewSizes.Push(Sizes[Length - A_Index + 1])
					}
					this._Potions[Type_] := NewSizes
				}
			}

			if (this._Fullscreen) {
				; Start GDI+ for full screen
				this._GdipToken := Gdip_Startup()
				if (!this._GdipToken) {
					Diablo2._Throw("GDI+ failed to start. Please ensure you have GDI+ on your system and that you are running a 32-bit version of AutoHotkey.")
				}
			}
			this._InitBitmaps()
			if (!this._HasBitmaps) {
				this._Log("Needle bitmaps not found; please generate them first")
				Diablo2.Voice.Speak("Please generate potion bitmaps")
			}
		}

		__Delete() {
			this._DisposeBitmaps()
			if (this.HasKey("_GdipToken")) {
				Gdip_Shutdown(this._GdipToken)
			}
		}

		; Fill the belt with potions.
		gActivate() {
			this._Function.Call()
		}

		; Create needle bitmaps from the contents of the screen.
		gGenerateBitmaps() {
			this._Log("Generating new needle bitmaps")
			Diablo2.ClearScreen()
			Diablo2.OpenInventory()
			Sleep, 100 ; Wait for the inventory to appear
			Diablo2.TakeScreenshot(ObjBindMethod(this, "_GenerateBitmapsFromScreenshot"))
		}

		; Generate and write needle bitmaps from a taken screenshot.
		_GenerateBitmapsFromScreenshot(ScreenshotPath) {
			this._StopWatchDirectory()
			; If we are in fullscreen, dispose the bitmaps so that our PowerShell script can access those
			; paths. The bitmaps will be re-created when resetting. If we are in windowed mode, this is a
			; no-op.
			this._GdipShutdown()
			this._Log("Running bitmap generation script")
			ScriptPath := Diablo2.AutoHotkeyLibDir . "\GenerateBitmaps.ps1"
			LogPath := A_WorkingDir . "\GenerateBitmaps.log"
			WindowType := this._Fullscreen ? "Fullscreen" : "Windowed"
			; Don't use -File: https://connect.microsoft.com/PowerShell/feedback/details/750653/powershell-exe-doesn-t-return-correct-exit-codes-when-using-the-file-option
			;
			; The goal is to capture stdout and stderr. RunWait internally uses Wscript.Shell.Run, which
			; doesn't capture the standard streams. Wscript.Shell.Exec does capture the standard streams,
			; but raises a PowerShell console, kicking a fullscreen user to the desktop when it runs. This
			; isn't acceptable, so in lieu of complicated solutions that would drop down to
			; CreateProcess(), we've just decided to write to a temporary file.
			RunWait, powershell -NoLogo -NonInteractive -NoProfile -Command "Start-Transcript '%LogPath%'; & '%ScriptPath%' -Verbose '%ScreenshotPath%' '%WindowType%'; Stop-Transcript", %A_WorkingDir%, Hide
			ExitCode := ErrorLevel

			; Remove the screen shot; it is not needed any more.
			FileDelete, %ScreenshotPath%

			; Log status
			FileRead, Output, %LogPath%
			FileDelete, %LogPath%
			this._Log(Format("Bitmap generation finished with exit code {} and output:`r`n{}", ExitCode, RTrim(Output, "`r`n")))
			; Check for success
			Status := ExitCode == 0 ? "succeeded" : "failed"
			this._("Needle bitmap generation " . Status)
			Diablo2.Voice.Speak("Bitmap generation " . Status)
			if (ExitCode == 0) {
				Diablo2.ClearScreen()
				this._InitBitmaps()
				if (this._HasBitmaps) {
					Diablo2.Voice.Speak(this._Name . " enabled")
					this._Log("Enabled")
				}
				else {
					Message := "Bitmaps still not found"
					Diablo2._Throw(Message, , {Speak: Message})
				}
			}
		}

		; Called when bitmaps are missing.
		_NoBitmaps() {
			this._Log("Disabled due to missing bitmaps")
			Diablo2.Voice.Speak("Please generate potion bitmaps")
		}

		; Stop watching for new screenshots.
		_StopWatchDirectory() {
			WatchDirectory("")
		}

		; Dispose images and shut down GDI+.
		_DisposeBitmaps() {
			if (this.HasKey("_GdipToken")) {
				for Type_, Sizes in this._NeedleBitmaps {
					for _, Bitmap in Sizes {
						Gdip_DisposeImage(Bitmap)
					}
				}
			}
		}

		; Check for and initialize bitmaps.
		_InitBitmaps() {
			BitmapPaths := {}
			for Type_, Sizes in this._Potions {
				for _, Size in Sizes {
					Path := this._ImagePath(Type_, Size)
					if (!FileExist(Path)) {
						this._HasBitmaps := false
						this._Function := ObjBindMethod(this, "_NoBitmaps")
						return
					}
					BitmapPaths[Type_, Size] := Path
				}
			}
			; Cache needle bitmaps
			if (this._Fullscreen) {
				for Type_, Sizes in BitmapPaths {
					for Size, Path in Sizes {
						this._NeedleBitmaps[Type_, Size] := Diablo2.SafeCreateBitmapFromFile(Path)
					}
				}
			}
			; Assign function
			this._Function := ObjBindMethod(this, this._Fullscreen ? "_FullscreenBegin" : "_Windowed")
		}

		; Return the potion image path for a specified type and size.
		;
		; Parameters:
		; Type
		;     Potion type (Healing, Mana, Rejuvenation)
		; Size
		;     Potion size (Minor, Light, Regular, Greater, Super)
		;
		; Returns: the image path
		_ImagePath(Type_, Size) {
			return Format("{}\Images\{}\{}\{}.png"
				, A_WorkingDir
				, this._Fullscreen ? "Fullscreen" : "Windowed"
				, Type_, Size)
		}

		; Perform a click to insert a potion into the belt.
		;
		; Parameters:
		; Coords
		;     The coordinates of the intended click
		_Click(Coords) {
			; The sleeps here are totally emperical. Just seems to work best this way.
			Sleep, 150
			MouseGetPos, MouseX, MouseY
			LButtonIsDown := GetKeyState("LButton")

			; Click doesn't support expressions (at all)
			X := Coords.X, Y := Coords.Y
			Click, %X%, %Y%
			MouseMove, MouseX, MouseY
			if (LButtonIsDown) {
				Diablo2.Send("{LButton down}")
			}
			Sleep, 150
		}

		; Perform starting tasks for a FillPotion run.
		_Begin() {
			this._Log(Format("Starting {} run", this._Fullscreen ? "fullscreen" : "windowed"))
			Diablo2.ClearScreen()
			Diablo2.OpenInventory()
			Diablo2.ShowBelt()
			Diablo2.Send("{Shift down}")
		}

		; End insertion of potions to the belt and clear the screen.
		_End() {
			this._Log("Finishing run")
			Diablo2.Send("{Shift up}")
			Diablo2.ClearScreen()
		}

		_LogWithType(Type_, Message) {
			this._Log(Format("{1:-12}|{2}", Type_, Message))
		}

		_LogWithSize(Type_, Size, Message) {
			this._LogWithType(Type_, Format("{1:-7}|{2}", Size, Message))
		}

		; Fill the belt with potions in windowed mode.
		_Windowed() {
			this._Begin()
			for Type_, Sizes in this._Potions {
				LastPotion := {X: -1, Y: -1}
WindowedSizeLoop:
				for _, Size in Sizes {
					NeedlePath := this._ImagePath(Type_, Size)
					Loop {
						try {
							ImageSearch, PotionX, PotionY
								, % Diablo2.Inventory.TopLeft.X, % Diablo2.Inventory.TopLeft.Y
								, % Diablo2.Inventory.BottomRight.X, % Diablo2.Inventory.BottomRight.Y
								, % Format("*{} {}", this._Variation, NeedlePath)
						}
						catch {
							; XXX This should really be in a finally at the end... but, it doesn't work for some
							; reason.
							this._End()
							Diablo2._Throw("Needle image file not found: " . NeedlePath)
						}
						if (ErrorLevel == 1) {
							break ; Image not found on the screen.
						}
						Potion := {X: PotionX, Y: PotionY}
						if (LastPotion.X == Potion.X and LastPotion.Y == Potion.Y) {
							this._LogWithType(Type_, "Finished for run due to full belt")
							break, WindowedSizeLoop
						}
						this._LogWithSize(Type_, Size, Format("Clicking {1},{2}", Potion.X, Potion.Y))
						this._Click(Potion)
						LastPotion := Potion
					}
				}
				if (LastPotion.X == -1) {
					this._LogWithType(Type_, "Finished because no potions left")
				}
			}
			this._End()
		}

		; Begin filling belt with potions in fullscreen mode.
		_FullscreenBegin() {
			this._Begin()
			; Initialize structures
			for Type_ in this._Potions {
				this["_FullscreenState", Type_] := {SizeIndex: 1, Finished: false, PotionsClicked: []}
			}
			Sleep, 100 ; Wait for the inventory to appear
			try {
				Diablo2.TakeScreenshot(ObjBindMethod(this, "_FullscreenProcess"))
			}
			catch {
				; XXX This should really be a finally... but, it doesn't work for some reason.
				this._End()
				throw Exc
			}
		}

		; Process screenshot to fill the belt with potions in fullscreen mode.
		g_FullscreenProcess(HaystackPath) {
			this._Log("Processing " . HaystackPath)

			HaystackBitmap := ""
			try {
				; In the past, we tried tic's Gdip_ImageSearch. However, it is broken as reported in the
				; bugs. w and h are supposed (?) to represent width and height; they are used as such in the
				; AHK code but not the C code. This causes problems and an inability to find the needle. We
				; are now using MasterFocus' Gdip_ImageSearch, which works well.
				; http://www.autohotkey.com/board/topic/71100-gdip-imagesearch/
				HaystackBitmap := Diablo2.SafeCreateBitmapFromFile(HaystackPath)
				; Assume we are finished for now; invalidate later if we are not.
				Finished := true

				for Type_, Sizes in this._Potions {
					if (this._FullscreenState[Type_].Finished) {
						; We have already finished finding potions of this type.
						continue
					}
					PotionsClicked := []
PotionSizeLoop:
					Loop {
						Size := Sizes[this._FullscreenState[Type_].SizeIndex]
						this._LogWithSize(Type_, Size, "Searching")
						NumPotionsFound := Gdip_ImageSearch(HaystackBitmap
							, this._NeedleBitmaps[Type_][Size]
							, CoordsListString
							, Diablo2.Inventory.TopLeft.X, Diablo2.Inventory.TopLeft.Y
							, Diablo2.Inventory.BottomRight.X, Diablo2.Inventory.BottomRight.Y
							, this._Variation
							; These two blank parameters are transparency color and search direction.
							, ,
							; For the number of instances to find, pass one more than the user requested so that we
							; can terminate early if possible. If they passed 0, find all instances with 0.
							, this._FullscreenPotionsPerScreenshot == 0 ? 0 : this._FullscreenPotionsPerScreenshot + 1)

						; Anything less than 0 indicates an error.
						if (NumPotionsFound < 0) {
							Diablo2._Throw("Gdip_ImageSearch call failed with error code " . NumPotionsFound)
						}

						; Collect all the potions we found into an array.
						PotionsFound := []
						for _3, CoordsString in StrSplit(CoordsListString, "`n") {
							Coords := StrSplit(CoordsString, "`,")
							PotionFound := {X: Coords[1], Y: Coords[2]}
							this._LogWithSize(Type_, Size, Format("Found at {1},{2}", PotionFound.X, PotionFound.Y))
							; If any of the potions found were clicked before, the belt is already full of this type
							; and we are finished with it.
							for _4, PotionClicked in this._FullscreenState[Type_].PotionsClicked {
								if (PotionFound.X == PotionClicked.X and PotionFound.Y == PotionClicked.Y) {
									this._FullscreenState[Type_].Finished := true
									this._LogWithType(Type_, "Finished for run due to full belt")
									break, PotionSizeLoop
								}
							}
							PotionsFound.Push(PotionFound)
						}

						; Click potions.
						NumPotionsToClick := (this._FullscreenPotionsPerScreenshot == 0
							? NumPotionsFound
							: Diablo2._Min(NumPotionsFound
								, this._FullscreenPotionsPerScreenshot - PotionsClicked.Length()))
						Loop, % NumPotionsToClick {
							Potion := PotionsFound[A_Index]
							this._LogWithSize(Type_, Size, Format("Clicking {1},{2}", Potion.X, Potion.Y))
							this._Click(Potion)
							PotionsClicked.Push(Potion)
						}

						if (this._FullscreenPotionsPerScreenshot > 0
							and PotionsClicked.Length() >= this._FullscreenPotionsPerScreenshot) {
							; We can't click any more potions for this screenshot.
							Finished := false
							this._LogWithType(Type_, "Finished for screenshot")
							break
						}

						; Move on to the next size.
						++this._FullscreenState[Type_].SizeIndex

						; Check to see if we have run out of potion sizes for this type. This has happened if
						; the size index has been incremented beyond the bounds of the size array.
						if this._FullscreenState[Type_].SizeIndex > Sizes.Length() {
							this._FullscreenState[Type_].Finished := true
							this._LogWithType(Type_, "Finished because no potions left")
							break
						}
					}

					; Record all the potions of this type we clicked for this screenshot.
					this._FullscreenState[Type_].PotionsClicked := PotionsClicked
				}

				if (Finished) {
					; If we are still considered finished, check to see if every type has finished.
					for Type_, Obj in this._FullscreenState {
						if (!Obj.Finished) {
							; We still have potions over which to iterate.
							Finished := false
							break
						}
					}
				}
				if (Finished) {
					this._StopWatchDirectory()
					this._End()
				}
				else {
					this._Log("Requesting updated screenshot")
					; Wait slightly for the game to update
					; Sleep, 100

					; Get the next screenshot
					Diablo2.Send(Diablo2.GetControl("Screen Shot", true))
				}
			}
			catch Exc {
				; Stop watch, end filling of potions, then re-throw.
				this._StopWatchDirectory()
				this._End()
				throw Exc
			}
			finally {
				if (HaystackBitmap) {
					Gdip_DisposeImage(HaystackBitmap)
				}
				; Remove the screen shot regardless.
				FileDelete, %HaystackPath%
			}
		}
	}

	class _SteamFeature extends Diablo2._EnabledFeature {
		; Default overlay key for Steam
		_OverlayKey := "^{Tab}"
		_BrowserTabUrls := ["http://blizzard.com/diablo2/"]

		__New(Config) {
			; We want Steam.BrowserOpenTabs() to run under suspension because hotkeys should be suspended
			; when the overlay is open. Because Suspend, Permit does not work in function references, a
			; hotkey which calls a suspend permit function cannot accept arguments. We therefore have to
			; accept BrowserTabs as a configuration option instead of an argument to
			; Steam.BrowserOpenTabs().
			for _, Key in ["OverlayKey", "BrowserTabUrls"] {
				if (Config.HasKey(Key)) {
					this["_" . Key] := Config[Key]
				}
			}
		}

		; Launch the game through Steam. See the README for instructions on setting this up.
		;
		; Parameters:
		; GameUrl
		;     The URL to run the game through Steam
		LaunchGame(GameUrl) {
			this._Log("Running game with Url " . GameUrl)
			Run, %GameUrl%
			Diablo2._SuspendUntilGameJoined()
		}
	}
}

; Any functions that should be able to be activated when hotkeys are suspended need to be outside
; the namespace class. It's unfortunate, but it doesn't work to pass a function reference (using
; Func(...) or ObjBindMethod(...)) in which the function has "Suspend, *" as the first line.

; Suspend the macros.
;
; Parameters:
; Mode
;     Passed directly to Suspend command
_Diablo2_Suspend(Mode := "Toggle") {
	Suspend, %Mode%
	CurrentState := A_IsSuspended ? "Suspended" : "Resumed"
	Diablo2.Log.Message("Global", CurrentState)
	Diablo2.Voice.Speak(CurrentState)
}

; Exit the macros.
_Diablo2_Exit() {
	Suspend, Permit
	Diablo2.Voice.Speak("Exiting", true)
	ExitApp
}

; Report status of the macros.
_Diablo2_Status() {
	Suspend, Permit
	Diablo2.Log.Message("Global", "Logging status report")
	HotkeysActive := "Hotkeys " . (A_IsSuspended ? "Suspended" : "Active")
	Diablo2.Log.Message("Global", HotkeysActive)
	SpeakStr := HotkeysActive
	FeaturesByStatus := {Enabled: [], Disabled: []}
	for Name, Feature in Diablo2._Features {
		Enabled := Feature.Enabled ? "Enabled" : "Disabled"
		FeaturesByStatus[Enabled].Push(Name)
		Diablo2.Log.Message(Name, Enabled)
	}
	SpeakStr := HotkeysActive
	for _1, Enabled in ["Enabled", "Disabled"] {
		SpeakStr .= Format(", {} features", Enabled)
		Features := FeaturesByStatus[Enabled]
		if (Features.Length() > 0) {
			for _2, Feature in Features {
				SpeakStr .= ", " . Feature
			}
		}
		else {
			SpeakStr .= ", None"
		}
	}
	Diablo2.Voice.Speak(SpeakStr)
}

; Toggle the Steam overlay.
_Diablo2_Steam_OverlayToggle() {
	Suspend, Permit
	_Diablo2_Suspend()
	Diablo2.Send(Diablo2.Steam._OverlayKey)
}

; Open tabs in the Steam Web Browser. First, provide the Steam feature a list of tab URLs you would
; like opened. Then assign this function to a hotkey. Next, open the web browser and position your
; mouse over the URL bar. Then press the hotkey to load the tabs.
;
; Note: This function is best-effort. The Steam Web Browser (and overlay in general) can be very
; finicky and sometimes this function does not want to work correctly.
;
; Parameters:
; TabUrls
;     List of strings representing URLs to open in the browser
_Diablo2_Steam_BrowserOpenTabs() {
	Suspend, Permit

	; Grab the mouse's position over the URL bar.
	MouseGetPos, MouseX, MouseY

	; Ensure we are suspended.
	Suspend, On

	for _, Url in Diablo2.Steam._BrowserTabUrls {
		; Use SendEvent to enable delays. Change the key press delay for keystrokes using SendEvent
		; because the Steam overlay is laggy in detecting them. Without this, keys will be dropped.
		;
		; This sets the key delay only for this thread, so we don't need to worry about setting it
		; back. Hopefully the user assigned this to a hotkey as suggested.
		SetKeyDelay, 0, 100
		SendEvent, ^t

		; Click where the user had the mouse.
		Click, %MouseX%, %MouseY%
		Sleep, 100
		SetKeyDelay, 0, 10
		SendEvent, {Raw}%Url%
		SendEvent, {Enter}
		; Let the tab load a bit. If we don't do this, the tab usually ends up in error.
		Sleep, 1000
	}

	; Don't resume hotkeys because we are still in the overlay. If the user is using the Steam
	; macros, hotkeys are hopefully suspended before this function started executing, so leave
	; them suspended.
}

; Wrapper for the screenshot WatchDirectory callback.
_Diablo2_ScreenshotCallback(WDThis, FromPath, ToPath) {
	; In both WatchDirectory's master branch (which has incorrect docs) and v2-alpha (which has
	; correct docs), the callback function takes three arguments:
	;
	; - WatchDirectory "this" object (not quite sure what this is)
	; - "from path"
	; - "to path"
	;
	; Both the "from" and "to" paths will be populated for FILE_NOTIFY_CHANGE_LAST_WRITE, but
	; we'll just use the latter.
	;
	; XXX: Calling a function object in an essentially global variable is certainly a race condition
	; if more than one thread calls TakeScreenshot().
	Diablo2._ScreenshotCallback.Call(ToPath)
}
