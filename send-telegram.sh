#!/bin/bash
# ArcadiaUZ — Telegram'ga post yuborish
# Ishlatish: ./send-telegram.sh "xabar matni"
# .env dan TELEGRAM_BOT_TOKEN va TELEGRAM_CHANNEL o'qiladi
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -f "$DIR/.env" ]; then
  set -a; source "$DIR/.env"; set +a
fi

TOKEN="${TELEGRAM_BOT_TOKEN:-}"
CHAT="${TELEGRAM_CHANNEL:-@ArcadiaUZ}"
MSG="${1:-}"

if [ -z "$TOKEN" ]; then echo "XATO: TELEGRAM_BOT_TOKEN yo'q (.env ni tekshir)"; exit 1; fi
if [ -z "$MSG" ]; then echo "XATO: xabar bo'sh"; exit 1; fi

# Markdown xavfsizligi uchun parse_mode ishlatmaymiz — oddiy text + emoji
RESP=$(curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${CHAT}" \
  --data-urlencode "text=${MSG}" \
  --data-urlencode "disable_web_page_preview=false")

echo "$RESP" | grep -q '"ok":true' && echo "OK: post yuborildi -> $CHAT" || { echo "XATO: $RESP"; exit 1; }
