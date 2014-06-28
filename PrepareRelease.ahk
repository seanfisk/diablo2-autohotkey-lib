#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Enable warnings to assist with detecting common errors.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

SampleDirName = Sample
DistDirName = D2Macros
MainScriptName = D2Macros.ahk

; Create distribution directory.
FileCreateDir, %DistDirName%
for FileIndex, FileName in [MainScriptName, "Keys.json", "SkillWeaponSets.json"] {
		; Last parameter tells FileCopy to overwrite.
		FileCopy, %SampleDirName%\%FileName%, %DistDirName%\%FileName%, 1
}

; Compile the main script using Ahk2Exe.
RunWait, Ahk2Exe /in %MainScriptName%, %DistDirName%

; Create a zip archive using 7-zip.
RunWait, 7z a -tzip %DistDirName%.zip %DistDirName%

; Destroy the temporary distribution directory.
; 1 means recurse.
FileRemoveDir, %DistDirName%, 1
