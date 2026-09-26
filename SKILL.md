---
name: Publish
description: Publish a project to GitHub and/or post to a Telegram channel, with an optional fly.io deploy step. Use when the user asks to publish, push, release or "noylantirish" a project ("GitHub'ga push qil", "telegramga post qil", "publish qil", "release qil", "fly.io ga deploy qil", "host qil"), or asks to send a message to their Telegram channel.
---

# Publish skill

PowerShell/bash scripts do all the work:

- `publish.ps1` / `publish.sh` — GitHub repo yaratish + push + Telegram post
- `send-telegram.ps1` / `send-telegram.sh` — faqat Telegram post
- `deploy-fly.ps1` / `deploy-fly.sh` — fly.io'ga joylashtirish (ixtiyoriy,
  avval publish'dan). To'liq qoida: **`FLY_DEPLOY.md`**
- `install-fly.ps1` — flyctl o'rnatish (bir marta)

> Loyiha fly.io'ga joylashtirilishi kerak bo'lsa (demo URL kerak, "host
> qil", "deploy qil", "onlayn qil" deb so'ralsa) — **avval `deploy-fly.*`
> ishlatiladi**, keyin `publish.*` bilan GitHub + Telegram post yuboriladi.
> `FLY_DEPLOY.md` ni o'qib tur; u aytgan qoidalar bajarilishi shart.

## Scriptlarni topish

Ushbu SKILL.md fayli bilan bir papkada (yoki `scripts/` ichida) `publish.ps1`
bo'lmasa, quyidagilardan birini ishlat:

1. `SKILL.md` ning o'z papkasi (loyiha ko'rinishi)
2. `~/skills/publish/publish.ps1` (global o'rnatilgan ko'rinish)

Ishlatiladigan skriptni `Test-Path` bilan tekshir, keyin shu to'liq yo'l bilan
chaqir. Hech qachon skriptni qayta yozma — u allaqach tekshirilgan.

## Non-negotiable rules

1. **Never print, echo, log, or commit secrets.** Tokens live in `.env`
   (gitignored) or `TOKENS.md`. Use them inline only. Never paste a `ghp_...` or
   a bot token into chat, a commit message, or a tracked file.
2. **Confirm the target before pushing.** Show the resolved project path, repo
   name, and GitHub login. If the user did not name a project, list candidate
   project directories and ask.
3. **Push before posting.** Only send the Telegram post after `git push` succeeds.
4. **Write the post in Uzbek (Latin)** and keep the house format below unless
   the user supplies their own text.
5. **Use `-DryRun` first** when anything is uncertain (new repo, unclear
   description, first use in a session), then run for real.
6. Run scripts with `powershell -NoProfile -ExecutionPolicy Bypass -File ...` —
   the machine blocks unsigned scripts by default. Do not chain with `&&`.
7. **Never touch a fly.io app without explicit confirmation.** If the user
   did not name an app, ask which one — never pick one yourself. Run
   `deploy-fly.*` once to print the plan, show it to the user, and only
   re-run with `-Yes` after they approve. Never run `fly apps create`,
   `fly destroy`, `fly secrets set`, or `fly scale` on your own initiative.
   See `FLY_DEPLOY.md`.

## Setup check (cheap, once per session)

```powershell
Test-Path <skill-dir>\.env
```

- `.env` missing -> copy `.env.example` to `.env` and ask the user for
  `TELEGRAM_BOT_TOKEN` (from @BotFather) and `TELEGRAM_CHANNEL` (their channel).
- `.env` present -> proceed. Do not read the values back to the user.
- The GitHub token resolves automatically from `.env` or `TOKENS.md`
  (`ghp_...`). If it is missing, ask the user to add `GITHUB_TOKEN` to `.env`;
  do not hunt through unrelated files.

## Full publish (repo + push + Telegram)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <script> -Path <project-dir> -Repo <repo-name> -Desc "<qisqa tavsif>" -Demo <https-url> [-Private] [-DryRun]
```

- `-Path` absolute project directory, e.g. `D:\AI\my-app`
- `-Repo` kebab-case GitHub repo name, e.g. `my-app`
- `-Desc` one line, Uzbek, no trailing period
- `-Demo` live URL if deployed; omit otherwise (post says "tez kunda")
- `-Private` only when the user asks for a private repo
- `-SkipTelegram` when the user wants GitHub only

The script prints the post text before sending — read that output back to the
user. Always dry run first, then run for real:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <script> -Path D:\AI\my-app -Repo my-app -Desc "AI yordamchi" -DryRun
powershell -NoProfile -ExecutionPolicy Bypass -File <script> -Path D:\AI\my-app -Repo my-app -Desc "AI yordamchi"
```

## Deploy to fly.io + GitHub + Telegram (to'liq oqim)

Avval `FLY_DEPLOY.md` ni o'qib tur. Qisqasi:

```powershell
# 1) reja (hech narsani o'zgartirmaydi)
powershell -NoProfile -ExecutionPolicy Bypass -File <deploy-script> -Path <project-dir> -App <fly-app>

# 2) foydalanuvchi tasdiqlagandan keyin
powershell -NoProfile -ExecutionPolicy Bypass -File <deploy-script> -Path <project-dir> -App <fly-app> -Yes

# 3) GitHub + Telegram
powershell -NoProfile -ExecutionPolicy Bypass -File <script> -Path <project-dir> -Repo <repo> -Desc "<tavsif>" -Demo https://<fly-app>.fly.dev
```

- `-App` **berilmasa** skript to'xtaydi va mavjud app'lar ro'yxatini
  chiqaradi — foydalanuvchidan qaysi app ekanini **so'rang**, o'zi
  tanlamang.
- `-Yes` **berilmasa** skript faqat reja ko'rsatadi, hech narsani
  o'zgartirmaydi.
- Loyiha hajmiga qarab CPU/RAM avtomat tanlanadi va **avto-suspend**
  (`auto_stop_machines = 'suspend'`, `min_machines_running = 0`) doim
  qo'llanadi — bo'sh holatda to'lov chiqmaydi.
- `.env` ga `FLY_API_TOKEN` qo'shilishi kerak. Hech qachon ekranga
  chiqarilmaydi.

## Telegram only

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <send-script> "<xabar matni>" -Channel @my_channel
```

Show the final message to the user before sending when they did not dictate the
exact wording.

## Post format

```
🚀 Yangi loyiha — <repo>

📝 <description>

🔗 GitHub: https://github.com/<login>/<repo>
🌐 Demo: <url | tez kunda>

#AI #loyiha #github #automation
```

## Troubleshooting

| Symptom | Action |
| --- | --- |
| `GITHUB_TOKEN topilmadi` | Add `GITHUB_TOKEN` to `.env`. |
| repo creation warning with 422 / "already exists" | Repo exists; push continues. |
| `git push` fails | Read the printed error. Auth failure means the token lacks the `repo` scope — report it, do not retry blindly. |
| `Telegram XATO: ... admin` | The bot must be an admin of the channel with Post Messages. Report and stop. |
| `OGOH: TELEGRAM_BOT_TOKEN yo'q` | GitHub push succeeded; ask the user for the bot token to finish the post. |
| `OGOH: TELEGRAM_CHANNEL yo'q` | Ask the user which channel to post to. |
| Token visible in `git remote -v` | The script resets the remote to the token-free URL after pushing; verify with `git -C <dir> remote -v`. |

`README.md` va bash skriptlar (`publish.sh`, `send-telegram.sh`, Git Bash / WSL /
Termux uchun) shu oqimni hujjatlashtiradi.
