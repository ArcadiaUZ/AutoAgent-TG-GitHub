<#
.SYNOPSIS
  fly.io'ga xavfsiz deploy: reja tuzadi, foydalanuvchi tasdig'ini oladi, keyin o'rnadi.
.DESCRIPTION
  Loyiha hajmiga qarab resurs (CPU/RAM/vm size) avtomat tanlanadi, avto-suspend
  yoqiladi (pul tejash), va HECH QACHON foydalanuvchi tasdig'isiz mavjud app'ni
  o'zgartirmaydi. Tokentlar .env dan olinadi va hech qachon ekranga chiqarilmaydi.
.PARAMETER Path
  Loyiha papkasi.
.PARAMETER App
  fly app nomi. BERILMASA skript to'xtaydi va mavjud app'lar ro'yxatini chiqaradi —
  foydalanuvchi tanlaydi. Skript hech qachon o'zi nom tanlamaydi.
.PARAMETER New
  Yangi app yaratish (app nomi -App bilan birga beriladi). Mavjud app'ga tegilmaydi.
.PARAMETER Cpu
  CPU: shared-cpu-1x | shared-cpu-2x | performance-1x | performance-2x. Bo'sh = hajm bo'yicha.
.PARAMETER MemoryMb
  RAM (MB). Bo'sh = hajm bo'yicha.
.PARAMETER VmSize
  shared-cpu-1x | shared-cpu-2x | shared-cpu-4x | performance-1x | performance-2x | performance-4x | performance-8x.
.PARAMETER Region
  Joylashuv (masalan: fra, ord, ams). Bo'sh = fly.toml dagi yoki default.
.PARAMETER Profile
 loyiha hajmiga qarab resurs: auto (default) | tiny | small | medium | large.
.PARAMETER MinMachinesRunning
  Doimiy ishlaydigan mashina soni. Default 0 = to'liq avto-suspend (pul tejash).
.PARAMETER AutoStopMachines
  stop | suspend . Default suspend (avto-suspend, tez qayta ishga tushadi).
.PARAMETER NoAutoSuspend
  Avto-suspend'ni o'chiradi (Mahniva maydonida tavsiya etilmaydi).
.PARAMETER BuildOnly
  Faqat docker build / reja, deploy qilmaydi.
.PARAMETER Yes
  Rejani tasdiqlaydi va haqiqatan o'chqazadi. Yo'q bo'lsa skript faqat reja ko'rsatadi.
.PARAMETER DryRun
  Hech narsani o'zgartirmaydi.
.EXAMPLE
  .\deploy-fly.ps1 -Path D:\AI\my-app -App my-app
.EXAMPLE
  .\deploy-fly.ps1 -Path D:\AI\my-app -New -App my-app -Yes
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Path,
  [string]$App = '',
  [switch]$New,
  [string]$Cpu = '',
  [string]$MemoryMb = '',
  [string]$VmSize = '',
  [string]$Region = '',
  [ValidateSet('auto', 'tiny', 'small', 'medium', 'large')][string]$Profile = 'auto',
  [int]$MinMachinesRunning = 0,
  [ValidateSet('stop', 'suspend')][string]$AutoStopMachines = 'suspend',
  [switch]$NoAutoSuspend,
  [switch]$BuildOnly,
  [switch]$Yes,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path

# ---------- 0) .env ni yuklash (tokenlarni chiqarmasdan) ----------
if (Test-Path (Join-Path $Dir '.env')) {
  Get-Content (Join-Path $Dir '.env') | ForEach-Object {
    if ($_ -match '^\s*([A-Za-z0-9_]+)\s*=\s*(.*)\s*$') {
      $n = $Matches[1]; $v = $Matches[2].Trim().Trim('"').Trim("'")
      if (-not (Get-Item "env:$n" -ErrorAction SilentlyContinue)) { Set-Item -Path "env:$n" -Value $v }
    }
  }
}

function Redact($s) {
  if (-not $s) { return $s }
  foreach ($t in @($env:FLY_API_TOKEN, $env:TELEGRAM_BOT_TOKEN, $env:GITHUB_TOKEN)) {
    if ($t -and $t.Length -gt 6) { $s = $s -replace [regex]::Escape($t), '***' }
  }
  return $s
}

# flyctl ni xavfsiz chaqirish: stderr ni yig'maydi, xatoni toza chiqaradi.
function Invoke-Fly([string[]]$FlyArgs) {
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $out = & $fly @FlyArgs 2>&1 | Out-String
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prev
  return [pscustomobject]@{ Out = (Redact $out); Code = $code }
}

