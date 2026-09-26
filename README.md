# ArcadiaUZ avtomatika

Har yangi loyiha -> GitHub'ga push -> @ArcadiaUZ kanalga o'zbekcha post.

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
# To'liq (avval --DryRun bilan sinab ko'ring):
powershell -NoProfile -ExecutionPolicy Bypass -File .\publish.ps1 `
  -Path D:\AI\my-app -Repo my-app -Desc "AI yordamchi" -Demo https://my-app.fly.dev

# Faqat telegram:
powershell -NoProfile -ExecutionPolicy Bypass -File .\send-telegram.ps1 "Salom ArcadiaUZ!"
```

Parametrlar: `-Repo` (repo nomi), `-Desc` (tavsif), `-Demo` (demo URL),
`-Private`, `-SkipTelegram` (faqat GitHub), `-DryRun` (hech narsani yubormaydi).

## Skill sifatida agent'ga ulash (OpenCode)

Skil `SKILL.md` faylidan iborat. OpenCode uni avtomatik topadi va kerak bo'lganda
o'zi yuklaydi — siz buyruq yozishingiz shart emas.

## Sozlash (1 marta)
1. Botni `@ArcadiaUZ` kanalga **admin** qil (Post Messages huquqi bilan).
   Kanal -> Manage Channel -> Administrators -> Add -> botni qidir.
2. `.env.example` ni `.env` deb saqlab, `TELEGRAM_BOT_TOKEN` ni to'ldir
   (`@BotFather` dan), `TELEGRAM_CHANNEL=@ArcadiaUZ` ni tekshir.
3. GitHub token: `GITHUB_TOKEN` ni `.env` ga yozing yoki `D:\AI\TOKENS.md`
   faylida `ghp_...` ko'rinishida qoldiring — skript avtomat o'qib oladi.

## Ishlatish
```bash
# To'liq:
Yani siz shu repository ni AI Agent ga tashlaysiz va shu skill ni o'zinga qo'sh deb yozasin u shu reponi yuklab oziga skill sifatida qoshadi,
va qoshilgandan keyin siz unga Github API key (upload, push kabi ruxsatlar bilan) va telegram bot token berasiz va u skill ga saqlab oladi,
keyin telegram bot ni kanalizga admin qilasiz va endi biror bir narsani github ga push qilish yoki kanalga post qoyish kerak bolsa shunchaki soraysiz
"Shu loyihamni github ga yangi repo ochib (repo-nomi) bolsin va telegram ga post qo'y shu repo haqida" deb yozasiz u avtomatik skill larni korib telegram/github ga joylaydi loyihangizni.
```

Tokenlar `../TOKENS.md` dan avtomatik o'qiladi, `.env` da `GITHUB_TOKEN` bo'sh bo'lsa ham ishlaydi.
