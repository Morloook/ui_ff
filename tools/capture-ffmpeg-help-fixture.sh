#!/usr/bin/env bash
# Captures a complete FFmpeg parser-regression profile. Usage:
# ./tools/capture-ffmpeg-help-fixture.sh profile-name /path/to/ffmpeg

set -Eeuo pipefail

FFUI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FFUI_PROFILE="${1:-}"
FFUI_BINARY="${2:-ffmpeg}"

die() {
    printf 'Błąd: %s\n' "$1" >&2
    exit 1
}

[[ -n "$FFUI_PROFILE" ]] || die 'Użycie: capture-ffmpeg-help-fixture.sh nazwa-profilu [/ścieżka/do/ffmpeg]'
[[ "$FFUI_PROFILE" =~ ^[A-Za-z0-9._-]+$ ]] || die 'Nazwa profilu może zawierać tylko litery, cyfry, kropki, podkreślenia i myślniki.'
command -v "$FFUI_BINARY" >/dev/null 2>&1 || die "Nie znaleziono FFmpeg: $FFUI_BINARY"

FFUI_TARGET="$FFUI_ROOT/test/fixtures/help_parser/$FFUI_PROFILE"
mkdir -p "$FFUI_TARGET"

capture() {
    local name="$1"
    shift
    printf '==> %s\n' "$name"
    "$FFUI_BINARY" "$@" > "$FFUI_TARGET/$name.txt" 2>&1
}

capture version -version
capture full_help -h full
capture encoders -hide_banner -encoders
capture decoders -hide_banner -decoders
capture filters -hide_banner -filters
capture formats -hide_banner -formats
capture protocols -hide_banner -protocols
capture hwaccels -hide_banner -hwaccels
capture bsfs -hide_banner -bsfs

printf 'Zapisano pełny profil parsera: %s\n' "$FFUI_TARGET"