# ---------- 1) flyctl bormi? ----------
$fly = Get-Command flyctl -ErrorAction SilentlyContinue
if (-not $fly) {
  $binDir = Join-Path $env:USERPROFILE '.fly\bin'
  $guess = Join-Path $binDir 'flyctl.exe'
  if (Test-Path $guess) {
    if ($env:PATH -notlike "*$binDir*") { $env:PATH = "$binDir;$env:PATH" }
    $fly = $guess
  } else {
    $localGuess = Join-Path $env:USERPROFILE 'bin\flyctl.exe'
    if (Test-Path $localGuess) { $fly = $localGuess } else {
      Write-Host "XATO: flyctl topilmadi." -ForegroundColor Red
      Write-Host "O'rnatish:  powershell -NoProfile -ExecutionPolicy Bypass -File $Dir\install-fly.ps1 -Yes" -ForegroundColor Yellow
      Write-Host "Yoki: winget install flyctl   /   iwr -useb https://fly.io/install.ps1 | iex" -ForegroundColor DarkGray
      exit 1
    }
  }
}
if (-not $env:FLY_API_TOKEN) {
  Write-Host 'XATO: FLY_API_TOKEN topilmadi (.env ga qosh: https://fly.io/docs/guides/environments-variables/)' -ForegroundColor Red
  exit 1
}
if (-not $Yes) { $env:FLY_NO_UPDATE_CHECK = '1' }

# ---------- 2) Loyiha papkasini tekshirish ----------
$ProjectDir = if (Test-Path $Path) { (Resolve-Path $Path).Path } else { $null }
if (-not $ProjectDir) { throw "XATO: papka topilmadi -> $Path" }

$Toml = Join-Path $ProjectDir 'fly.toml'
$Dockerfile = Join-Path $ProjectDir 'Dockerfile'

# ---------- 3) Loyiha hajmi (node_modules/.git/.venv siz) ----------
$files = Get-ChildItem -Path $ProjectDir -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\(node_modules|\.git|\.venv|venv|__pycache__|\.next|dist|build|target|site-packages|\.cache|\.fly)\\' } |
  Where-Object { $_.Extension -notin @('.png', '.jpg', '.jpeg', '.gif', '.ico', '.zip', '.pdf', '.mp4', '.woff', '.woff2') }
$sizeMb = [math]::Round((($files | Measure-Object -Property Length -Sum).Sum / 1MB), 1)
if ($null -eq $sizeMb) { $sizeMb = 0 }
$heavyFiles = $files | Where-Object { $_.Length -gt 25MB } | Sort-Object Length -Descending | Select-Object -First 8
$heavyMb = [math]::Round((($files | Where-Object { $_.Length -gt 25MB } | Measure-Object Length -Sum).Sum / 1MB), 1)
$totalMb = [math]::Round((($files | Measure-Object -Property Length -Sum).Sum / 1MB), 1)

# ---------- 4) Profil tanlash (loyiha hajmiga qarab) ----------
$detected = @()
foreach ($e in @('package.json', 'requirements.txt', 'pyproject.toml', 'go.mod', 'Cargo.toml', 'Gemfile', 'composer.json', 'Dockerfile')) {
  if (Test-Path (Join-Path $ProjectDir $e)) { $detected += $e }
}

if ($Profile -eq 'auto') {
  if ($totalMb -ge 200 -or $heavy.Count -gt 0)      { $Profile = 'large' }
  elseif ($totalMb -ge 20)                          { $Profile = 'medium' }
  elseif ($totalMb -ge 2)                           { $Profile = 'small' }
  else                                             { $Profile = 'tiny' }
}
if ($detected -contains 'requirements.txt' -and $Profile -eq 'tiny') { $Profile = 'small' }

$matrix = @{
  tiny   = @{ cpu = 'shared-cpu-1x';   mem = '256m'; vm = 'shared-cpu-1x' }
  small  = @{ cpu = 'shared-cpu-1x';   mem = '512m'; vm = 'shared-cpu-1x' }
  medium = @{ cpu = 'shared-cpu-2x';   mem = '1g';   vm = 'shared-cpu-2x' }
  large  = @{ cpu = 'performance-1x'; mem = '2g';   vm = 'performance-1x' }
}
$p = $matrix[$Profile]
$ResCpu = if ($Cpu) { $Cpu } else { $p.cpu }
$ResMem = if ($MemoryMb) { "${MemoryMb}m" } else { $p.mem }
$ResVm  = if ($VmSize) { $VmSize } else { $p.vm }

