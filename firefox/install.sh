#!/usr/bin/env bash
#
# FluidSur Firefox theme installer.
#
# Firefox draws its own window buttons and no longer offers a way to hand that
# job back to GTK — the widget.gtk.non-native-titlebar-buttons pref was removed.
# The only remaining hook is userChrome.css, which is what this component uses
# to give Firefox the same window buttons as the rest of the desktop.
#
# Two strengths are available:
#   full     restyle the whole browser chrome  (default)
#   buttons  restyle only the three window buttons, leave Firefox alone otherwise

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SRC_DIR="${REPO_DIR}/src"

NAME="FluidSur"
MODE="full"
VARIANT=""        # '' | -darker | -adaptive | -nord
REMOVE="false"
PROFILES=()

MARK_BEGIN="/* >>> FluidSur theme begin — managed by firefox/install.sh */"
MARK_END="/* <<< FluidSur theme end */"

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '    \033[33m!\033[0m %s\n' "$*"; }
err()  { printf '    \033[31m✘\033[0m %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

  -m, --mode MODE       full | buttons              (default: full)
                        full    restyle the entire browser chrome
                        buttons only the three window buttons
  -v, --variant NAME    default | darker | adaptive | nord   (default: default)
  -p, --profile DIR     Target this profile directory instead of auto-detecting.
                        May be given more than once.
  -r, --remove          Uninstall
  -h, --help            Show this message

Firefox must be restarted for any change to take effect.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--mode)
      case "$2" in
        full|buttons) MODE="$2" ;;
        *) err "unknown mode: $2"; exit 1 ;;
      esac
      shift 2 ;;
    -v|--variant)
      case "$2" in
        default)  VARIANT="" ;;
        darker|adaptive|nord) VARIANT="-$2" ;;
        *) err "unknown variant: $2"; exit 1 ;;
      esac
      shift 2 ;;
    -p|--profile) PROFILES+=("$2"); shift 2 ;;
    -r|--remove)  REMOVE="true"; shift ;;
    -h|--help)    usage; exit 0 ;;
    *) err "unknown option: $1"; usage; exit 1 ;;
  esac
done

# ── profile discovery ─────────────────────────────────────────────────────────
# Firefox 138 moved Linux profiles from ~/.mozilla to ~/.config/mozilla, and the
# packaged Flatpak and Snap builds keep their own copies. Check all of them.
discover_profiles() {
  local roots=(
    "${HOME}/.mozilla/firefox"
    "${HOME}/.config/mozilla/firefox"
    "${HOME}/.var/app/org.mozilla.firefox/.mozilla/firefox"
    "${HOME}/snap/firefox/common/.mozilla/firefox"
  )
  local root d
  for root in "${roots[@]}"; do
    [[ -d "${root}" ]] || continue
    for d in "${root}"/*.default*/; do
      [[ -d "${d}" ]] || continue
      PROFILES+=("${d%/}")
    done
  done
}

# ── user.js ───────────────────────────────────────────────────────────────────
# Never truncate user.js: it may already hold the user's own settings. Instead
# maintain a delimited block that can be rewritten or removed cleanly.
strip_block() {
  local f="$1"
  [[ -f "${f}" ]] || return 0
  awk -v b="${MARK_BEGIN}" -v e="${MARK_END}" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip   { print }
  ' "${f}" > "${f}.tmp" && mv "${f}.tmp" "${f}"
}

write_prefs() {
  local profile="$1"
  local f="${profile}/user.js"

  [[ -f "${f}" && ! -f "${f}.pre-fluidsur" ]] && cp -a "${f}" "${f}.pre-fluidsur"
  strip_block "${f}"

  {
    echo "${MARK_BEGIN}"
    echo 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'
    echo 'user_pref("svg.context-properties.content.enabled", true);'
    if [[ "${MODE}" == "full" ]]; then
      echo 'user_pref("browser.uidensity", 0);'
      echo 'user_pref("widget.gtk.rounded-bottom-corners.enabled", true);'
      echo 'user_pref("mozilla.widget.use-argb-visuals", true);'
    fi
    echo "${MARK_END}"
  } >> "${f}"
}

