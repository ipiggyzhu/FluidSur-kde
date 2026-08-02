#!/usr/bin/env bash

set -euo pipefail

readonly ROOT_UID=0
readonly THEME_NAME="FluidSur"

if (( EUID == ROOT_UID )); then
  AURORAE_DIR="/usr/share/aurorae/themes"
  SCHEMES_DIR="/usr/share/color-schemes"
  PLASMA_DIR="/usr/share/plasma/desktoptheme"
  LOOKFEEL_DIR="/usr/share/plasma/look-and-feel"
  KVANTUM_DIR="/usr/share/Kvantum"
  WALLPAPER_DIR="/usr/share/wallpapers"
  ICONS_DIR="/usr/share/icons"
  PLASMOIDS_DIR="/usr/share/plasma/plasmoids"
  LAYOUTS_DIR="/usr/share/plasma/layout-templates"
  SENSORFACES_DIR="/usr/share/ksysguard/sensorfaces"
  LOCALE_DIR="/usr/share/locale"
else
  AURORAE_DIR="$HOME/.local/share/aurorae/themes"
  SCHEMES_DIR="$HOME/.local/share/color-schemes"
  PLASMA_DIR="$HOME/.local/share/plasma/desktoptheme"
  LOOKFEEL_DIR="$HOME/.local/share/plasma/look-and-feel"
  KVANTUM_DIR="$HOME/.config/Kvantum"
  WALLPAPER_DIR="$HOME/.local/share/wallpapers"
  ICONS_DIR="$HOME/.local/share/icons"
  PLASMOIDS_DIR="$HOME/.local/share/plasma/plasmoids"
  LAYOUTS_DIR="$HOME/.local/share/plasma/layout-templates"
  SENSORFACES_DIR="$HOME/.local/share/ksysguard/sensorfaces"
  LOCALE_DIR="$HOME/.local/share/locale"
fi

readonly LATTE_DIR="$HOME/.config/latte"

remove_path() {
  if [[ -e "$1" || -L "$1" ]]; then
    printf 'Removing %s\n' "$1"
    rm -rf -- "$1"
  fi
}

remove_glob() {
  local path
  for path in "$@"; do
    remove_path "$path"
  done
}

printf "Uninstalling '%s KDE themes'...\n" "$THEME_NAME"

remove_glob \
  "$AURORAE_DIR"/FluidSur* \
  "$PLASMA_DIR"/FluidSur* \
  "$LOOKFEEL_DIR"/com.github.fluidsur.FluidSur* \
  "$KVANTUM_DIR"/FluidSur* \
  "$WALLPAPER_DIR"/FluidSur* \
  "$ICONS_DIR/FluidSur" \
  "$ICONS_DIR/FluidSur-cursors" \
  "$LATTE_DIR/FluidSur.layout.latte" \
  "$PLASMOIDS_DIR/org.fluidsur.plasma.battery" \
  "$PLASMOIDS_DIR/org.kde.plasma.splitdigitalclock" \
  "$LAYOUTS_DIR/org.fluidsur.desktop.FluidSurPanel" \
  "$SENSORFACES_DIR/org.fluidsur.ksysguard.textonly" \
  "$LOCALE_DIR/zh_CN/LC_MESSAGES/plasma_applet_org.fluidsur.plasma.battery.mo"

for scheme in "$SCHEMES_DIR"/FluidSur*.colors; do
  [[ -e "$scheme" ]] && remove_path "$scheme"
done

printf "Uninstall finished.\n"
