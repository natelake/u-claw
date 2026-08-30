@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1
title U-Claw - Install to Windows

echo.
echo   ========================================
echo     Install U-Claw on Windows
echo     Offline install from USB
echo   ========================================
echo.

set "UCLAW_DIR=%~dp0"
set "APP_DIR=%UCLAW_DIR%app"
set "INSTALL_TARGET=%USERPROFILE%\.uclaw"
set "MIRROR=https://registry.npmjs.org"
set "NODE_MIRROR=https://nodejs.org/dist"
set "NODE_VER=v22.22.3"

REM ---- Step 1: Check environment ----
echo   [1/4] Checking environment...

set "USE_NODE=none"
set "USB_NODE=%APP_DIR%\runtime\node-win-x64\node.exe"

if exist "%USB_NODE%" (
    for /f "tokens=*" %%v in ('"%USB_NODE%" --version') do echo   Node.js: using USB copy %%v
    set "USE_NODE=usb"
) else (
    where node >nul 2>&1
    if !errorlevel!==0 (
        for /f "tokens=*" %%v in ('node --version') do (
            echo   Node.js: checking system %%v
            set "SYS_VER=%%v"
        )
        REM Use only supported LTS majors. Newer Current releases can break native deps.
        for /f "tokens=1 delims=." %%m in ("!SYS_VER:v=!") do set "MAJOR=%%m"
        if !MAJOR! equ 20 (
            echo   Node.js: using system !SYS_VER!
            set "USE_NODE=system"
        ) else if !MAJOR! equ 22 (
            echo   Node.js: using system !SYS_VER!
            set "USE_NODE=system"
        ) else (
            echo   Node.js: system version not supported ^(!SYS_VER!^), will use bundled v22 LTS
            set "USE_NODE=download"
        )
    ) else (
        echo   Node.js: not installed
        set "USE_NODE=download"
    )
)

set "USB_OPENCLAW=%APP_DIR%\core\node_modules\openclaw\openclaw.mjs"
if exist "%USB_OPENCLAW%" (
    echo   OpenClaw: using USB copy
    set "USE_OPENCLAW=usb"
) else (
    echo   OpenClaw: not on USB, will download
    set "USE_OPENCLAW=download"
)

echo.

REM ---- Step 2: Check existing ----
if exist "%INSTALL_TARGET%" (
    echo   Existing install found: %INSTALL_TARGET%
    set /p OVERWRITE="  Overwrite? (y/n): "
    if /i not "!OVERWRITE!"=="y" (
        echo   Cancelled
        pause
        exit /b 0
    )
    echo.
)

REM ---- Step 3: Create directories ----
echo   [2/4] Creating install folder...
mkdir "%INSTALL_TARGET%" 2>nul
mkdir "%INSTALL_TARGET%\data\.openclaw" 2>nul
mkdir "%INSTALL_TARGET%\data\memory" 2>nul
mkdir "%INSTALL_TARGET%\data\backups" 2>nul
mkdir "%INSTALL_TARGET%\data\logs" 2>nul
echo.

REM ---- Step 4: Copy/Download Node.js ----
echo   [3/4] Installing Node.js...

if "!USE_NODE!"=="usb" (
    echo   Copying Node.js from USB...
    xcopy /s /e /q /y "%APP_DIR%\runtime\node-win-x64" "%INSTALL_TARGET%\runtime\node-win-x64\" >nul
    set "INSTALL_NODE=%INSTALL_TARGET%\runtime\node-win-x64\node.exe"
    set "INSTALL_NPM=%INSTALL_TARGET%\runtime\node-win-x64\npm.cmd"
    echo   Node.js installed.
) else if "!USE_NODE!"=="system" (
    set "INSTALL_NODE=node"
    set "INSTALL_NPM=npm"
    echo   Using system Node.js
) else (
    echo   Downloading Node.js %NODE_VER%...
    set "NODE_ZIP=node-%NODE_VER%-win-x64.zip"
    set "NODE_URL=%NODE_MIRROR%/%NODE_VER%/!NODE_ZIP!"
    echo   URL: !NODE_URL!
    echo.

    REM Download using curl (available on Windows 10+)
    curl -# -L "!NODE_URL!" -o "%TEMP%\!NODE_ZIP!"
    if !errorlevel! neq 0 (
        echo   [ERROR] 下载失败！请检查网络连接
        echo   Or download manually: !NODE_URL!
        pause
        exit /b 1
    )

    echo   Extracting...
    mkdir "%INSTALL_TARGET%\runtime\node-win-x64" 2>nul
    powershell -command "Expand-Archive -Path '%TEMP%\!NODE_ZIP!' -DestinationPath '%TEMP%\node-extract' -Force"
    xcopy /s /e /q /y "%TEMP%\node-extract\node-%NODE_VER%-win-x64\*" "%INSTALL_TARGET%\runtime\node-win-x64\" >nul
    rmdir /s /q "%TEMP%\node-extract" 2>nul
    del "%TEMP%\!NODE_ZIP!" 2>nul

    set "INSTALL_NODE=%INSTALL_TARGET%\runtime\node-win-x64\node.exe"
    set "INSTALL_NPM=%INSTALL_TARGET%\runtime\node-win-x64\npm.cmd"
    echo   Node.js downloaded.
)
echo.

REM ---- Step 5: Copy/Download OpenClaw ----
echo   [4/4] Installing OpenClaw...

