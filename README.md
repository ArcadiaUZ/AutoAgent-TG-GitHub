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

**1) Global (barcha loyihalarda ishlaydi):**
```
%USERPROFILE%\.config\opencode\skills\publish\SKILL.md
```

**2) Loyihaga xos:**
```
<loyiha>\.opencode\skills\publish\SKILL.md
```

**3) Tayyor faylni nusxalash:**
```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.config\opencode\skills\publish"
Copy-Item .\SKILL.md "$env:USERPROFILE\.config\opencode\skills\publish\SKILL.md"
```

**4) Boshqa joydagi skill katalogini ulash** — `opencode.json` ga qo'shing:
```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "skills": ["D:/AI/automation"]
}
```
Bu holda `D:\AI\automation\SKILL.md` fayli `SKILL` ID si bilan yuklanadi.

**5) Tekshirish:** agent ishga tushgandan keyun `publish` skill ro'yxatda
ko'rinishi kerak. Uni qo'lda yuklash uchun: `skill` -> `id: publish`.
Skill nomi va tavsifi `SKILL.md` dagi `frontmatter` da:

```markdown
---
name: Publish
description: Loyihani GitHub'ga push qilish va @ArcadiaUZ kanaliga post yuborish
---
```

Skill ID fayl yo'lidan kelib chiqadi (`skills/publish/SKILL.md` -> `publish`),
`name` esa faqat ko'rsatish uchun.

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
bash publish.sh <papka> <repo-nomi> "tavsif" [--demo https://...] [--dry-run]

# Misollar:
bash publish.sh ../robot-face robot-face "Robot yuz — jonli AI yordamchi"
bash publish.sh ../LuminaMedia lumina-media "Media platforma" --demo https://lumina-media.fly.dev

# Faqat telegram:
bash send-telegram.sh "Salom ArcadiaUZ!"
```

Tokenlar `../TOKENS.md` dan avtomatik o'qiladi, `.env` da `GITHUB_TOKEN` bo'sh bo'lsa ham ishlaydi.
