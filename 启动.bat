@echo off
chcp 65001 >nul
cd /d "%~dp0"
set "HERE=%~dp0"

echo.
echo   ================================================
echo    点墨 · 作文批改台
echo   ================================================
echo   位置：%HERE%
echo.

rem ── 1. 解除「来自网络」的封锁（外来的 .bat 会被 Windows 标记）──
powershell -NoProfile -Command "if (Get-Item -LiteralPath '%HERE%启动.bat' -Stream Zone.Identifier -ErrorAction SilentlyContinue) { Get-ChildItem -LiteralPath '%HERE%' -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue; Write-Host '  已解除文件的网络封锁标记。' }" >nul 2>nul

rem ── 2. 数据目录可写性自检 ──
if not exist "%HERE%data" mkdir "%HERE%data" 2>nul
echo test> "%HERE%data\.write_test" 2>nul
if not exist "%HERE%data\.write_test" (
  echo   x 无法写入 data 目录，这是权限问题，不是程序出错。
  echo.
  echo     解决办法：
  echo       把整个「作文批改平台（Teacher_Tony）」文件夹移到「文档」或「桌面」下你自己的目录里
  echo       ^(不要放在 C:\Program Files、C:\Windows 这类系统目录^)，再重新双击本文件。
  echo.
  pause
  exit /b 1
)
del "%HERE%data\.write_test" >nul 2>nul
echo   数据目录可读写 OK
echo.

rem ── 3. 找 Node.js：优先用随包自带的运行时 ──
set "NODE_EXE="
if exist "%HERE%runtime\node\node.exe" set "NODE_EXE=%HERE%runtime\node\node.exe"
if not defined NODE_EXE if exist "%HERE%node\node.exe" set "NODE_EXE=%HERE%node\node.exe"
if not defined NODE_EXE (
  where node >nul 2>nul
  if not errorlevel 1 set "NODE_EXE=node"
)
if not defined NODE_EXE (
  echo.
  echo   检测到本机还没有安装 Node.js，正在尝试自动安装 LTS 稳定版……
  echo   安装过程中若弹出「用户账户控制」窗口，请点「是」。
  echo.

  rem 优先用 winget（Win10 1809 / Win11 自带）
  where winget >nul 2>nul
  if not errorlevel 1 (
    winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
  )

  rem 安装后当前会话 PATH 不会刷新，直接在常见安装位置里找 node.exe
  if not defined NODE_EXE if exist "%ProgramFiles%\nodejs\node.exe" set "NODE_EXE=%ProgramFiles%\nodejs\node.exe"
  if not defined NODE_EXE if exist "%ProgramFiles(x86)%\nodejs\node.exe" set "NODE_EXE=%ProgramFiles(x86)%\nodejs\node.exe"
  if not defined NODE_EXE if exist "%LocalAppData%\Programs\nodejs\node.exe" set "NODE_EXE=%LocalAppData%\Programs\nodejs\node.exe"

  rem winget 不可用或没装成功：用 PowerShell 从官网下载 LTS 安装包并安装
  if not defined NODE_EXE (
    echo   winget 不可用或未成功，改为从官网下载安装包……
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $html=(Invoke-WebRequest -UseBasicParsing -Uri 'https://nodejs.org/dist/latest-v24.x/').Content; $m=[regex]::Match($html,'node-v[0-9]+(\.[0-9]+){2}-x64\.msi').Value; if(!$m){throw 'MSI 版本号解析失败'}; $p=Join-Path $env:TEMP $m; Write-Host ('正在下载 '+$m+' ……'); Invoke-WebRequest -Uri ('https://nodejs.org/dist/latest-v24.x/'+$m) -OutFile $p; Write-Host '下载完成，开始安装（静默模式，约 1 分钟）……'; & msiexec.exe /i $p /passive /norestart; Write-Host ('安装结束，退出码 '+$LASTEXITCODE)"
    if not defined NODE_EXE if exist "%ProgramFiles%\nodejs\node.exe" set "NODE_EXE=%ProgramFiles%\nodejs\node.exe"
    if not defined NODE_EXE if exist "%ProgramFiles(x86)%\nodejs\node.exe" set "NODE_EXE=%ProgramFiles(x86)%\nodejs\node.exe"
    if not defined NODE_EXE if exist "%LocalAppData%\Programs\nodejs\node.exe" set "NODE_EXE=%LocalAppData%\Programs\nodejs\node.exe"
  )
)

if not defined NODE_EXE (
  echo.
  echo   x 自动安装没有成功，请手动安装后重新双击本文件：
  echo       1. 到 https://nodejs.org 下载 LTS 版安装，装完重新双击本文件
  echo       2. 装完如果还是提示找不到，重启一次电脑再试
  echo.
  echo     本平台不依赖任何第三方库，只要有 Node.js 就能跑。
  echo.
  pause
  exit /b 1
)

echo   正在启动……浏览器会自动打开
echo   用完在本窗口按 Ctrl + C 关闭服务
echo.
"%NODE_EXE%" server.js
echo.
pause
