@echo off
title MyVault Windows Build Tool
color 0A

echo ========================================================
echo               MYVAULT WINDOWS BUILDER                    
echo ========================================================
echo.
echo [1/3] Checking and terminating active my_vault.exe processes...
taskkill /F /IM my_vault.exe >nul 2>&1
timeout /t 1 /nobreak >nul 2>&1 || ping 127.0.0.1 -n 2 >nul

echo.
echo [2/3] Cleaning previous build caches...
call flutter clean
if %errorlevel% neq 0 (
    echo [ERROR] Flutter clean failed.
    pause
    exit /b %errorlevel%
)

echo.
echo [3/3] Compiling release build for Windows desktop...
call flutter build windows
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Build failed. Please check the compilation log.
    pause
    exit /b %errorlevel%
)
echo.
echo [4/4] Checking for Inno Setup Compiler (ISCC)...
set ISCC_PATH=
where iscc >nul 2>&1
if %errorlevel% equ 0 (
    set ISCC_PATH="iscc"
) else (
    if exist "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" (
        set ISCC_PATH="C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    )
)

if defined ISCC_PATH (
    echo [+] Inno Setup compiler found. Packaging application into setup wizard...
    call %ISCC_PATH% installer.iss
    if %errorlevel% neq 0 (
        echo.
        echo [WARNING] Installer creation failed, but release binary was compiled.
    ) else (
        echo.
        echo ========================================================
        echo [+] SUCCESS: Setup Wizard Created Successfully!
        echo [+] Installer is located at:
        echo     Output\MyVault_Setup.exe
        echo ========================================================
    )
) else (
    echo [-] Inno Setup compiler ISCC.exe not found in PATH or default path.
    echo     Skipping installer creation. To compile the installer, install
    echo     Inno Setup and add it to your environment variables.
)

echo.
pause
