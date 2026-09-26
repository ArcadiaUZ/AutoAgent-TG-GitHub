<#
.SYNOPSIS
  flyctl'ni o'rnatadi va FLY_API_TOKEN so'raydi.
#>
[CmdletBinding()]
param([switch]$Yes)

$ErrorActionPreference = 'Stop'

if (Get-Command flyctl -ErrorAction SilentlyContinue) {
  Write-Host "flyctl allaqach o'rnatilgan." -ForegroundColor Green
  & flyctl version
  exit 0
}

if (-not $Yes) {
  Write-Host "flyctl o'rnatilmoqda (fly.io rasmiy install skripti)." -ForegroundColor Cyan
  Write-Host "Davom etish uchun -Yes qo'shing yoki buyruqni to'g'radan ishga tushiring:" -ForegroundColor Yellow
  Write-Host '  powershell -NoProfile -ExecutionPolicy Bypass -File .\install-fly.ps1 -Yes' -ForegroundColor Green
  Write-Host ''
  Write-Host "Keyin https://fly.io/dashboard/ dan token oling va .env ga yozing:" -ForegroundColor Cyan
  Write-Host '  FLY_API_TOKEN=<token>' -ForegroundColor White
  exit 0
}

Write-Host 'flyctl yuklanmoqda...' -ForegroundColor Cyan
$install = Join-Path $env:TEMP 'fly-install.ps1'
Invoke-WebRequest -Uri 'https://fly.io/install.ps1' -OutFile $install -UseBasicParsing
& powershell -NoProfile -ExecutionPolicy Bypass -File $install

$binDir = Join-Path $env:USERPROFILE '.fly\bin'
if (-not (Test-Path $binDir)) { $binDir = Join-Path $env:USERPROFILE 'bin' }
$env:PATH = "$binDir;$env:PATH"
[Environment]::SetEnvironmentVariable('PATH', "$binDir;$env:PATH", 'User')

Write-Host ''
Write-Host "flyctl o'rnatildi:" -ForegroundColor Green
& (Join-Path $binDir 'flyctl.exe') version

Write-Host ''
Write-Host 'Qolgan qadamlar:' -ForegroundColor Cyan
Write-Host "  1) https://fly.io/dashboard/ -> ""Access Tokens"" -> token yarating" -ForegroundColor White
Write-Host "  2) .env fayliga qo'shing:  FLY_API_TOKEN=<token>" -ForegroundColor White
Write-Host "  3) fly auth login  (yoki .env tokeni bilan avtomat ishlaydi)" -ForegroundColor White
