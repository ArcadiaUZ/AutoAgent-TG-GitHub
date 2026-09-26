# Fly.io deploy skill (ilova)

`deploy-fly.ps1` / `deploy-fly.sh` — loyihani fly.io'ga joylashtiradi.
Bu o'z navbatida **`publish` skill'ning ichki qismi**: avval fly, keyin
GitHub + Telegram.

---

## 0. Eng muhim qoida — TASDIQ

> **Agent hech qachon o'z holicha hech bir app'ni ochmaydi, yaratmaydi,
> yangilamaydi, o'chirmaydi, sekret qo'ymaydi yoki resursini o'zgartirmaydi.**

Aniq qoidalar:

1. **`-App` berilmasa skript `exit 0` bilan to'xtaydi** va mavjud app'lar
   ro'yxatini chiqaradi. Agent **o'zi nom tanlamaydi** — foydalanuvchidan
   so'raydi. Bir nechta app bo'lsa, qaysi biri ekanini aniqlashtiradi.
2. **`-Yes` (PowerShell) / `-Yes` (bash) berilmaganda skript hech narsani
   o'zgartirmaydi** — faqat reja (CPU/RAM/suspend/region) chiqaradi va
   tasdiq kutadi.
3. **Foydalanuvchi tasdiqlagan app'dan boshqa app'ga tegilmaydi.**
   "Barchasini yangila" deyishmagan bo'lsa — bitta app bilan cheklangan.
4. **`fly apps create` faqat `-New` bilan** va foydalanuvchi aniq "yangi app
   yarat" degan bo'lsa. Aks holda mavjud bo'lmagan nom bilan xato beradi va
   to'xtaydi.
5. **`fly destroy`, `fly secrets set`, `fly scale`, `fly volumes`**
   bu skill orqali **ishga tushirilmaydi**. Kerak bo'lsa — foydalanuvchi
   alohida tasdiqlashi kerak, agent oldindan aniq tushuntiradi.
6. **`.env` dagi `FLY_API_TOKEN` hech qachon ekranga chiqarilmaydi,
   log'ga yozilmaydi, commitga tushmaydi.** Skript barcha chiqishlarni
   `Redact` orqali tozalaydi.

---

## 1. Loyiha hajmiga qarab resurs (auto-sizing)

Skript `node_modules`, `.git`, `.venv`, `dist`, `build`, `__pycache__`,
`.next`, `target`, `site-packages`, `.fly` ni **hisobga olmaydi** va
qolgan hajmni `bc`/PowerShell bilan MB'ga o'giradi.

| Loyiha hajmi | `Profile` | CPU | RAM | VM size | Qachon |
| --- | --- | --- | --- | --- | --- |
| < 2 MB | `tiny` | `shared-cpu-1x` | 256 MB | `shared-cpu-1x` | statik sayt, kichik bot, API stub |
| 2–20 MB | `small` | `shared-cpu-1x` | 512 MB | `shared-cpu-1x` | oddiy web app, telegram bot |
| 20–200 MB | `medium` | `shared-cpu-2x` | 1 GB | `shared-cpu-2x` | to'plamlar (node_modules, wagay) |
| ≥ 200 MB yoki 1 ta fayl > 25 MB | `large` | `performance-1x` | 2 GB | `performance-1x` | ML model, og'ir image/audio pipeline |

Qo'shimcha qoida: `requirements.txt` topilsa `tiny` avtomat `small` ga
ko'tariladi (Python runtime 256 MB da siqiladi).

Qo'lda berish mumkin: `-Profile tiny|small|medium|large` yoki
`-Cpu` / `-MemoryMb` / `-VmSize` bilan aniq.

---

## 2. Avto-suspend (pul tejash)

Har bir deploy'da avtomat qo'llanadi, `-NoAutoSuspend` berilmasa:

```toml
[http_service]
  auto_stop_machines = 'suspend'   # trafik tugasa mashina to'xtaydi
  auto_start_machines = true        # so'rov kelganda o'z-o'zidan ishga tushadi
  min_machines_running = 0          # doimiy ishlaydigan mashina yo'q
```

- `suspend` — xotira saqlanadi, qayta ishga tushish ~1 soniya. Loyihalar
  uchun eng arzon variant. Default shu.
- `stop` — to'liq o'chirish, biroz sekinroq qayta ishga tushadi.
- `min_machines_running = 0` — bo'sh holatda **hich narsa to'lanmaydi**,
  faqat object storage. Shu bilan oylik hisob bir necha barobar kamayadi.
