<#
.SYNOPSIS
  To'liq avtomat: GitHub repo yaratish + push + Telegram post.
.DESCRIPTION
  Loyiha papkasini GitHub'ga push qiladi va Telegram kanaliga
  o'zbekcha post yuboradi. Tokenlar .env yoki TOKENS.md dan olinadi
  va hech qachon log'ga chiqarilmaydi.
.PARAMETER Path
  Loyiha papkasi (hozirgi papka yoki nisbiy yo'l).
.PARAMETER Repo
  GitHub repo nomi (masalan: my-app).
.PARAMETER Desc
  Qisqa tavsif — post matni ham shundan yig'iladi.
.PARAMETER Demo
  Demo URL (ixtiyoriy).
.PARAMETER Private
  Repo private qilinsin.
.PARAMETER DryRun
  Hech narsa yubormasdan, faqat natijani ko'rsatish.
.PARAMETER SkipTelegram
  Faqat GitHub, Telegram'siz.
.EXAMPLE
  .\publish.ps1 -Path D:\AI\my-app -Repo my-app -Desc "AI yordamchi" -Demo https://my-app.fly.dev
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Path,
  [Parameter(Mandatory = $true)][string]$Repo,
  [string]$Desc = 'Yangi loyiha',
  [string]$Demo = '',
  [switch]$Private,
  [switch]$DryRun,
  [switch]$SkipTelegram
)

$ErrorActionPreference = 'Stop'
$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---------- 0) .env ni yuklash ----------
if (Test-Path (Join-Path $Dir '.env')) {
  Get-Content (Join-Path $Dir '.env') | ForEach-Object {
    if ($_ -match '^\s*([A-Za-z0-9_]+)\s*=\s*(.*)\s*$') {
      $n = $Matches[1]; $v = $Matches[2].Trim().Trim('"').Trim("'")
      if (-not (Get-Item "env:$n" -ErrorAction SilentlyContinue)) { Set-Item -Path "env:$n" -Value $v }
    }
  }
}

# ---------- 1) Loyiha papkasini tekshirish ----------
$ProjectDir = if (Test-Path $Path) { (Resolve-Path $Path).Path } else { $null }
if (-not $ProjectDir) { throw "XATO: papka topilmadi -> $Path" }
if (-not (Test-Path (Join-Path $ProjectDir '.'))) { throw "XATO: $ProjectDir — papka emas." }

# ---------- 2) GitHub token: env > .env > TOKENS.md ----------
function Find-GitHubToken {
  if ($env:GITHUB_TOKEN) { return $env:GITHUB_TOKEN }
  $candidates = @(
    (Join-Path $Dir '..\TOKENS.md'),
    (Join-Path $env:USERPROFILE 'TOKENS.md'),
    (Join-Path $env:USERPROFILE 'Download\TOKENS.md')
  )
  foreach ($f in $candidates) {
    if ($f -and (Test-Path $f)) {
      $m = Select-String -Path $f -Pattern 'ghp_[A-Za-z0-9]+' -AllMatches -ErrorAction SilentlyContinue |
           Select-Object -First 1
      if ($m) { return $m.Matches[0].Value }
    }
  }
  return $null
}

$GITHUB_TOKEN = Find-GitHubToken
if (-not $GITHUB_TOKEN) { throw 'XATO: GITHUB_TOKEN topilmadi (env, .env yoki TOKENS.md).' }
$headers = @{ Authorization = "Bearer $GITHUB_TOKEN"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'opencode-publish' }

# ---------- 3) Token egasi ----------
try {
  $me = Invoke-RestMethod -Uri 'https://api.github.com/user' -Headers $headers
} catch {
  $m = $_.Exception.Message -replace [regex]::Escape($GITHUB_TOKEN), '***'
  throw "XATO: GitHub token ishlamadi — $m"
}
$Login = $me.login
$RepoUrl = "https://github.com/$Login/$Repo"
Write-Host "GitHub user: $Login" -ForegroundColor Cyan
Write-Host "Repo: $RepoUrl" -ForegroundColor Cyan
Write-Host "Papka: $ProjectDir" -ForegroundColor Cyan

# ---------- 4) Repo yaratish ----------
if ($DryRun) {
  Write-Host "[dry-run] repo yaratish o'tkazib yuborildi" -ForegroundColor DarkGray
} else {
  $payload = @{ name = $Repo; description = $Desc; private = [bool]$Private; auto_init = $false } |
             ConvertTo-Json -Compress
  try {
    $created = Invoke-RestMethod -Method Post -Uri 'https://api.github.com/user/repos' -Headers $headers -Body $payload -ContentType 'application/json'
    Write-Host "Repo yaratildi: $($created.full_name)" -ForegroundColor Green
  } catch {
    $body = $_.ErrorDetails.Message
    if ($body -match 'already exists|name already taken') {
      Write-Host 'Repo avvaldan bor — push davom etadi.' -ForegroundColor Yellow
    } else {
      $b = ($body -replace [regex]::Escape($GITHUB_TOKEN), '***')
      Write-Host "OGOHLANTIRISH (repo yaratish): $b" -ForegroundColor Yellow
    }
  }
}

