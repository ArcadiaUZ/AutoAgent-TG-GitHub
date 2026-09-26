<#
.SYNOPSIS
  Telegram kanaliga post yuborish.
.DESCRIPTION
  .env faylidan TELEGRAM_BOT_TOKEN va TELEGRAM_CHANNEL ni oladi va
  xabarni kanalga yuboradi. Token hech qachon ekranga chiqarilmaydi.
.EXAMPLE
  .\send-telegram.ps1 "Salom!" -Channel @my_channel
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)][string]$Message,
  [string]$Channel = ''
)

$ErrorActionPreference = 'Stop'
$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (Test-Path (Join-Path $Dir '.env')) {
  Get-Content (Join-Path $Dir '.env') | ForEach-Object {
    if ($_ -match '^\s*([A-Za-z0-9_]+)\s*=\s*(.*)\s*$') {
      $n = $Matches[1]; $v = $Matches[2].Trim().Trim('"').Trim("'")
      if (-not (Get-Item "env:$n" -ErrorAction SilentlyContinue)) {
        Set-Item -Path "env:$n" -Value $v
      }
    }
  }
}

$Token  = $env:TELEGRAM_BOT_TOKEN
$ChatId = if ($Channel) { $Channel } else { $env:TELEGRAM_CHANNEL }

if (-not $Token) { throw "XATO: TELEGRAM_BOT_TOKEN yo'q. $Dir\.env ga qo'shing." }
if (-not $ChatId) { throw "XATO: TELEGRAM_CHANNEL yo'q. .env ga kanal nomini yozing yoki -Channel parametridan foydalaning." }
if (-not $Message) { throw "XATO: xabar matni bo'sh" }

$json = @{
  chat_id                = $ChatId
  text                   = $Message
  disable_web_page_preview = $false
} | ConvertTo-Json -Compress
$body = [System.Text.Encoding]::UTF8.GetBytes($json)

try {
  $r = Invoke-RestMethod -Method Post -Uri "https://api.telegram.org/bot$Token/sendMessage" `
        -Body $body -ContentType 'application/json; charset=utf-8'
  if ($r.ok) { Write-Host "OK: post yuborildi -> $ChatId" -ForegroundColor Green }
  else { throw "Telegram rad etdi: $($r.description)" }
} catch {
  $msg = $_.Exception.Message -replace [regex]::Escape($Token), '***'
  throw "Telegram XATO: $msg`nBot kanalga admin ekanini tekshir."
}