- `-MinMachinesRunning 1` — doimiy ishlab turish (tez javob kerak bo'lsa),
  lekin har oy to'lanadi.
- `-NoAutoSuspend` — avto-suspend'ni o'chiradi. Faqat foydalanuvchi so'rasa.

Eski `fly.toml` bo'lsa skript `.bak` nusxasini oladi va `[[vm]]` hamda
`[http_service]` bloklarini yangilaydi — mavjud sozlamalarni buzmaydi.

---

## 3. Ishlatish

### 1-bosqich: reja (hech narsani o'zgartirmaydi)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <script> -Path D:\AI\my-app -App my-app
```

```bash
./deploy-fly.sh -Path ~/my-app -App my-app
```

### 2-bosqich: tasdiqlash

Reja chog'ini foydalanuvchiga ko'rsating. U tasdiqlasa:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File <script> -Path D:\AI\my-app -App my-app -Yes
```

### Yangi app

```powershell
... -Path D:\AI\my-app -App my-app -New -Yes
```

### Boshqa variantlar

| Flag | Vazifasi |
| --- | --- |
| `-Region fra\|ord\|ams\|iad` | joylashuvni majburlash |
| `-Profile medium` | qo'lda profil |
| `-Cpu performance-1x -MemoryMb 4096` | aniq resurs |
| `-MinMachinesRunning 1` | doimiy ishlatish (pul to'lanadi) |
| `-NoAutoSuspend` | avto-suspend'ni o'chirish |
| `-BuildOnly` | faqat build, deploy qilinmaydi |
| `-DryRun` | faqat reja |

### App nomi berilmasa

```powershell
... -Path D:\AI\my-app          # -App yo'q
```

Chiqadi: papka, hajm, stack, avtomat profil, va mavjud app'lar ro'yxati.
Keyin **foydalanuvchiga savol beriladi**: "Qaysi app'ni yangilamiz?"

---

## 4. Sozlash (1 marta)

1. `flyctl` yo'q bo'lsa:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File <script-dir>\install-fly.ps1
   ```
   (Keyin `-Yes` bilan o'rnatish, yoki `winget install flyctl`.)
2. https://fly.io/dashboard/ -> **Access Tokens** -> token yarating.
3. `.env` ga qo'shing (hech qachon commit qilmaydi):
   ```
   FLY_API_TOKEN=<token>
   ```
4. `fly auth login` (ixtiyoriy — `.env` tokeni bilan ham ishlaydi).

`fly.toml` yoki `Dockerfile` ikkalasi ham yo'q bo'lsa skript **xato beradi
va to'xtaydi** — hech qanday fayl yaratmaydi.

---

## 5. Deploy'dan keyin: GitHub + Telegram

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File publish.ps1 `
  -Path D:\AI\my-app -Repo my-app -Desc "AI yordamchi" -Demo https://my-app.fly.dev
```

---

## 6. Xatolar

| Belgi | Yechim |
| --- | --- |
| `flyctl topilmadi` | `install-fly.ps1 -Yes` yoki `winget install flyctl` |
| `FLY_API_TOKEN topilmadi` | `.env` ga token qo'shing |
| `XATO: '$App' apps list'da yo'q` | nomni tekshiring yoki `-New` bilan yangi app yarating |
| `fly.toml ham, Dockerfile ham yo'q` | loyihaga Dockerfile yoki fly.toml qo'shing (skript yaratmaydi) |
| `OOM / Machine did not become ready` | `-Profile`ni bittaga ko'taring (masalan `medium`) |
| `Error: insufficient funds` | eski app'ni `fly apps destroy` bilan o'chiring — bu agent'ga aytiladi, agent o'zi yo'q qilmaydi |
| `verify: no such host` | `fly status` bilan app holatini tekshiring |
| Token ekranda ko'rinib qoldi | `.env` ni `git status` da tekshiring; hech qachon `-Yes` logini to'liq yuklamang |

---

## 7. Xulosa

```
loyiha hajmi  ->  avtomat profil (CPU/RAM/vm size)
har doim     ->  auto_stop_machines = 'suspend' + min_machines_running = 0
-App yo'q     ->  to'xtaydi, ro'yxatni ko'rsatadi, SO'RAYDI
-Yes yo'q     ->  faqat reja, hech narsa o'zgartirmaydi
boshqa app    ->  tegilmaydi
```
