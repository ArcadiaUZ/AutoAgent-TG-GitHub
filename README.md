# OpenCode publish skill

Har yangi loyiha -> GitHub'ga push -> Telegram kanalga o'zbekcha post.

## Fayllar
- `publish.ps1` — to'liq avtomat: repo yaratish + push + telegram post (Windows)
- `send-telegram.ps1` — faqat telegram post (Windows)
- `publish.sh` — to'liq avtomat (Git Bash / WSL / Termux)
- `send-telegram.sh` — faqat telegram post (Git Bash / WSL / Termux)
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