# ── install / remove ──────────────────────────────────────────────────────────
install_profile() {
  local profile="$1"
  local chrome="${profile}/chrome"

  # Preserve a pre-existing, foreign chrome/ exactly once.
  if [[ -e "${chrome}" && ! -e "${chrome}/.fluidsur" && ! -e "${profile}/chrome.pre-fluidsur" ]]; then
    mv "${chrome}" "${profile}/chrome.pre-fluidsur"
    warn "existing chrome/ kept at ${profile}/chrome.pre-fluidsur"
  fi

  rm -rf "${chrome}"
  mkdir -p "${chrome}/${NAME}/parts"
  touch "${chrome}/.fluidsur"

  cp -rf "${SRC_DIR}/${NAME}/." "${chrome}/${NAME}/"
  cp -rf "${SRC_DIR}/common/icons" "${SRC_DIR}/common/pages" "${chrome}/${NAME}/"
  if [[ "${VARIANT}" == "-nord" ]]; then
    cp -rf "${SRC_DIR}/common/titlebuttons-nord" "${chrome}/${NAME}/titlebuttons"
  else
    cp -rf "${SRC_DIR}/common/titlebuttons" "${chrome}/${NAME}/"
  fi
  cp -f "${SRC_DIR}/common/"*.css        "${chrome}/${NAME}/"
  cp -f "${SRC_DIR}/common/parts/"*.css  "${chrome}/${NAME}/parts/"
  cp -f "${SRC_DIR}/customChrome.css"    "${chrome}/"

  if [[ "${MODE}" == "full" ]]; then
    cp -f "${SRC_DIR}/userChrome-${NAME}${VARIANT}.css"  "${chrome}/userChrome.css"
    cp -f "${SRC_DIR}/userContent-${NAME}${VARIANT}.css" "${chrome}/userContent.css"
  else
    # Only the window buttons. csd.css carries their geometry, the two
    # titlebutton sheets carry the artwork for each colour scheme.
    cat > "${chrome}/userChrome.css" <<EOF
/* FluidSur — window buttons only. Generated by firefox/install.sh --mode buttons. */
@import "${NAME}/parts/csd.css";
@import "${NAME}/parts/titlebutton-light.css";
@import "${NAME}/parts/titlebutton-dark.css";
EOF
    : > "${chrome}/userContent.css"
  fi

  write_prefs "${profile}"
}

remove_profile() {
  local profile="$1"
  local chrome="${profile}/chrome"

  if [[ -e "${chrome}/.fluidsur" ]]; then
    rm -rf "${chrome}"
    if [[ -e "${profile}/chrome.pre-fluidsur" ]]; then
      mv "${profile}/chrome.pre-fluidsur" "${chrome}"
      ok "restored the previous chrome/ in ${profile##*/}"
    fi
  elif [[ -e "${chrome}" ]]; then
    warn "chrome/ in ${profile##*/} was not installed by FluidSur, left alone"
  fi

  strip_block "${profile}/user.js"
  [[ -s "${profile}/user.js" ]] || rm -f "${profile}/user.js"
}

# ── main ──────────────────────────────────────────────────────────────────────
if [[ ${#PROFILES[@]} -eq 0 ]]; then
  discover_profiles
fi

if [[ ${#PROFILES[@]} -eq 0 ]]; then
  err "no Firefox profile found"
  echo "    Looked in ~/.mozilla/firefox, ~/.config/mozilla/firefox, and the"
  echo "    Flatpak and Snap locations. Pass --profile DIR to target one directly."
  exit 1
fi

if [[ "${REMOVE}" == "true" ]]; then
  say "Removing the FluidSur Firefox theme"
  for p in "${PROFILES[@]}"; do
    remove_profile "${p}"
    ok "${p}"
  done
else
  say "Installing the FluidSur Firefox theme (mode: ${MODE}${VARIANT:+, variant: ${VARIANT#-}})"
  for p in "${PROFILES[@]}"; do
    if install_profile "${p}"; then
      ok "${p}"
    else
      err "failed on ${p}"
    fi
  done
fi

if pgrep -x firefox >/dev/null 2>&1; then
  warn "Firefox is running — restart it for the change to take effect"
fi
