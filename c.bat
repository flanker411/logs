@echo off

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting admin privileges...
    powershell -Command "Start-Process '%~f0' -Verb runAs"
    exit /b
)

set "vbs=%temp%\type3.vbs"
echo Set WshShell = WScript.CreateObject("WScript.Shell") > "%vbs%"
echo WScript.Sleep 500 >> "%vbs%"
echo WshShell.SendKeys "3" >> "%vbs%"

start notepad.exe
cscript //nologo "%vbs%"

del "%vbs%"