if "!USE_OPENCLAW!"=="usb" (
    echo   Copying OpenClaw + plugins from USB...
    xcopy /s /e /q /y "%APP_DIR%\core" "%INSTALL_TARGET%\core\" >nul
    echo   OpenClaw installed.
) else (
    echo   Downloading OpenClaw...
    mkdir "%INSTALL_TARGET%\core" 2>nul
    (echo {"name":"u-claw-core","version":"1.0.0","private":true,"dependencies":{"openclaw":"latest"}})>"%INSTALL_TARGET%\core\package.json"
    cd /d "%INSTALL_TARGET%\core"
    call "!INSTALL_NPM!" install --registry=%MIRROR%
    call "!INSTALL_NPM!" install @sliverp/qqbot@latest --registry=%MIRROR%
    echo   OpenClaw downloaded.
)

set "QQ_DIR=%INSTALL_TARGET%\core\node_modules\@sliverp\qqbot"
if exist "!QQ_DIR!" (
    if not exist "!QQ_DIR!\dist\index.js" (
        echo   Building optional QQ plugin...
        pushd "!QQ_DIR!"
        call "!INSTALL_NPM!" install --include=dev --registry=%MIRROR% >nul 2>&1
        call "!INSTALL_NPM!" run build >nul 2>&1
        call "!INSTALL_NPM!" prune --omit=dev >nul 2>&1
        popd
    )
    if exist "!QQ_DIR!\node_modules\openclaw" rmdir /s /q "!QQ_DIR!\node_modules\openclaw" 2>nul
    if exist "!QQ_DIR!\dist\index.js" (
        echo   QQ plugin runtime ready.
    ) else (
        echo   [WARNING] QQ plugin missing dist\index.js
    )
)

REM ---- Copy extensions (WeChat plugin etc.) ----
REM OpenClaw loads extensions ONLY from OPENCLAW_STATE_DIR\extensions (single override,
REM no ~/.openclaw fallback). The generated start.bat points STATE_DIR at
REM %INSTALL_TARGET%\data\.openclaw, so the plugin MUST be staged there.
REM zod is copied from the bundled OpenClaw core: the plugin's npm tarball ships without
REM it and the host node_modules is off the plugin's resolution path, so otherwise the
REM plugin fails to load with "Cannot find module 'zod'".
set "WECHAT_DST=%INSTALL_TARGET%\data\.openclaw\extensions\openclaw-weixin"
if exist "%APP_DIR%\extensions\openclaw-weixin\openclaw.plugin.json" (
    echo   Installing WeChat plugin...
    mkdir "%INSTALL_TARGET%\data\.openclaw\extensions" 2>nul
    xcopy /s /e /q /y "%APP_DIR%\extensions\openclaw-weixin" "%WECHAT_DST%\" >nul
    if not exist "%WECHAT_DST%\node_modules\zod" if exist "%APP_DIR%\core\node_modules\zod" (
        mkdir "%WECHAT_DST%\node_modules" 2>nul
        xcopy /s /e /q /y "%APP_DIR%\core\node_modules\zod" "%WECHAT_DST%\node_modules\zod\" >nul
    )
    echo   WeChat plugin installed!
)

REM ---- Default config ----
if not exist "%INSTALL_TARGET%\data\.openclaw\openclaw.json" (
    (echo {"gateway":{"mode":"local","auth":{"token":"uclaw"}}})>"%INSTALL_TARGET%\data\.openclaw\openclaw.json"
)

REM ---- Copy HTML pages ----
if exist "%UCLAW_DIR%Config.html" copy "%UCLAW_DIR%Config.html" "%INSTALL_TARGET%\" >nul
if exist "%UCLAW_DIR%U-Claw.html" copy "%UCLAW_DIR%U-Claw.html" "%INSTALL_TARGET%\" >nul

REM ---- Create launch script ----
(
echo @echo off
echo setlocal EnableDelayedExpansion
echo chcp 65001 ^>nul 2^>^&1
echo title U-Claw
echo set "DIR=%%~dp0"
echo set "NODE_BIN=%%DIR%%runtime\node-win-x64\node.exe"
echo if not exist "%%NODE_BIN%%" set "NODE_BIN=node"
echo set "OPENCLAW_MJS=%%DIR%%core\node_modules\openclaw\openclaw.mjs"
echo set "OPENCLAW_HOME=%%DIR%%data"
echo set "OPENCLAW_STATE_DIR=%%DIR%%data\.openclaw"
echo set "OPENCLAW_CONFIG_PATH=%%DIR%%data\.openclaw\openclaw.json"
echo set "OPENCLAW_DISABLE_BONJOUR=1"
echo.
echo REM Find available port
echo set PORT=18789
echo :check_port
echo netstat -an ^| findstr ":%%PORT%% " ^| findstr "LISTENING" ^>nul 2^>^&1
echo if %%errorlevel%%==0 (
echo     set /a PORT+=1
echo     if !PORT! gtr 18799 (echo No available port ^& pause ^& exit /b 1^)
echo     goto :check_port
echo ^)
echo.
echo cd /d "%%DIR%%core"
echo start /B "" cmd /c "timeout /t 3 /nobreak ^>nul ^&^& start http://127.0.0.1:!PORT!/#token=uclaw"
echo "%%NODE_BIN%%" "%%OPENCLAW_MJS%%" gateway run --allow-unconfigured --force --port !PORT!
echo pause
) > "%INSTALL_TARGET%\start.bat"

echo.
echo   ========================================
echo     Install succeeded!
echo   ========================================
echo.
echo   Location: %INSTALL_TARGET%
echo.
for /f "tokens=*" %%s in ('powershell -command "(Get-ChildItem '%INSTALL_TARGET%' -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB" 2^>nul') do echo   Size: %%s MB
echo.
echo   Start:
echo     Double-click %INSTALL_TARGET%\start.bat
echo.
echo   First use:
echo     After start, the browser opens the config page
echo     Pick a model - enter API Key - start
echo.
pause
