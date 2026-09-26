# OpenCode publish skill

Har yangi loyiha -> GitHub'ga push -> Telegram kanalga o'zbekcha post.

## Fayllar
- `publish.ps1` — to'liq avtomat: repo yaratish + push + telegram post (Windows)
- `send-telegram.ps1` — faqat telegram post (Windows)
- `publish.sh` — to'liq avtomat (Git Bash / WSL / Termux)
- `send-telegram.sh` — faqat telegram post (Git Bash / WSL / Termux)
- `deploy-fly.ps1` / `deploy-fly.sh` — fly.io'ga xavfsiz deploy
- `install-fly.ps1` — flyctl o'rnatish (bir marta)
- `FLY_DEPLOY.md` — fly deploy qoidalari (avto-sizing, avto-suspend, tasdiq)
- `.env` — MAXFIY tokenlar (git'ga chiqmaydi, `.gitignore` da)
- `.env.example` — namuna

> `.ps1` fayllar UTF-8 BOM bilan saqlangan (Windows PowerShell 5.1 o'zbekcha
> harflarni to'g'ri o'qisin deb). Tokentlar hech qachon ekranga chiqarilmaydi.

## Windows'da ishlatish
```powershell
# To'liq (avval -DryRun bilan sinab ko'ring):
powershell -NoProfile -ExecutionPolicy Bypass -File .\publish.ps1 `
  -Path D:\AI\my-app -Repo my-app -Desc "AI yordamchi" -Demo https://my-app.fly.dev

# Faqat telegram:
powershell -NoProfile -ExecutionPolicy Bypass -File .\send-telegram.ps1 "Salom!" -Channel @my_channel
```

Parametrlar: `-Repo` (repo nomi), `-Desc` (tavsif), `-Demo` (demo URL),
`-Private`, `-SkipTelegram` (faqat GitHub), `-DryRun` (hech narsani yubormaydi).

## fly.io deploy

Loyihani fly.io'ga joylashtirish uchun (avval o'rnatish):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install-fly.ps1
```

`flyctl` o'rnatiladi, keyin https://fly.io/dashboard/ dan token olib
`.env` ga `FLY_API_TOKEN=` deb yozasiz.

Ikki bosqichli — avval reja, keyin tasdiq:

```powershell
# 1) reja: CPU/RAM/suspend hisoblanadi, hech narsa o'zgartirilmaydi
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy-fly.ps1 `
  -Path D:\AI\my-app -App my-app

# 2) tasdiqlagandan keyin
powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy-fly.ps1 `
  -Path D:\AI\my-app -App my-app -Yes
```

**Xavfsizlik qoidalari:**

- `-App` berilmasa skript to'xtaydi va mavjud app'lar ro'yxatini ko'rsatadi —
  agent o'zi app tanlamaydi, sizdan so'raydi.
- `-Yes` berilmasa hech bir app o'zgartirilmaydi.
- Faqat siz nomlagan app'ga tegiladi. Boshqa app'larga, sekretlarga va
  `fly destroy`/`fly secrets set`/`fly scale` ga agent o'zi qo'l
  urmaydi.
- `FLY_API_TOKEN` hech qachon ekranga chiqarilmaydi.

**Avtomat resurs (loyiha hajmiga qarab):**

| Hajm | CPU / RAM | Auto-suspend |
| --- | --- | --- |
| < 2 MB | shared-cpu-1x / 256 MB | `suspend`, `min_machines_running = 0` |
| 2–20 MB | shared-cpu-1x / 512 MB | `suspend`, `min_machines_running = 0` |
| 20–200 MB | shared-cpu-2x / 1 GB | `suspend`, `min_machines_running = 0` |
| ≥ 200 MB | performance-1x / 2 GB | `suspend`, `min_machines_running = 0` |

Avto-suspend har doim yoqiladi: trafik tugasa mashina o'chadi, so'rov
kelganda o'z-o'zidan ishga tushadi — bo'sh holatda to'lov chiqmaydi.
`-MinMachinesRunning 1` bilan doimiy ishlatish mumkin, `-NoAutoSuspend`
bilan o'chiriladi.

Batafsil: [`FLY_DEPLOY.md`](FLY_DEPLOY.md).

## Skill sifatida agent'ga ulash (OpenCode)

Skill `SKILL.md` faylidan iborat. OpenCode uni avtomatik topadi va kerak bo'lganda
o'zi yuklaydi — siz buyruq yozishingiz shart emas.

## Sozlash (1 marta)
1. Botni o'z kanalingizga **admin** qil (Post Messages huquqi bilan).
   Kanal -> Manage Channel -> Administrators -> Add -> botni qidir.
2. `.env.example` ni `.env` deb saqlab, `TELEGRAM_BOT_TOKEN` ni to'ldir
   (`@BotFather` dan), `TELEGRAM_CHANNEL` ga o'z kanalini yoz.
3. GitHub token: `GITHUB_TOKEN` ni `.env` ga yozing yoki birinchi darajadagi
   papkadagi `TOKENS.md` faylida `ghp_...` ko'rinishida qoldiring — skript
   avtomat o'qib oladi.

## Ishlatish
```bash
# To'liq:
./publish.sh -Path ~/my-app -Repo my-app -Desc "AI yordamchi"

# Faqat telegram:
./send-telegram.sh "Salom!" @my_channel
```

Agent'ga shunday aytsangiz yetarli:
"Shu loyihamni GitHub'ga yangi repo qilib tashla va kanalga post qo'y" —
agent skill'ni yuklab, avtomatik bajaradi.

Tokenlar `TOKENS.md` dan avtomatik o'qiladi, `.env` da `GITHUB_TOKEN` bo'sh
bo'lsa ham ishlaydi.

## Xavfsizlik

- `.env` hech qachon git'ga tushmasligi kerak (`.gitignore` da turadi).
- Tokenlarni chatga yozmang, commit xabariga yozmang.
- Ikkalasi ham bo'lmasa skript xato beradi va to'xtaydi.