# ---------- 5) Git add / commit / push ----------
if (-not (Test-Path (Join-Path $ProjectDir '.git'))) {
  Write-Host 'git init ...' -ForegroundColor Cyan
  if (-not $DryRun) {
    git -C $ProjectDir init | Out-Null
    git -C $ProjectDir add -A
    git -C $ProjectDir commit -m "Initial: $Desc" 2>&1 | Out-Null
    git -C $ProjectDir branch -M main
  }
} else {
  Write-Host 'git repo bor — commit + push' -ForegroundColor Cyan
  if (-not $DryRun) {
    git -C $ProjectDir add -A
    git -C $ProjectDir commit -m "Update: $Desc" 2>&1 | Out-Null
    git -C $ProjectDir branch -M main 2>&1 | Out-Null
  }
}

if ($DryRun) {
  Write-Host "[dry-run] push o'tkazib yuborildi" -ForegroundColor DarkGray
} else {
  git -C $ProjectDir remote remove origin 2>&1 | Out-Null
  git -C $ProjectDir remote add origin "https://x-access-token:$GITHUB_TOKEN@github.com/$Login/$Repo.git"
  $out = git -C $ProjectDir push -u origin main --force-with-lease 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) { $out = git -C $ProjectDir push -u origin main 2>&1 | Out-String }
  $safe = $out -replace [regex]::Escape("x-access-token:$GITHUB_TOKEN"), 'x-access-token:***'
  Write-Host $safe.Trim()
  if ($LASTEXITCODE -ne 0) { throw "XATO: git push muvaffaqiyatsiz (yuoridagi xabarni ko'ring)." }
  # Tokenni remote URL dan olib tashlaymiz
  git -C $ProjectDir remote set-url origin $RepoUrl
  Write-Host "Push OK -> $RepoUrl" -ForegroundColor Green
}

# ---------- 6) Telegram post ----------
$DemoLine = if ($Demo) { "🌐 Demo: $Demo" } else { '🌐 Demo: tez kunda' }
$Post = @"
🚀 Yangi loyiha — $Repo

📝 $Desc

🔗 GitHub: $RepoUrl
$DemoLine

#AI #loyiha #github #automation
"@

Write-Host '---- POST MATNI ----' -ForegroundColor DarkGray
Write-Host $Post
Write-Host '--------------------' -ForegroundColor DarkGray

if ($DryRun)  { Write-Host '[dry-run] telegram yuborilmadi' -ForegroundColor DarkGray; exit 0 }
if ($SkipTelegram) { Write-Host '[skip] telegram yuborilmadi' -ForegroundColor DarkGray; exit 0 }

if (-not $env:TELEGRAM_BOT_TOKEN) {
  Write-Host "OGOH: TELEGRAM_BOT_TOKEN yo'q — faqat GitHub qilindi. (.env ga qo'sh: $Dir\.env)" -ForegroundColor Yellow
  exit 0
}

if (-not $env:TELEGRAM_CHANNEL) {
  Write-Host "OGOH: TELEGRAM_CHANNEL yo'q — faqat GitHub qilindi. (.env ga kanal nomini yozing)" -ForegroundColor Yellow
  exit 0
}
$chat = $env:TELEGRAM_CHANNEL
$json = @{ chat_id = $chat; text = $Post; disable_web_page_preview = $false } | ConvertTo-Json -Compress
$body = [System.Text.Encoding]::UTF8.GetBytes($json)
try {
  $r = Invoke-RestMethod -Method Post -Uri "https://api.telegram.org/bot$($env:TELEGRAM_BOT_TOKEN)/sendMessage" `
        -Body $body -ContentType 'application/json; charset=utf-8'
  if ($r.ok) { Write-Host "Telegram OK -> $chat" -ForegroundColor Green }
  else { Write-Host "Telegram XATO: $($r.description)" -ForegroundColor Red }
} catch {
  $m = $_.Exception.Message -replace [regex]::Escape($env:TELEGRAM_BOT_TOKEN), '***'
  Write-Host "Telegram XATO: $m" -ForegroundColor Red
  Write-Host "Bot kanalga admin ekanini tekshir: $chat" -ForegroundColor Yellow
}
