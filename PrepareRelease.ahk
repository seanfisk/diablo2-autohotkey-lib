#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  ; Enable warnings to assist with detecting common errors.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

SampleDirName = Sample
DistDirName = dist
BaseName = D2Macros

; Create distribution directory.
FileCreateDir, %DistDirName%
; Last parameter tells FileCopy to overwrite.
FileCopy, %SampleDirName%\*.json, %DistDirName%, 1

; Compile the main script using Ahk2Exe.
RunWait, Ahk2Exe /in %SampleDirName%\%BaseName%.ahk /out %DistDirName%\%BaseName%.exe

; Create a zip archive using 7-zip. Set the working directory to the dist dir to avoid storage of
; paths.
RunWait, 7z a ..\%BaseName%.zip ., %DistDirName%

; Destroy the temporary distribution directory.
; 1 means recurse.
FileRemoveDir, %DistDirName%, 1
