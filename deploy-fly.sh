#!/usr/bin/env bash
# fly.io'ga xavfsiz deploy (Git Bash / WSL / Linux / Termux).
# Reja tuzadi, foydalanuvchi tasdig'isiz HECH NARSANI o'zgartirmaydi.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PATH_ARG=""; APP=""; NEW=0; PROFILE="auto"; REGION=""
CPU=""; MEM=""; VM=""; MIN_MACHINES=0; AUTO_STOP="suspend"; NO_SUSPEND=0
BUILD_ONLY=0; YES=0; DRYRUN=0

usage() { sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -Path|--path)      PATH_ARG="$2"; shift 2 ;;
    -App|--app)        APP="$2"; shift 2 ;;
    -New|--new)        NEW=1; shift ;;
    -Cpu|--cpu)        CPU="$2"; shift 2 ;;
    -MemoryMb)         MEM="$2"; shift 2 ;;
    -VmSize)           VM="$2"; shift 2 ;;
    -Region)           REGION="$2"; shift 2 ;;
    -Profile)          PROFILE="$2"; shift 2 ;;
    -MinMachinesRunning) MIN_MACHINES="$2"; shift 2 ;;
    -AutoStopMachines) AUTO_STOP="$2"; shift 2 ;;
    -NoAutoSuspend)    NO_SUSPEND=1; shift ;;
    -BuildOnly)        BUILD_ONLY=1; shift ;;
    -Yes|-y)           YES=1; shift ;;
    -DryRun)           DRYRUN=1; shift ;;
    -h|--help)         usage ;;
    *) echo "Noma'lum argument: $1" >&2; usage ;;
  esac
done

if [[ -f "$DIR/.env" ]]; then set -a; . "$DIR/.env"; set +a; fi

if ! command -v flyctl >/dev/null 2>&1; then
  for d in "$HOME/.fly/bin" "$HOME/bin" "/usr/local/bin"; do
    if [[ -x "$d/flyctl" ]]; then export PATH="$d:$PATH"; break; fi
  done
fi
command -v flyctl >/dev/null 2>&1 || { echo "XATO: flyctl topilmadi. iwr -useb https://fly.io/install.ps1 | iex  yoki  curl -L https://fly.io/install.sh | sh" >&2; exit 1; }
[[ -n "${FLY_API_TOKEN:-}" ]] || { echo "XATO: FLY_API_TOKEN topilmadi (.env ga qo'shing)." >&2; exit 1; }
export FLY_NO_UPDATE_CHECK=1

[[ -n "$PATH_ARG" ]] || { echo "XATO: -Path majburiy." >&2; exit 1; }
[[ -d "$PATH_ARG" ]] || { echo "XATO: papka topilmadi -> $PATH_ARG" >&2; exit 1; }
PROJECT_DIR="$(cd "$PATH_ARG" && pwd)"
TOML="$PROJECT_DIR/fly.toml"
[[ -f "$TOML" || -f "$PROJECT_DIR/Dockerfile" ]] || {
  echo "XATO: fly.toml ham, Dockerfile ham yo'q. Skript hech narsani yaratmaydi." >&2; exit 1; }

# --- loyiha hajmi (node_modules/.git/.venv siz) ---
TOTAL_MB=$(find "$PROJECT_DIR" -type f \
  ! -path '*/node_modules/*' ! -path '*/.git/*' ! -path '*/.venv/*' ! -path '*/venv/*' \
  ! -path '*/__pycache__/*' ! -path '*/dist/*' ! -path '*/build/*' ! -path '*/.next/*' \
  ! -path '*/target/*' ! -path '*/site-packages/*' ! -path '*/.fly/*' -printf '%s\n' 2>/dev/null \
  | awk '{s+=$1} END {printf "%.1f", s/1048576}')
HEAVY=$(find "$PROJECT_DIR" -type f -size +25M \
  ! -path '*/node_modules/*' ! -path '*/.git/*' 2>/dev/null | head -5 | wc -l | tr -d ' ')

STACK=""
for f in package.json requirements.txt pyproject.toml go.mod Cargo.toml Gemfile composer.json Dockerfile; do
  [[ -f "$PROJECT_DIR/$f" ]] && STACK="$STACK $f"
done

# --- hajmga qarab resurs ---
if [[ "$PROFILE" == "auto" ]]; then
  if   awk "BEGIN{exit !($TOTAL_MB >= 200 || $HEAVY > 0)}"; then PROFILE="large"
  elif awk "BEGIN{exit !($TOTAL_MB >= 20)}"; then PROFILE="medium"
  elif awk "BEGIN{exit !($TOTAL_MB >= 2)}"; then PROFILE="small"
  else PROFILE="tiny"; fi
