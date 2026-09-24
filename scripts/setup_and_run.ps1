# CaliMind Flutter Setup & Run Script
$ErrorActionPreference = "Stop"
$puroExe = "C:\Users\USER\AppData\Local\Microsoft\WinGet\Packages\pingbird.Puro_Microsoft.Winget.Source_8wekyb3d8bbwe\puro.exe"
$puroBin = "$env:USERPROFILE\.puro\bin"

Write-Host ">>> [1/5] Creating / Resuming Flutter stable environment via Puro..." -ForegroundColor Cyan
& $puroExe create stable

Write-Host ">>> [2/5] Setting active environment to stable for CaliMind..." -ForegroundColor Cyan
& $puroExe use stable

$env:PATH = "$puroBin;$env:PATH"

Write-Host ">>> [3/5] Verifying Flutter version..." -ForegroundColor Cyan
& $puroExe flutter --version

Write-Host ">>> [4/5] Running flutter pub get..." -ForegroundColor Cyan
& $puroExe flutter pub get

Write-Host ">>> [5/5] Running test suite..." -ForegroundColor Cyan
& $puroExe flutter test

Write-Host ">>> Ready! Starting CaliMind app..." -ForegroundColor Green
& $puroExe flutter run
