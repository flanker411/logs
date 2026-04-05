@echo off

:: Check for admin rights
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting admin privileges...
    powershell -Command "Start-Process '%~f0' -Verb runAs"
    exit /b
)

:: Create temp script to type into Notepad
set "vbs=%temp%\type1.vbs"
echo Set WshShell = WScript.CreateObject("WScript.Shell") > "%vbs%"
echo WScript.Sleep 500 >> "%vbs%"
echo WshShell.SendKeys "1" >> "%vbs%"

:: Open Notepad and type
start notepad.exe
cscript //nologo "%vbs%"

del "%vbs%"