# "256m" / "1g" / "2gb" -> MB butun son
function Convert-ToMb([string]$v) {
  $n = [double](($v -replace '[^0-9.]', ''))
  if ($v -match '(?i)g') { $n = $n * 1024 }
  [int][math]::Round($n)
}
$MemMb = Convert-ToMb $ResMem

$KIND = if ($ResCpu -like 'performance*') { 'performance' } else { 'shared' }
$NCpu = 1
if ($ResCpu -match '-(\d+)x$') { $NCpu = [int]$Matches[1] }

$MinMachines = $MinMachinesRunning
$AutoStop = if ($NoAutoSuspend) { 'off' } else { $AutoStopMachines }
if ($NoAutoSuspend -and $MinMachines -lt 1) { $MinMachines = 1 }

# ---------- 5) Mavjud app'lar (hech qachon o'zi tanlamaydi) ----------
$existing = @()
try {
  $r = Invoke-Fly @('apps', 'list', '--json')
  if ($r.Code -eq 0 -and $r.Out.Trim()) {
    $existing = @($r.Out | ConvertFrom-Json | ForEach-Object { $_.Name })
  }
} catch { }

if (-not $App) {
  Write-Host '================================================================' -ForegroundColor DarkGray
  Write-Host ' APP NOMI BERILMADI — hech narsa o`zgartirilmadi.' -ForegroundColor Yellow
  Write-Host '================================================================' -ForegroundColor DarkGray
  Write-Host "Papka: $ProjectDir" -ForegroundColor Cyan
  if ($existing.Count) {
    Write-Host 'Mavjud fly app`lar:' -ForegroundColor Cyan
    foreach ($a in $existing) { Write-Host "  - $a" -ForegroundColor White }
  } else {
    Write-Host 'Mavjud app topilmadi (yoki fly list`ga kirish muvaffaqiyatsiz).' -ForegroundColor DarkGray
  }
  Write-Host ''
  Write-Host "Reja (auto-sizing, loyiha $totalMb MB):" -ForegroundColor Cyan
  Write-Host "  profile : $Profile"
  Write-Host "  cpu/mem : $ResCpu / $ResMem"
  Write-Host "  vm size : $ResVm"
  Write-Host "  suspend : auto_stop=$AutoStop, min_machines_running=$MinMachines"
  if ($heavyFiles -and $heavyFiles.Count -gt 0) {
    Write-Host ''
    Write-Host "  OGOHLANTIRISH: $heavyMb MB og'ir fayllar bor — .dockerignore ni tekshiring." -ForegroundColor Yellow
  }
  Write-Host ''
  Write-Host 'Qayta ishga tushiring:' -ForegroundColor Green
  Write-Host '  -App <nom>            # mavjud appni yangilash'
  Write-Host '  -App <nom> -New        # yangi app yaratish'
  Write-Host '  -Path <boshqa-papka>   # boshqa loyiha'
  exit 0
}

# ---------- 6) fly.toml / Dockerfile bormi ----------
if (-not (Test-Path $Toml) -and -not (Test-Path $Dockerfile)) {
  Write-Host "XATO: $ProjectDir da fly.toml ham, Dockerfile ham yo'q." -ForegroundColor Red
  Write-Host 'Fly deploy uchun Dockerfile yoki fly.toml kerak. Skript hech narsani yaratmaydi.' -ForegroundColor Yellow
  exit 1
}

