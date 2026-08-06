#!/usr/bin/env bash

set -euo pipefail

readonly ROOT_UID=0
readonly THEME_NAME="FluidSur"
readonly SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

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
  THEMES_DIR="/usr/share/themes"
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
  THEMES_DIR="$HOME/.themes"
fi

readonly LATTE_DIR="$HOME/.config/latte"

COLOR_VARIANTS=("" "-dark")
PCOLOR_VARIANTS=("" "-alt" "-dark")
WINDOW_VARIANTS=("" "-opaque" "-sharp")
SCALE_VARIANTS=("" "_x1.25" "_x1.5" "_x1.75" "_x2.0")

usage() {
  cat <<EOF
Usage: $0 [OPTION]...

Install FluidSur KDE themes into the current user's data directory. Run with
sudo for a system-wide installation.

Options:
  -c, --color VARIANT...   Install light, alt and/or dark variants
  -w, --window VARIANT...  Install default, opaque and/or sharp decorations
      --sharp              Alias for --window sharp
      --opaque             Alias for --window opaque
      --no-gtk             Skip the GTK theme (GTK apps keep whatever GTK theme
                           is already selected)
      --firefox [MODE]     Also theme Firefox. MODE is 'full' (default) or
                           'buttons' for the window buttons only. Off unless
                           asked for, because it rewrites the browser profile's
                           chrome/ directory.
  -h, --help               Show this help

Examples:
  $0
  $0 --color dark
  $0 --window opaque
  $0 --firefox
  sudo $0
  sudo ./sddm/install.sh
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 2
}

