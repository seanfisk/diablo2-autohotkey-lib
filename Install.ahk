; Install the Diablo2 library and its dependency, JSON, to the AutoHotkey user library.

AutoHotkeyLibDir = %A_MyDocuments%\AutoHotkey\Lib

FileCreateDir, %AutoHotkeyLibDir%

FileCopy, Diablo2.ahk, %AutoHotkeyLibDir%, true
FileCopy, Vendor\JSON.ahk, %AutoHotkeyLibDir%, true

MsgBox, Install successful!`n`nInstalled to %AutoHotkeyLibDir%.