# ---------- 7) Rejani chiqarish (tasdiq kutamiz) ----------
$isNew = $New -or ($existing -notcontains $App)
Write-Host '================= FLY DEPLOY REJASI =================' -ForegroundColor Cyan
Write-Host "Papka       : $ProjectDir"
Write-Host "Loyiha hajmi: $totalMb MB (kod+assets, node_modules/.git siz)"
Write-Host "Stack       : $($detected -join ', ')"
Write-Host "App         : $App$(if ($isNew) { '  (YANGI yaratiladi)' } else { '  (mavjud, yangilanadi)' })"
Write-Host "Profile     : $Profile"
Write-Host "CPU / RAM   : $ResCpu / $ResMem"
Write-Host "VM size     : $ResVm"
Write-Host "Auto-suspend: auto_stop_machines = `"$AutoStop`""
Write-Host "Min machines: $MinMachines  (0 = to`liq avto-suspend, pul tejash)"
if ($Region) { Write-Host "Region      : $Region" }
if ($heavyFiles -and $heavyFiles.Count -gt 0) {
  Write-Host ''
  Write-Host "OGOHLANTIRISH: $heavyMb MB og'ir fayllar topildi ($($heavyFiles.Count)+ ta, 25 MB dan katta)." -ForegroundColor Yellow
  $heavyFiles | ForEach-Object {
    Write-Host ("  - {0}  ({1} MB)" -f $_.FullName.Substring($ProjectDir.Length + 1), [math]::Round($_.Length / 1MB)) -ForegroundColor DarkYellow
  }
  Write-Host '  Ular image''ga sig''masligi mumkin. Fly''da uchta variant bor:' -ForegroundColor Yellow
  Write-Host '   a) model/data ni .dockerignore ga qo''shib build dan chiqarib tashlang (tavsiya etiladi)' -ForegroundColor DarkGray
  Write-Host '   b) 2 GB dan kattasini fly volumes bilan mount qiling' -ForegroundColor DarkGray
  Write-Host '   c) -Profile ni boshqacha bering' -ForegroundColor DarkGray
}
Write-Host '=====================================================' -ForegroundColor Cyan

if ($DryRun)  { Write-Host '[dry-run] hech narsa o`zgartirilmadi' -ForegroundColor DarkGray; exit 0 }
if (-not $Yes) {
  Write-Host 'Bu reja HECH BIR narsani o`zgartirmadi (tasdiq kutilmoqda).' -ForegroundColor Yellow
  Write-Host 'Tasdiqlash uchun -Yes qo`shing:' -ForegroundColor Green
  Write-Host "  .\deploy-fly.ps1 -Path `"$Path`" -App $App -Yes$(if ($isNew) { ' -New' })"
  exit 0
}

# ---------- 8) fly.toml'ni tayyorlash ----------
if (Test-Path $Toml) { Copy-Item $Toml "$Toml.bak" -Force }
else {
  $appEsc = $App
  $primary = if ($Region) { $Region } else { 'mad' }
  $vmLine = if ($ResVm) { "`"$ResVm`"" } else { '' }
  # BOM'siz yozamiz — flyctl BOM'li TOML'ni o'qi olmaydi
  $tomlText = @"
app = '$appEsc'
primary_region = '$primary'

[build]

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = '$AutoStop'
  auto_start_machines = true
  min_machines_running = $MinMachines
  processes = ['app']

  [http_service.concurrency]
    type = 'requests'
    soft_limit = 200
    hard_limit = 250

[[vm]]
  size = $vmLine
  cpu_kind = '$KIND'
  cpus = $NCpu
  memory_mb = $MemMb
"@
  [System.IO.File]::WriteAllText($Toml, $tomlText, (New-Object System.Text.UTF8Encoding $false))
  Write-Host "fly.toml yaratildi" -ForegroundColor Green
}

# auto-suspend qiymatlarini har doim qo'llaymiz (pul tejash uchun)
$content = Get-Content $Toml -Raw
if ($NoAutoSuspend) {
  $content = $content -replace '(?m)^\s*auto_stop_machines\s*=.*$', "auto_stop_machines = 'off'"
  $content = $content -replace '(?m)^\s*min_machines_running\s*=.*$', 'min_machines_running = 1'
} else {
  if ($content -notmatch '(?m)^\s*auto_stop_machines\s*=') {
    $content = $content -replace '(?m)^(\s*force_https\s*=\s*.*)$', "`$1`n  auto_stop_machines = '$AutoStop'`n  auto_start_machines = true`n  min_machines_running = $MinMachines"
  } else {
    $content = $content -replace '(?m)^(\s*auto_stop_machines\s*=).*$', "`$1 '$AutoStop'"
  }
  if ($content -notmatch '(?m)^\s*min_machines_running\s*=') {
    $content = $content -replace '(?m)^(\s*auto_start_machines\s*=.*)$', "`$1`n  min_machines_running = $MinMachines"
  } else {
    $content = $content -replace '(?m)^(\s*min_machines_running\s*=).*$', "`$1 $MinMachines"
  }
}
# vm resurslari
if ($content -match '(?ms)^\[\[vm\]\].*$') {
  $vmBlock = $content.Substring($content.IndexOf('[[vm]]'))
  $newVm = $vmBlock `
    -replace '(?m)^(\s*size\s*=).*$', "`$1 `"$ResVm`"" `
    -replace '(?m)^(\s*cpu_kind\s*=).*$', "`$1 '$KIND'" `
    -replace '(?m)^(\s*cpus\s*=).*$', "`$1 $NCpu" `
    -replace '(?m)^(\s*memory_mb\s*=).*$', "`$1 $MemMb"
  $content = $content.Substring(0, $content.IndexOf('[[vm]]')) + $newVm
} else {
  $content = $content.TrimEnd() + @"

[[vm]]
  size = `"$ResVm`"
  cpu_kind = '$KIND'
  cpus = $NCpu
  memory_mb = $MemMb
"@
}
Set-Content -Path $Toml -Value $content -Encoding UTF8 -NoNewline
# BOM'siz — flyctl BOM'li TOML'ni o'qi olmaydi
[System.IO.File]::WriteAllText($Toml, $content, (New-Object System.Text.UTF8Encoding $false))
Write-Host "fly.toml yangilandi: $ResCpu / $ResMem, auto_stop=$AutoStop, min_machines_running=$MinMachines" -ForegroundColor Green