require_value() {
  (( $# >= 2 )) || die "${1} requires a value"
}

remove_path() {
  if [[ -e "$1" || -L "$1" ]]; then
    rm -rf -- "$1"
  fi
}

# Builds and installs the GTK half of FluidSur. Kept non-fatal on purpose: the
# GTK build needs sassc and glib-compile-resources, and a machine missing those
# should still get a complete KDE install.
install_gtk_theme() {
  local installer="$SRC_DIR/gtk/install.sh"

  if [[ ! -f "$installer" ]]; then
    printf "  GTK component not present, skipping.\n"
    return 0
  fi

  local missing=()
  command -v sassc >/dev/null || missing+=("sassc")
  command -v glib-compile-resources >/dev/null || missing+=("glib2-devel")

  if (( ${#missing[@]} > 0 )); then
    printf "  Skipping GTK theme, missing: %s\n" "${missing[*]}"
    printf "  Fedora: sudo dnf install sassc glib2-devel\n"
    return 0
  fi

  bash "$installer" --dest "$THEMES_DIR" || printf "  GTK theme build failed, continuing.\n"
}

# Firefox draws its own window buttons and ignores the GTK theme for them, so it
# needs a userChrome.css of its own. Always per-user: a browser profile lives in
# $HOME even when this script runs under sudo.
install_firefox_theme() {
  local installer="$SRC_DIR/firefox/install.sh"

  if [[ ! -f "$installer" ]]; then
    printf "  Firefox component not present, skipping.\n"
    return 0
  fi

  if (( EUID == 0 )); then
    printf "  Refusing to touch a browser profile as root.\n"
    printf "  Run '%s --firefox' as your own user instead.\n" "$installer"
    return 0
  fi

  bash "$installer" --mode "${firefox_mode:-full}" \
    || printf "  Firefox theme install failed, continuing.\n"
}

install_kvantum_and_wallpapers() {
  remove_path "$KVANTUM_DIR/$THEME_NAME"
  remove_path "$KVANTUM_DIR/$THEME_NAME-opaque"
  remove_path "$WALLPAPER_DIR/$THEME_NAME"
  remove_path "$WALLPAPER_DIR/$THEME_NAME-light"
  remove_path "$WALLPAPER_DIR/$THEME_NAME-dark"

  cp -a "$SRC_DIR/Kvantum/$THEME_NAME" "$KVANTUM_DIR/"
  if [[ "${install_opaque:-false}" == true ]]; then
    cp -a "$SRC_DIR/Kvantum/$THEME_NAME-opaque" "$KVANTUM_DIR/"
  fi

  cp -a "$SRC_DIR/wallpaper/$THEME_NAME" "$WALLPAPER_DIR/"
  cp -a "$SRC_DIR/wallpaper/$THEME_NAME-light" "$WALLPAPER_DIR/"
  cp -a "$SRC_DIR/wallpaper/$THEME_NAME-dark" "$WALLPAPER_DIR/"

  if [[ -d "$LATTE_DIR" && -f "$SRC_DIR/latte-dock/$THEME_NAME.layout.latte" ]]; then
    cp -a "$SRC_DIR/latte-dock/$THEME_NAME.layout.latte" "$LATTE_DIR/"
  fi
}

install_icons() {
  local icon_theme

  for icon_theme in "$THEME_NAME" "$THEME_NAME-light" "$THEME_NAME-dark" "$THEME_NAME-cursors"; do
    [[ -d "$SRC_DIR/icons/$icon_theme" ]] || die "Missing icon theme: $icon_theme"
    remove_path "$ICONS_DIR/$icon_theme"
    cp -a "$SRC_DIR/icons/$icon_theme" "$ICONS_DIR/"
  done

  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    for icon_theme in "$THEME_NAME" "$THEME_NAME-light" "$THEME_NAME-dark"; do
      gtk-update-icon-cache --force "$ICONS_DIR/$icon_theme" >/dev/null
    done
  fi
}

install_plasma_theme() {
  local pcolor="$1"
  local source="$SRC_DIR/plasma/desktoptheme/$THEME_NAME$pcolor"
  local destination="$PLASMA_DIR/$THEME_NAME$pcolor"

  [[ -d "$source" ]] || die "Missing Plasma theme: $source"
  remove_path "$destination"
  cp -a "$source" "$PLASMA_DIR/"
  cp -a "$SRC_DIR/plasma/desktoptheme/icons" "$SRC_DIR/plasma/desktoptheme/weather" "$destination/"
}

install_look_and_feel() {
  local pcolor="$1"
  local package="com.github.fluidsur.$THEME_NAME$pcolor"
  local source="$SRC_DIR/plasma/look-and-feel/$package"

  [[ -d "$source" ]] || die "Missing global theme: $source"
  remove_path "$LOOKFEEL_DIR/$package"
  cp -a "$source" "$LOOKFEEL_DIR/"
}

install_color_schemes() {
  local file
  for file in "$SRC_DIR"/color-schemes/*.colors; do
    [[ -f "$file" ]] || continue
    cp -a "$file" "$SCHEMES_DIR/"
  done
}

install_aurorae() {
  local color="$1"
  local window="$2"
  local scale="$3"
  local source="$SRC_DIR/aurorae/main$window/$THEME_NAME$color$window$scale"
  local rc_source="$SRC_DIR/aurorae/main$window/$THEME_NAME$color${window}rc"
  local destination="$AURORAE_DIR/$THEME_NAME$color$window$scale"

  [[ -d "$source" ]] || die "Missing Aurorae decoration: $source"
  [[ -f "$rc_source" ]] || die "Missing Aurorae configuration: $rc_source"
  remove_path "$destination"
  cp -a "$source" "$destination"
  cp -a "$SRC_DIR/aurorae/common/assets$color"/*.svg "$destination/"
  cp -a "$SRC_DIR/aurorae/metadata.desktop" "$destination/"
  cp -a "$SRC_DIR/aurorae/metadata.json" "$destination/"
  cp -a "$rc_source" "$destination/$THEME_NAME$color$window${scale}rc"

  # Aurorae uses the directory name as the plugin id. Only rewrite the
  # identity fields; leave the FluidSur Project attribution untouched.
  sed -i \
    -e "s/^Name=FluidSur$/Name=$THEME_NAME$color$window$scale/" \
    -e "s/^X-KDE-PluginInfo-Name=FluidSur$/X-KDE-PluginInfo-Name=$THEME_NAME$color$window$scale/" \
    -e "s/\"Name\": \"FluidSur\"/\"Name\": \"$THEME_NAME$color$window$scale\"/" \
    -e "s/\"Id\": \"FluidSur\"/\"Id\": \"$THEME_NAME$color$window$scale\"/" \
    "$destination/metadata.desktop" "$destination/metadata.json"
}

install_addons() {
  local package
  mkdir -p "$PLASMOIDS_DIR" "$LAYOUTS_DIR" "$SENSORFACES_DIR" "$LOCALE_DIR/zh_CN/LC_MESSAGES"

  if [[ -d "$SRC_DIR/plasma/plasmoids" ]]; then
    for package in "$SRC_DIR/plasma/plasmoids"/*; do
      [[ -d "$package" ]] || continue
      remove_path "$PLASMOIDS_DIR/$(basename "$package")"
      cp -a "$package" "$PLASMOIDS_DIR/"
    done
  fi

  if [[ -d "$SRC_DIR/plasma/sensorfaces" ]]; then
    for package in "$SRC_DIR/plasma/sensorfaces"/*; do
      [[ -d "$package" ]] || continue
      remove_path "$SENSORFACES_DIR/$(basename "$package")"
      cp -a "$package" "$SENSORFACES_DIR/"
    done
  fi

  if [[ -d "$SRC_DIR/plasma/layout-templates" ]]; then
    for package in "$SRC_DIR/plasma/layout-templates"/*; do
      [[ -d "$package" ]] || continue
      remove_path "$LAYOUTS_DIR/$(basename "$package")"
      cp -a "$package" "$LAYOUTS_DIR/"
    done
  fi

  for package in "$SRC_DIR"/translations/zh_CN/*.mo; do
    [[ -f "$package" ]] || continue
    cp -a "$package" "$LOCALE_DIR/zh_CN/LC_MESSAGES/"
  done
}

declare -a requested_colors=()
declare -a requested_pcolors=()
declare -a requested_windows=()

while (( $# > 0 )); do
  case "$1" in
    -c|--color)
      require_value "$@"
      shift
      while (( $# > 0 )) && [[ "$1" != -* ]]; do
        case "$1" in
          light) requested_colors+=(""); requested_pcolors+=("");;
          alt) requested_colors+=(""); requested_pcolors+=("-alt");;
          dark) requested_colors+=("-dark"); requested_pcolors+=("-dark");;
          *) die "Unknown color variant '$1'";;
        esac
        shift
      done
      ;;
    -w|--window)
      require_value "$@"
      shift
      while (( $# > 0 )) && [[ "$1" != -* ]]; do
        case "$1" in
          default) requested_windows+=("");;
          opaque) requested_windows+=("-opaque"); install_opaque=true;;
          sharp) requested_windows+=("-sharp");;
          *) die "Unknown window variant '$1'";;
        esac
        shift
      done
      ;;
    --sharp) requested_windows+=("-sharp"); shift;;
    --opaque) requested_windows+=("-opaque"); install_opaque=true; shift;;
    --no-gtk) install_gtk=false; shift;;
    --firefox)
      install_firefox=true
      shift
      case "${1:-}" in
        full|buttons) firefox_mode="$1"; shift;;
      esac
      ;;
    -h|--help) usage; exit 0;;
    *) die "Unknown option '$1' (use --help)";;
  esac
done

if (( ${#requested_colors[@]} == 0 )); then
  requested_colors=("${COLOR_VARIANTS[@]}")
  requested_pcolors=("${PCOLOR_VARIANTS[@]}")
fi
if (( ${#requested_windows[@]} == 0 )); then
  requested_windows=("")
fi

mkdir -p "$AURORAE_DIR" "$SCHEMES_DIR" "$PLASMA_DIR" "$LOOKFEEL_DIR" \
  "$KVANTUM_DIR" "$WALLPAPER_DIR" "$ICONS_DIR"

printf "Installing '%s KDE themes'...\n" "$THEME_NAME"
install_kvantum_and_wallpapers
install_icons
install_color_schemes
install_addons

for pcolor in "${requested_pcolors[@]}"; do
  install_plasma_theme "$pcolor"
  install_look_and_feel "$pcolor"
done

for color in "${requested_colors[@]}"; do
  for window in "${requested_windows[@]}"; do
    for scale in "${SCALE_VARIANTS[@]}"; do
      install_aurorae "$color" "$window" "$scale"
    done
  done
done

if [[ "${install_gtk:-true}" == true ]]; then
  printf "Installing '%s GTK theme'...\n" "$THEME_NAME"
  install_gtk_theme
fi

if [[ "${install_firefox:-false}" == true ]]; then
  printf "Installing '%s Firefox theme'...\n" "$THEME_NAME"
  install_firefox_theme
fi

printf "Install finished.\n"
