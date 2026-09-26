#!/bin/bash
# To'liq avtomat: GitHub repo yaratish + push + Telegram post
# Ishlatish:
#   ./publish.sh <loyiha-papkasi> <repo-nomi> "qisqa tavsif" [--private] [--demo https://...] [--dry-run]
# Misol:
#   ./publish.sh ../my-app my-app "AI yordamchi" --demo https://my-app.fly.dev
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f "$DIR/.env" ]; then set -a; source "$DIR/.env"; set +a; fi

PROJECT_DIR="${1:-}"
REPO_NAME="${2:-}"
DESC="${3:-Yangi loyiha}"
PRIVATE="false"
DEMO_URL=""
DRY_RUN="false"
for a in "$@"; do
  case "$a" in
    --private) PRIVATE="true" ;;
    --demo) ;;
    --dry-run) DRY_RUN="true" ;;
  esac
  if [[ "$a" == https://* || "$a" == http://* ]]; then DEMO_URL="$a"; fi
done

if [ -z "$PROJECT_DIR" ] || [ -z "$REPO_NAME" ]; then
  echo "Ishlatish: ./publish.sh <papka> <repo-nomi> \"tavsif\" [--private] [--demo URL] [--dry-run]"
  exit 1
fi

# 1) GitHub token: .env > ../TOKENS.md > ~/TOKENS.md
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
if [ -z "$GITHUB_TOKEN" ]; then
  for f in "$DIR/../TOKENS.md" "$DIR/../../Download/TOKENS.md" "$HOME/TOKENS.md"; do
    if [ -f "$f" ]; then
      T=$(grep -oE 'ghp_[A-Za-z0-9]+' "$f" | head -1 || true)
      if [ -n "$T" ]; then GITHUB_TOKEN="$T"; break; fi
    fi
  done
fi
if [ -z "$GITHUB_TOKEN" ]; then echo "XATO: GITHUB_TOKEN topilmadi"; exit 1; fi

GITHUB_USER="${GITHUB_USER:-}"

# 2) GitHub username ni aniqlash (token egasi)
USER_JSON=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" https://api.github.com/user)
LOGIN=$(echo "$USER_JSON" | grep -oE '"login": *"[^"]+"' | head -1 | cut -d'"' -f4 || true)
if [ -z "$LOGIN" ]; then echo "XATO: GitHub token ishlamadi: $USER_JSON"; exit 1; fi
echo "GitHub user: $LOGIN (so'ralgan: $GITHUB_USER)"

# 3) Repo yaratish (bor bo'lsa davom etamiz)
REPO_URL="https://github.com/$LOGIN/$REPO_NAME"
if [ "$DRY_RUN" == "true" ]; then
  echo "[dry-run] repo yaratish o'tkazib yuborildi -> $REPO_URL"
else
CREATE_JSON=$(curl -s -X POST -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
  https://api.github.com/user/repos \
  -d "{\"name\":\"$REPO_NAME\",\"description\":\"$DESC\",\"private\":$PRIVATE,\"auto_init\":false}")
if echo "$CREATE_JSON" | grep -q '"full_name"'; then
  echo "Repo yaratildi: $(echo "$CREATE_JSON" | grep -oE '\"full_name\": *\"[^\"]+\"' | head -1)"
elif echo "$CREATE_JSON" | grep -qi 'already exists\|name already taken'; then
  echo "Repo avvaldan bor — push davom etadi."
else
  echo "OGOHLANTIRISH (repo yaratish): $CREATE_JSON"
fi
fi

# 4) Git push
if [ ! -d "$PROJECT_DIR/.git" ]; then
  echo "git init -> $PROJECT_DIR"
  if [ "$DRY_RUN" != "true" ]; then
    git -C "$PROJECT_DIR" init
    git -C "$PROJECT_DIR" add -A
    git -C "$PROJECT_DIR" commit -m "Initial: $DESC" || true
    git -C "$PROJECT_DIR" branch -M main
  fi
else
  echo "git repo bor — commit + push"
  if [ "$DRY_RUN" != "true" ]; then
    git -C "$PROJECT_DIR" add -A
    git -C "$PROJECT_DIR" commit -m "Update: $DESC" || echo "(commit qilinmadi — o'zgarish yo'q)"
    git -C "$PROJECT_DIR" branch -M main || true
  fi
fi

if [ "$DRY_RUN" != "true" ]; then
  git -C "$PROJECT_DIR" remote remove origin 2>/dev/null || true
  # Tokenni URL ga qo'yamiz (log'ga chiqarmaymiz)
  git -C "$PROJECT_DIR" remote add origin "https://x-access-token:${GITHUB_TOKEN}@github.com/${LOGIN}/${REPO_NAME}.git"
  git -C "$PROJECT_DIR" push -u origin main --force-with-lease 2>&1 | sed 's/x-access-token:[^@]*@/x-access-token:***/g' || git -C "$PROJECT_DIR" push -u origin main 2>&1 | sed 's/x-access-token:[^@]*@/x-access-token:***/g'
  git -C "$PROJECT_DIR" remote set-url origin "https://github.com/${LOGIN}/${REPO_NAME}.git"
  echo "Push OK -> $REPO_URL"
else
  echo "[dry-run] push o'tkazib yuborildi"
fi

# 5) Telegram post matni (o'zbekcha)
if [ -n "$DEMO_URL" ]; then
  DEMO_QATOR="🌐 Demo: $DEMO_URL"
else
  DEMO_QATOR="🌐 Demo: tez kunda"
fi

POST="🚀 Yangi loyiha — $REPO_NAME

📝 $DESC

🔗 GitHub: $REPO_URL
$DEMO_QATOR

#AI #loyiha #github #automation"

echo "---- POST MATNI ----"
echo "$POST"
echo "--------------------"

if [ "$DRY_RUN" == "true" ]; then echo "[dry-run] telegram yuborilmadi"; exit 0; fi

TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT="${TELEGRAM_CHANNEL:-}"
if [ -z "$CHAT" ]; then echo "OGOH: TELEGRAM_CHANNEL yo'q — faqat GitHub qilindi."; exit 0; fi
if [ -z "$TOKEN" ]; then echo "OGOH: TELEGRAM_BOT_TOKEN yo'q — faqat GitHub qilindi."; exit 0; fi

curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT}" \
  --data-urlencode "text=${POST}" \
  --data-urlencode "disable_web_page_preview=false" | grep -q '"ok":true' \
  && echo "Telegram OK -> $CHAT" || echo "Telegram XATO — bot kanalga admin qilinganini tekshir."