# ---------- 9) App yaratish (faqat -New bilan, foydalanuvchi tasdig'i bilan) ----------
if ($isNew) {
  if (-not $New -and $existing.Count -gt 0) {
    Write-Host "XATO: '$App' apps list`da yo'q. Yangi app yaratish uchun -New qo'shing." -ForegroundColor Red
    exit 1
  }
  Write-Host "App yaratilmoqda: $App" -ForegroundColor Cyan
  $r = Invoke-Fly @('apps', 'create', $App)
  Write-Host $r.Out
  if ($r.Code -ne 0) {
    Write-Host '' -ForegroundColor Red
    if ($r.Out -match 'Unauthorized|401') {
      Write-Host 'XATO: fly token yaroqli emas yoki muddati tugagan.' -ForegroundColor Red
      Write-Host '.env dagi FLY_API_TOKEN ni yangilang: https://fly.io/dashboard/ -> Access Tokens' -ForegroundColor Yellow
    } else {
      Write-Host 'XATO: app yaratilmadi. Yuoridagi xabarni o`qib, foydalanuvchiga yetkazing.' -ForegroundColor Red
    }
    Write-Host 'Hech narsa o`zgartirilmadi (fly.toml .bak nusxasi saqlangan).' -ForegroundColor DarkGray
    exit 1
  }
}

# ---------- 10) Deploy ----------
if ($BuildOnly) {
  $r = Invoke-Fly @('build')
  Write-Host $r.Out
  if ($r.Code -ne 0) { Write-Host 'XATO: build muvaffaqiyatsiz.' -ForegroundColor Red; exit 1 }
  Write-Host 'Build tugadi (deploy qilinmadi).' -ForegroundColor Green
  exit 0
}

Write-Host 'Deploy boshlandi...' -ForegroundColor Cyan
$r = Invoke-Fly @('deploy', '--strategy', 'rolling', '--now', '-y')
Write-Host $r.Out
if ($r.Code -ne 0) {
  Write-Host 'XATO: deploy muvaffaqiyatsiz.' -ForegroundColor Red
  if ($r.Out -match 'unauthorized|401') { Write-Host 'FLY_API_TOKEN yaroqli emas.' -ForegroundColor Yellow }
  exit 1
}

$st = Invoke-Fly @('status', '--json')
$HostName = "$App.fly.dev"
if ($st.Code -eq 0 -and $st.Out -match '"Hostname"\s*:\s*"([^"]+)"') { $HostName = $Matches[1] }

Write-Host ''
Write-Host '====================================================' -ForegroundColor Green
Write-Host "OK -> https://$HostName" -ForegroundColor Green
Write-Host "Mashina: $ResCpu / $ResMem  |  auto_stop=$AutoStop  |  min_machines_running=$MinMachines" -ForegroundColor Green
Write-Host 'Avto-suspend: trafik tugasa mashina o`chadi -> oylik to`lanish kamayadi.' -ForegroundColor DarkGray
Write-Host '====================================================' -ForegroundColor Green
Write-Host "Keyingi qadam: .\publish.ps1 -Path `"$Path`" -Repo $App -Desc `"<tavsif>`" -Demo https://$HostName"
