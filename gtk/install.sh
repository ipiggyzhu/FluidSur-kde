#!/usr/bin/env bash
#
# FluidSur GTK theme installer.
#
# Builds the GTK 2/3/4 side of FluidSur so that GTK applications running on
# Plasma (Firefox, Nautilus-style file pickers, GIMP, ...) pick up the same
# BigSur-style window buttons and widget styling that the Aurorae decoration
# already provides to native KDE applications.
#
# Scope note: this installer intentionally covers GTK only. GNOME Shell,
# Cinnamon, Xfwm4 and Metacity variants are not part of FluidSur, which
# targets Plasma.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SRC_DIR="${REPO_DIR}/src"
BUILD_DIR="${REPO_DIR}/.build"

NAME="FluidSur"
DEST="${HOME}/.themes"
COLORS=("Light" "Dark")
THEME=""          # accent: '' (default) or -blue -green -grey -orange -pink -purple -red -yellow
SCHEME=""         # '' (standard) or -nord
ALT=""            # titlebutton style: '' (default) or -alt
REMOVE="false"
LIBADWAITA="false"
APPLY="false"

SASSC_OPT="-M -t expanded"

# ── output helpers ────────────────────────────────────────────────────────────
say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok()   { printf '    \033[32m✔\033[0m %s\n' "$*"; }
err()  { printf '    \033[31m✘\033[0m %s\n' "$*" >&2; }

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

  -d, --dest DIR      Install directory (default: ${HOME}/.themes)
  -c, --color VARIANT light | dark | all          (default: all)
  -t, --theme ACCENT  default | blue | green | grey | orange | pink |
                      purple | red | yellow       (default: default)
  -s, --scheme NAME   standard | nord             (default: standard)
  -a, --alt           Use the alternative (symbol-less) window buttons
  -l, --libadwaita    Also force the theme onto libadwaita (GTK4) applications,
                      which otherwise ignore the system theme entirely
      --apply         Select the freshly built theme in Plasma as well, through
                      kde-gtk-config, rather than only writing the files. Use
                      this instead of editing ~/.config/gtk-3.0/settings.ini by
                      hand; see the "Applying it" section of gtk/README.md.
  -r, --remove        Uninstall instead of install
  -h, --help          Show this message
EOF
}

# ── argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dest)   DEST="$2"; shift 2 ;;
    -c|--color)
      case "$2" in
        light) COLORS=("Light") ;;
        dark)  COLORS=("Dark") ;;
        all)   COLORS=("Light" "Dark") ;;
        *) err "unknown color variant: $2"; exit 1 ;;
      esac
      shift 2 ;;
    -t|--theme)  [[ "$2" == "default" ]] && THEME="" || THEME="-$2"; shift 2 ;;
    -s|--scheme) [[ "$2" == "standard" ]] && SCHEME="" || SCHEME="-$2"; shift 2 ;;
    -a|--alt)    ALT="-alt"; shift ;;
    -l|--libadwaita) LIBADWAITA="true"; shift ;;
    --apply)     APPLY="true"; shift ;;
    -r|--remove) REMOVE="true"; shift ;;
    -h|--help)   usage; exit 0 ;;
    *) err "unknown option: $1"; usage; exit 1 ;;
  esac
done