fi
[[ -f "$PROJECT_DIR/requirements.txt" && "$PROFILE" == "tiny" ]] && PROFILE="small"
true

case "$PROFILE" in
  tiny)   D_CPU="shared-cpu-1x";   D_MEM="256m"; D_VM="shared-cpu-1x" ;;
  small)  D_CPU="shared-cpu-1x";   D_MEM="512m"; D_VM="shared-cpu-1x" ;;
  medium) D_CPU="shared-cpu-2x";   D_MEM="1g";   D_VM="shared-cpu-2x" ;;
  large)  D_CPU="performance-1x"; D_MEM="2g";   D_VM="performance-1x" ;;
  *) echo "XATO: -Profile tiny|small|medium|large oladi." >&2; exit 1 ;;
esac
RES_CPU="${CPU:-$D_CPU}"; RES_MEM="${MEM:-${D_MEM}}"; RES_VM="${VM:-$D_VM}"
[[ "$NO_SUSPEND" -eq 1 ]] && { AUTO_STOP="off"; MIN_MACHINES=1; }
true
KIND="shared"; [[ "$RES_CPU" == performance* ]] && KIND="performance"
NCPU=1; [[ "$RES_CPU" =~ -([0-9]+)x$ ]] && NCPU="${BASH_REMATCH[1]}"
NUM="${RES_MEM//[^0-9.]/}"                 # "256m" -> 256 ; "1g" -> 1
if [[ "${RES_MEM^^}" == *G* ]]; then NMB=$(awk "BEGIN{printf \"%d\", $NUM*1024}")
else NMB="${NUM%%.*}"; fi

# --- mavjud app'lar ---
EXISTING=$(flyctl apps list --json 2>/dev/null | grep -o '"Name":"[^"]*"' | cut -d'"' -f4 || true)

if [[ -z "$APP" ]]; then
  echo "============================================================"
  echo " APP NOMI BERILMADI — hech narsa o'zgartirilmadi."
  echo "============================================================"
  echo "Papka: $PROJECT_DIR"
  if [[ -n "$EXISTING" ]]; then
    echo "Mavjud fly app'lar:"; while read -r a; do [[ -n "$a" ]] && echo "  - $a"; done <<< "$EXISTING"
  else echo "Mavjud app topilmadi."; fi
  echo ""
  echo "Reja (auto-sizing, loyiha ${TOTAL_MB} MB):"
  echo "  profile : $PROFILE"
  echo "  cpu/mem : $RES_CPU / $RES_MEM"
  echo "  vm size : $RES_VM"
  echo "  suspend : auto_stop=$AUTO_STOP, min_machines_running=$MIN_MACHINES"
  echo ""
  echo "Qayta ishga tushiring:"
  echo "  -App <nom>            # mavjud app'ni yangilash"
  echo "  -App <nom> -New        # yangi app yaratish"
  exit 0
fi

IS_NEW=0
if [[ "$NEW" -eq 1 ]] || ! grep -qx "$APP" <<< "$EXISTING"; then IS_NEW=1; fi
NEW_FLAG=""
[[ "$IS_NEW" -eq 1 ]] && NEW_FLAG=" -New"
IS_NEW_TXT=$([ "$IS_NEW" -eq 1 ] && echo " (YANGI yaratiladi)" || echo " (mavjud, yangilanadi)")

