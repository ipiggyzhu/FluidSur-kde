#!/usr/bin/env bash
#
# FluidSur KDE network installer.
#
# Downloads a snapshot of the theme into a temporary directory, hands it to the
# repository's own install.sh, and cleans up afterwards. Every option is passed
# through, so this is equivalent to cloning the repository and running
# ./install.sh yourself.
#
#   curl -fsSL https://raw.githubusercontent.com/ipiggyzhu/FluidSur-kde/main/net-install.sh | bash
#   curl -fsSL .../net-install.sh | bash -s -- --color dark --apply
#
# Kept deliberately small and dependency-light: bash, curl or wget, and tar.

set -euo pipefail

readonly REPO="ipiggyzhu/FluidSur-kde"
readonly DEFAULT_REF="main"
REF="${FLUIDSUR_REF:-$DEFAULT_REF}"

WORKDIR=""

cleanup() {
  [[ -n "$WORKDIR" && -d "$WORKDIR" ]] && rm -rf -- "$WORKDIR"
}
trap cleanup EXIT INT TERM

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

note() {
  printf '==> %s\n' "$*"
}

# curl and wget disagree on flags but both can stream to stdout.
fetch() {
  local url="$1"

  if command -v curl >/dev/null; then
    curl -fsSL --retry 3 --retry-delay 2 -- "$url"
  elif command -v wget >/dev/null; then
    wget -qO- --tries=3 -- "$url"
  else
    die "need curl or wget"
  fi
}

require_tools() {
  local missing=()

  command -v tar >/dev/null || missing+=("tar")
  command -v curl >/dev/null || command -v wget >/dev/null || missing+=("curl or wget")

  (( ${#missing[@]} == 0 )) || die "missing: ${missing[*]}"
}

warn_unless_plasma() {
  # Not fatal. Installing from a TTY, a different desktop, or a live image is
  # legitimate; the files simply sit unused until Plasma reads them.
  if [[ -z "${KDE_FULL_SESSION:-}" ]] \
    && [[ "${XDG_CURRENT_DESKTOP:-}" != *KDE* ]] \
    && ! command -v plasmashell >/dev/null; then
    printf 'Note: no KDE Plasma detected. Installing anyway.\n'
  fi
}

main() {
  require_tools
  warn_unless_plasma

  WORKDIR="$(mktemp -d)"

  note "Downloading FluidSur ($REF)"
  if ! fetch "https://codeload.github.com/$REPO/tar.gz/$REF" \
    | tar -xz -C "$WORKDIR" --strip-components=1; then
    die "download or extract failed for ref '$REF'"
  fi

  [[ -f "$WORKDIR/install.sh" ]] || die "archive has no install.sh"

  note "Installing"
  bash "$WORKDIR/install.sh" "$@"
}

main "$@"