# ── dependency check ──────────────────────────────────────────────────────────
# Only building needs these, so the check lives in main() after the uninstall
# branch: removing an installed theme must work on a machine without a toolchain.
check_deps() {
  local missing=()
  command -v sassc >/dev/null                  || missing+=("sassc")
  command -v glib-compile-resources >/dev/null || missing+=("glib2-devel (glib-compile-resources)")
  if [[ ${#missing[@]} -gt 0 ]]; then
    err "missing build dependencies: ${missing[*]}"
    echo "    Fedora: sudo dnf install sassc glib2-devel"
    exit 1
  fi
}

# ── sass option headers ───────────────────────────────────────────────────────
# _variables.scss and _colors.scss import these two "-temp" files. Upstream
# regenerates them per build so that CLI options can feed into the stylesheet;
# we do the same rather than shipping stale copies.
write_sass_options() {
  local theme="${THEME:-default}"; theme="${theme#-}"
  local scheme="${SCHEME:-standard}"; scheme="${scheme#-}"

  sed -e "s/^\$theme:.*/\$theme: '${theme}';/" \
      -e "s/^\$scheme:.*/\$scheme: '${scheme}';/" \
      "${SRC_DIR}/sass/_gtk-base.scss" > "${SRC_DIR}/sass/_gtk-base-temp.scss"

  cp -f "${SRC_DIR}/sass/_theme-options.scss" "${SRC_DIR}/sass/_theme-options-temp.scss"
}

# ── build one colour variant ──────────────────────────────────────────────────
build_variant() {
  local color="-$1"                                   # -Light | -Dark
  local target="${DEST}/${NAME}${color}${THEME}${SCHEME}"
  local icon_theme="${NAME}"
  [[ "${color}" == "-Dark" ]] && icon_theme="${NAME}-dark"

  rm -rf "${target}"
  mkdir -p "${target}"

  # index.theme -------------------------------------------------------------
  cat > "${target}/index.theme" <<EOF
[Desktop Entry]
Type=X-GNOME-Metatheme
Name=${NAME}${color}${THEME}${SCHEME}
Comment=A macOS BigSur-like GTK theme, the GTK half of the FluidSur desktop
Encoding=UTF-8

[X-GNOME-Metatheme]
GtkTheme=${NAME}${color}${THEME}${SCHEME}
IconTheme=${icon_theme}
CursorTheme=${NAME}-cursors
ButtonLayout=close,minimize,maximize:menu
EOF

  # GTK 3 and GTK 4 ---------------------------------------------------------
  # Both are shipped as a gresource bundle; the on-disk gtk.css is only a
  # one-line @import pointing into it. That is what lets the window-button
  # PNGs be referenced by relative path from the compiled CSS.
  local gtk_ver
  for gtk_ver in "3.0" "4.0"; do
    local tmp="${BUILD_DIR}/gtk-${gtk_ver}${color}${THEME}${SCHEME}"
    rm -rf "${tmp}"; mkdir -p "${tmp}"

    cp -r "${SRC_DIR}/assets/gtk/common-assets/assets"                  "${tmp}"
    cp -r "${SRC_DIR}/assets/gtk/common-assets/sidebar-assets/"*".png"  "${tmp}/assets"
    cp -r "${SRC_DIR}/assets/gtk/scalable"                              "${tmp}/assets"
    # the window buttons
    cp -r "${SRC_DIR}/assets/gtk/windows-assets/titlebutton${ALT}${SCHEME}" "${tmp}/windows-assets"

    sassc ${SASSC_OPT} "${SRC_DIR}/main/gtk-${gtk_ver}/gtk${color}.scss" "${tmp}/gtk.css"    || return 1
    sassc ${SASSC_OPT} "${SRC_DIR}/main/gtk-${gtk_ver}/gtk-Dark.scss"    "${tmp}/gtk-dark.css" || return 1

    mkdir -p "${target}/gtk-${gtk_ver}"
    cp -f "${SRC_DIR}/assets/gtk/thumbnails/thumbnail${color}${THEME}${SCHEME}.png" \
          "${target}/gtk-${gtk_ver}/thumbnail.png"
    echo '@import url("resource:///org/gnome/theme/gtk.css");'      > "${target}/gtk-${gtk_ver}/gtk.css"
    echo '@import url("resource:///org/gnome/theme/gtk-dark.css");' > "${target}/gtk-${gtk_ver}/gtk-dark.css"

    glib-compile-resources --sourcedir="${tmp}" \
      --target="${target}/gtk-${gtk_ver}/gtk.gresource" \
      "${SRC_DIR}/main/gtk-${gtk_ver}/gtk.gresource.xml" || return 1
  done

  # GTK 2 -------------------------------------------------------------------
  mkdir -p "${target}/gtk-2.0"
  cp -f "${SRC_DIR}/main/gtk-2.0/gtkrc${color}${THEME}${SCHEME}"      "${target}/gtk-2.0/gtkrc"
  cp -f "${SRC_DIR}/main/gtk-2.0/menubar-toolbar${color}.rc"          "${target}/gtk-2.0/menubar-toolbar.rc"
  cp -f "${SRC_DIR}/main/gtk-2.0/common/"*".rc"                       "${target}/gtk-2.0"
  cp -r "${SRC_DIR}/assets/gtk-2.0/assets-common${color}${SCHEME}"    "${target}/gtk-2.0/assets"
  cp -f "${SRC_DIR}/assets/gtk-2.0/assets${color}${THEME}${SCHEME}/"*".png" "${target}/gtk-2.0/assets"

  return 0
}

# ── libadwaita override ───────────────────────────────────────────────────────
# GTK4 applications built on libadwaita ignore the selected system theme by
# design. The only supported way to restyle them is to drop a stylesheet into
# ~/.config/gtk-4.0, which libadwaita does read. Assets go in as plain files
# there — a gresource bundle would not be registered for those applications.
LIBADWAITA_DIR="${HOME}/.config/gtk-4.0"

install_libadwaita() {
  local color="-$1"

  mkdir -p "${LIBADWAITA_DIR}"
  rm -rf "${LIBADWAITA_DIR}/"{gtk.css,gtk-dark.css,gtk-Light.css,gtk-Dark.css,assets,windows-assets}

  sassc ${SASSC_OPT} "${SRC_DIR}/main/gtk-4.0/gtk-Light.scss" "${LIBADWAITA_DIR}/gtk-Light.css" || return 1
  sassc ${SASSC_OPT} "${SRC_DIR}/main/gtk-4.0/gtk-Dark.scss"  "${LIBADWAITA_DIR}/gtk-Dark.css"  || return 1
  ln -sf "${LIBADWAITA_DIR}/gtk${color}.css" "${LIBADWAITA_DIR}/gtk.css"
  ln -sf "${LIBADWAITA_DIR}/gtk-Dark.css"    "${LIBADWAITA_DIR}/gtk-dark.css"

  cp -r "${SRC_DIR}/assets/gtk/common-assets/assets"                  "${LIBADWAITA_DIR}"
  cp -r "${SRC_DIR}/assets/gtk/common-assets/sidebar-assets/"*".png"  "${LIBADWAITA_DIR}/assets"
  cp -r "${SRC_DIR}/assets/gtk/scalable"                              "${LIBADWAITA_DIR}/assets"
  cp -r "${SRC_DIR}/assets/gtk/windows-assets/titlebutton${ALT}${SCHEME}" "${LIBADWAITA_DIR}/windows-assets"
}

remove_libadwaita() {
  rm -rf "${LIBADWAITA_DIR}/"{gtk.css,gtk-dark.css,gtk-Light.css,gtk-Dark.css,assets,windows-assets}
}

# ── select the theme in Plasma ────────────────────────────────────────────────
# Writing gtk-theme-name into ~/.config/gtk-3.0/settings.ini by hand looks like
# it works, but it only half applies: Plasma keeps its own record of the GTK
# theme and feeds XSETTINGS from that, so GTK applications under XWayland go on
# using the previous theme while native Wayland ones switch. Going through
# kde-gtk-config's D-Bus service sets both.
#
# It also matters for the window buttons. Older kde-gtk-config wrote a
# ~/.config/gtk-3.0/window_decorations.css that replaces every GTK titlebutton
# image with a Qt rasterisation of the current Aurorae buttons, loaded at a
# provider priority above both the theme and the user stylesheet. Qt's SVG
# generator emits a default black pen on those fill-only circles, so the traffic
# lights come out with a heavy dark ring — most visible in Chrome, which also
# forces background-size:contain and so scales them up. Plasma 6 drops that file
# when the GTK theme is set through this service, which is the supported way to
# be rid of it.
apply_theme() {
  local theme="${NAME}-${COLORS[0]}${THEME}${SCHEME}"
  local qdbus=""

  for candidate in qdbus-qt6 qdbus6 qdbus; do
    if command -v "${candidate}" >/dev/null; then
      qdbus="${candidate}"
      break
    fi
  done

  if [[ -z "${qdbus}" ]]; then
    err "no qdbus binary found; select '${theme}' in System Settings instead"
    return 1
  fi

  if ! "${qdbus}" org.kde.GtkConfig /GtkConfig org.kde.GtkConfig.setGtkTheme \
       "${theme}" >/dev/null 2>&1; then
    err "kde-gtk-config would not take '${theme}' (is Plasma running?)"
    return 1
  fi

  ok "selected ${theme} in Plasma"
  return 0
}

# ── main ──────────────────────────────────────────────────────────────────────
if [[ "${REMOVE}" == "true" ]]; then
  say "Removing FluidSur GTK themes from ${DEST}"
  for color in "${COLORS[@]}"; do
    target="${DEST}/${NAME}-${color}${THEME}${SCHEME}"
    rm -rf "${target}" && ok "removed ${target}"
  done
  remove_libadwaita && ok "removed libadwaita override from ${LIBADWAITA_DIR}"
  exit 0
fi

say "Building FluidSur GTK theme"
check_deps
mkdir -p "${DEST}" "${BUILD_DIR}"
write_sass_options

failed=0
for color in "${COLORS[@]}"; do
  if build_variant "${color}"; then
    ok "${DEST}/${NAME}-${color}${THEME}${SCHEME}"
  else
    err "failed to build ${NAME}-${color}${THEME}${SCHEME}"
    failed=1
  fi
done

rm -rf "${BUILD_DIR}"

if [[ "${LIBADWAITA}" == "true" ]]; then
  if install_libadwaita "${COLORS[0]}"; then
    ok "libadwaita override installed in ${LIBADWAITA_DIR}"
  else
    err "failed to install the libadwaita override"
    failed=1
  fi
fi

if [[ ${failed} -ne 0 ]]; then
  exit 1
fi

if [[ "${APPLY}" == "true" ]]; then
  apply_theme || failed=1
fi

say "Done"
if [[ "${APPLY}" == "true" && ${failed} -eq 0 ]]; then
  cat <<EOF
    ${NAME}-${COLORS[0]}${THEME}${SCHEME} is now the GTK theme. Applications
    already running keep the old one until they are restarted.

    GTK4 / libadwaita applications additionally need the theme linked into
    ~/.config/gtk-4.0; see gtk/README.md.
EOF
else
  cat <<EOF
    Select the theme in System Settings > Appearance > Application Style >
    Configure GNOME/GTK Application Style, or re-run with --apply:

      $(basename "$0") --apply

    Setting gtk-theme-name in ~/.config/gtk-3.0/settings.ini by hand is not
    enough on Plasma — see the "Applying it" section of gtk/README.md.

    GTK4 / libadwaita applications additionally need the theme linked into
    ~/.config/gtk-4.0; see gtk/README.md.
EOF
fi

exit ${failed}