cat <<PLAN
================== FLY DEPLOY REJASI ==================
Papka        : $PROJECT_DIR
Loyiha hajmi : ${TOTAL_MB} MB (kod+assets, node_modules/.git siz)
Stack        : $STACK
App          : $APP $IS_NEW_TXT
Profile      : $PROFILE
CPU / RAM    : $RES_CPU / $RES_MEM
VM size      : $RES_VM
Auto-suspend : auto_stop_machines = "$AUTO_STOP"
Min machines : $MIN_MACHINES  (0 = to'liq avto-suspend, pul tejash)
========================================================
PLAN

if [[ "$DRYRUN" -eq 1 ]]; then echo "[dry-run] hech narsa o'zgartirilmadi"; exit 0; fi
if [[ "$YES" -ne 1 ]]; then
  echo "Bu reja HECH BIR narsani o'zgartirmadi (tasdiq kutilmoqda)."
  echo "Tasdiqlash uchun -Yes qo'shing:  ./deploy-fly.sh -Path \"$PATH_ARG\" -App $APP$NEW_FLAG -Yes"
  exit 0
fi

if [[ -f "$TOML" ]]; then cp "$TOML" "$TOML.bak"; fi

# --- avto-suspend har doim qo'llanadi (pul tejash) ---
set_suspend() {
  local tmp; tmp="$(mktemp)"
  # mavjud kalitlarni avval tekshiramiz — aks holda takrorlanib qoladi
  local has_stop has_mn has_asm
  grep -qE '^[ \t]*auto_stop_machines[ \t]*='   "$TOML" && has_stop=1 || has_stop=0
  grep -qE '^[ \t]*min_machines_running[ \t]*=' "$TOML" && has_mn=1   || has_mn=0
  grep -qE '^[ \t]*auto_start_machines[ \t]*='  "$TOML" && has_asm=1  || has_asm=0

  awk -v stop="$AUTO_STOP" -v mn="$MIN_MACHINES" -v q="'" \
      -v has_stop="$has_stop" -v has_mn="$has_mn" -v has_asm="$has_asm" '
    {
      if ($0 ~ /^[ \t]*auto_stop_machines[ \t]*=/)   { print "  auto_stop_machines = " q stop q; next }
      if ($0 ~ /^[ \t]*min_machines_running[ \t]*=/) { print "  min_machines_running = " mn;        next }
      print
      if (has_stop == 0 && $0 ~ /^[ \t]*force_https[ \t]*=/) {
        print "  auto_stop_machines = " q stop q
        if (has_mn == 0) print "  min_machines_running = " mn
        if (has_asm == 0) print "  auto_start_machines = true"
      }
    }
  ' "$TOML" > "$tmp"
  mv "$tmp" "$TOML"
}

if [[ ! -f "$TOML" ]]; then
  PRIMARY="${REGION:-mad}"
  cat > "$TOML" <<EOF
app = '$APP'
primary_region = '$PRIMARY'

[build]

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = '$AUTO_STOP'
  auto_start_machines = true
  min_machines_running = $MIN_MACHINES
  processes = ['app']

  [http_service.concurrency]
    type = 'requests'
    soft_limit = 200
    hard_limit = 250

[[vm]]
  size = "$RES_VM"
  cpu_kind = '$KIND'
  cpus = $NCPU
  memory_mb = $NMB
EOF
  echo "fly.toml yaratildi"
else
  set_suspend
fi

# --- vm resurslarini moslashtirish ---
if grep -q '^\[\[vm\]\]' "$TOML" 2>/dev/null; then
  sed -i -E "s|^([[:space:]]*size[[:space:]]*=).*|\1 \"$RES_VM\"|; s|^([[:space:]]*cpu_kind[[:space:]]*=).*|\1 '$KIND'|; s|^([[:space:]]*cpus[[:space:]]*=).*|\1 $NCPU|; s|^([[:space:]]*memory_mb[[:space:]]*=).*|\1 $NMB|" "$TOML"
else
  cat >> "$TOML" <<EOF

[[vm]]
  size = "$RES_VM"
  cpu_kind = '$KIND'
  cpus = $NCPU
  memory_mb = $NMB
EOF
fi
echo "fly.toml yangilandi: $RES_CPU / $RES_MEM, auto_stop=$AUTO_STOP, min_machines_running=$MIN_MACHINES"

if [[ "$IS_NEW" -eq 1 ]]; then
  if [[ "$NEW" -ne 1 && -n "$EXISTING" ]]; then
    echo "XATO: '$APP' apps list'da yo'q. Yangi app yaratish uchun -New qo'shing." >&2; exit 1
  fi
  echo "App yaratilmoqda: $APP"
  flyctl apps create "$APP"
fi

if [[ "$BUILD_ONLY" -eq 1 ]]; then
  flyctl build
  echo "Build tugadi (deploy qilinmadi)."
  exit 0
fi

echo "Deploy boshlandi..."
flyctl deploy --strategy rolling --now -y

HOST="$(flyctl status --json 2>/dev/null | grep -o '"Hostname":"[^"]*"' | cut -d'"' -f4)"
HOST="${HOST:-$APP.fly.dev}"

echo ""
echo "===================================================="
echo "OK -> https://$HOST"
echo "Mashina: $RES_CPU / $RES_MEM  |  auto_stop=$AUTO_STOP  |  min_machines_running=$MIN_MACHINES"
echo "Avto-suspend: trafik tugasa mashina o'chadi -> oylik to'lanish kamayadi."
echo "===================================================="
echo "Keyingi qadam: ./publish.ps1 -Path \"$PATH_ARG\" -Repo $APP -Desc \"<tavsif>\" -Demo https://$HOST"
