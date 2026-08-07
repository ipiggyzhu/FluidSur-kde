#!/usr/bin/env bash

set -euo pipefail

readonly ROOT_UID=0
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly THEME_DIR="${SDDM_THEME_DIR:-/usr/share/sddm/themes}"
readonly THEME_NAME="FluidSur"

usage() {
  cat <<EOF
Usage: sudo $0 [--uninstall]

Install or remove the FluidSur SDDM theme. The script selects the matching
Plasma 5/6 QML variant and installs light and dark themes.
EOF
}

remove_themes() {
  rm -rf -- "$THEME_DIR/$THEME_NAME-light" "$THEME_DIR/$THEME_NAME-dark"
  printf 'Removed FluidSur SDDM themes from %s\n' "$THEME_DIR"
}

if (( EUID != ROOT_UID )) && [[ "$THEME_DIR" == "/usr/share/sddm/themes" ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    printf 'Error: run this script as root (sudo is not installed).\n' >&2
    exit 1
  fi
  sudo -v
  exec sudo "$0" "$@"
fi

uninstall=false
while (( $# > 0 )); do
  case "$1" in
    --uninstall|-u) uninstall=true; shift;;
    --help|-h) usage; exit 0;;
    *) printf 'Error: unknown option %s\n' "$1" >&2; usage >&2; exit 2;;
  esac
done

if [[ "$uninstall" == true ]]; then
  remove_themes
  exit 0
fi

desk_version="6.2"
version_text=""
if command -v plasmashell >/dev/null 2>&1; then
  version_text="$(plasmashell --version 2>/dev/null || true)"
fi
if [[ "$version_text" =~ ([0-9]+)\.([0-9]+) ]]; then
  major="${BASH_REMATCH[1]}"
  minor="${BASH_REMATCH[2]}"
  if (( major < 6 )); then
    desk_version="5.0"
  elif (( minor < 2 )); then
    desk_version="6.0"
  fi
fi

mkdir -p "$THEME_DIR"

install_variant() {
  local color="$1"
  local source="$SCRIPT_DIR/$THEME_NAME-$desk_version"
  local destination="$THEME_DIR/$THEME_NAME$color"

  [[ -d "$source" ]] || { printf 'Error: missing SDDM source %s\n' "$source" >&2; exit 1; }
  rm -rf -- "$destination"
  cp -a "$source" "$destination"
  cp -a "$SCRIPT_DIR/images/background${color}.jpeg" "$destination/background.jpeg"
  cp -a "$SCRIPT_DIR/images/preview${color}.jpeg" "$destination/preview.jpeg"

  sed -i \
    -e "s/^Name=$THEME_NAME$/Name=$THEME_NAME$color/" \
    -e "s/^Theme-Id=$THEME_NAME$/Theme-Id=$THEME_NAME$color/" \
    "$destination/metadata.desktop"
}

printf "Installing FluidSur SDDM themes (Plasma %s)...\n" "$desk_version"
install_variant "-light"
install_variant "-dark"
printf "SDDM installation finished.\n"
