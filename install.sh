#!/usr/bin/env bash
# ============================================================================
# M3-CRETE — Klipper config installer (Tier 1)
# ============================================================================
# Installs the M3-CRETE Klipper configuration onto a Raspberry Pi that already
# runs Klipper + Moonraker (e.g. MainsailOS). It does NOT fork or reinstall
# Klipper/Moonraker/Mainsail — those stay upstream and self-update via Moonraker.
#
# What it does:
#   1. Drops our printer.cfg into ~/printer_data/config (backing up any existing)
#   2. Adds the M3-CRETE + KlipperScreen update_manager blocks to moonraker.conf
#      (without clobbering an existing MainsailOS moonraker.conf)
#   3. Optionally installs KlipperScreen (Pi touchscreen UI)
#   4. Best-effort auto-detects the Kraken's serial path
#   5. Restarts Klipper + Moonraker
#
# Usage:   ./install.sh [--no-screen] [--force] [--help]
#   --no-screen   skip KlipperScreen install
#   --force       overwrite the active printer.cfg without the "backup first" copy
# ============================================================================
set -euo pipefail

# ---- options ---------------------------------------------------------------
INSTALL_SCREEN=1
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --no-screen) INSTALL_SCREEN=0 ;;
    --force)     FORCE=1 ;;
    -h|--help)   grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)"; exit 1 ;;
  esac
done

# ---- helpers ---------------------------------------------------------------
info()  { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()   { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "Do NOT run as root/sudo. Run as the user that owns Klipper (e.g. 'pi')."

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PRINTER_DATA="${PRINTER_DATA:-$HOME/printer_data}"
CONFIG_DIR="$PRINTER_DATA/config"
STAMP="$(date +%Y%m%d-%H%M%S)"

info "Repo:        $REPO_DIR"
info "Config dir:  $CONFIG_DIR"

[ -d "$CONFIG_DIR" ] || die "No $CONFIG_DIR found. Install Klipper + Moonraker first \
(flash MainsailOS, or run KIAUH: https://github.com/dw-0/kiauh), then re-run this."
[ -f "$REPO_DIR/klipper/printer.cfg" ] || die "Can't find klipper/printer.cfg in the repo."

# ---- 1. active printer.cfg -------------------------------------------------
DEST_CFG="$CONFIG_DIR/printer.cfg"
if [ -f "$DEST_CFG" ] && [ "$FORCE" -eq 0 ]; then
  cp -a "$DEST_CFG" "$DEST_CFG.bak.$STAMP"
  warn "Backed up existing printer.cfg -> printer.cfg.bak.$STAMP"
fi
cp -a "$REPO_DIR/klipper/printer.cfg" "$DEST_CFG"
info "Installed printer.cfg"
# NOTE: this is YOUR working copy — edit serial/tuning here. To adopt a newer
# repo version later: git pull, then re-run install.sh (it backs up first).

# ---- 2. moonraker.conf (add blocks, never clobber) ------------------------
MOON="$CONFIG_DIR/moonraker.conf"
add_block() {  # $1 = marker section header, $2 = file with the block
  if [ -f "$MOON" ] && grep -qF "$1" "$MOON"; then
    info "moonraker.conf already has $1 — leaving it"
  else
    { echo ""; cat "$2"; } >> "$MOON"
    info "Added $1 to moonraker.conf"
  fi
}

if [ ! -f "$MOON" ]; then
  cp -a "$REPO_DIR/klipper/moonraker.conf" "$MOON"
  info "Installed moonraker.conf (fresh)"
else
  warn "Existing moonraker.conf found — adding only our blocks"
  TMP_M3="$(mktemp)"; TMP_KS="$(mktemp)"
  cat > "$TMP_M3" <<EOF
[update_manager m3-crete]
type: git_repo
path: $REPO_DIR
origin: https://github.com/sunnyday-technologies/M3-CRETE-FIRMWARE.git
primary_branch: main
is_system_service: False
managed_services: klipper
EOF
  cat > "$TMP_KS" <<'EOF'
[update_manager KlipperScreen]
type: git_repo
path: ~/KlipperScreen
origin: https://github.com/KlipperScreen/KlipperScreen.git
env: ~/.KlipperScreen-env/bin/python
requirements: scripts/KlipperScreen-requirements.txt
install_script: scripts/KlipperScreen-install.sh
managed_services: KlipperScreen
EOF
  add_block "[update_manager m3-crete]" "$TMP_M3"
  [ "$INSTALL_SCREEN" -eq 1 ] && add_block "[update_manager KlipperScreen]" "$TMP_KS"
  rm -f "$TMP_M3" "$TMP_KS"
fi
# Point the m3-crete path at the real clone location (fresh-install template default).
sed -i "s|^path: ~/M3-CRETE-FIRMWARE$|path: $REPO_DIR|" "$MOON" 2>/dev/null || true

# ---- 3. KlipperScreen (Pi touchscreen UI) ---------------------------------
if [ "$INSTALL_SCREEN" -eq 1 ]; then
  if [ -d "$HOME/KlipperScreen" ]; then
    info "KlipperScreen already present — skipping (Moonraker keeps it updated)"
  else
    info "Installing KlipperScreen..."
    git clone https://github.com/KlipperScreen/KlipperScreen.git "$HOME/KlipperScreen"
    "$HOME/KlipperScreen/scripts/KlipperScreen-install.sh"
  fi
else
  info "Skipping KlipperScreen (--no-screen)"
fi

# ---- 4. best-effort serial auto-detect ------------------------------------
mapfile -t SERIALS < <(ls /dev/serial/by-id/ 2>/dev/null | grep -i klipper || true)
if [ "${#SERIALS[@]}" -eq 1 ]; then
  sed -i "s|^serial: .*|serial: /dev/serial/by-id/${SERIALS[0]}|" "$DEST_CFG"
  info "Set MCU serial -> ${SERIALS[0]}"
elif [ "${#SERIALS[@]}" -eq 0 ]; then
  warn "No Klipper USB device found. Flash the Kraken, then edit 'serial:' in printer.cfg."
else
  warn "Multiple Klipper devices found — set 'serial:' in printer.cfg manually:"
  printf '      %s\n' "${SERIALS[@]}"
fi

# ---- 5. restart services ---------------------------------------------------
info "Restarting Klipper + Moonraker..."
sudo systemctl restart klipper moonraker || warn "Could not restart services — restart them from Mainsail."

cat <<EOF

$(info "M3-CRETE config installed.")
  Active config : $DEST_CFG
  Tracked repo  : $REPO_DIR  (shows in Mainsail's update panel)

Next:
  1. Open Mainsail at  http://$(hostname).local/  and confirm Klipper is 'Ready'.
  2. If the MCU serial wasn't auto-set, fix it in printer.cfg (ls /dev/serial/by-id/).
  3. Stage 1 bring-up (4 Z motors): see klipper/README.md  ->  ZHOLD, ZJOG, HOME_Z.
EOF
