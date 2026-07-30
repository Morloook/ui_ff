#!/usr/bin/env bash
set -Eeuo pipefail

FFUI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FFUI_BUNDLE="$FFUI_ROOT/build/linux/x64/release/bundle"
FFUI_EXPORT="$FFUI_ROOT/export"
FFUI_WORK="$(mktemp -d -t ffmpeg-ui-appimage-XXXXXXXX)"
FFUI_APPDIR="$FFUI_WORK/AppDir"
FFUI_PACKAGER=""
FFUI_PACKAGER_KIND=""

on_error() {
    local exit_code=$?
    printf '\nBłąd: budowanie AppImage przerwane w linii %s (kod %s).\n' \
        "${BASH_LINENO[0]}" "$exit_code" >&2
    exit "$exit_code"
}

cleanup() {
    case "$FFUI_WORK" in
        /tmp/ffmpeg-ui-appimage-*) rm -rf -- "$FFUI_WORK" ;;
        *) printf 'Pomijam usunięcie nieoczekiwanej ścieżki: %s\n' "$FFUI_WORK" >&2 ;;
    esac
}
trap cleanup EXIT
trap on_error ERR

die() {
    printf 'Błąd: %s\n' "$1" >&2
    exit 1
}

command -v flutter >/dev/null 2>&1 || die "Nie znaleziono Fluttera w PATH."

FFUI_LINUXDEPLOY="${FFUI_LINUXDEPLOY:-}"
FFUI_APPIMAGETOOL="${FFUI_APPIMAGETOOL:-}"
if [[ -z "$FFUI_LINUXDEPLOY" ]] && command -v linuxdeploy >/dev/null 2>&1; then
    FFUI_LINUXDEPLOY="$(command -v linuxdeploy)"
elif [[ -z "$FFUI_LINUXDEPLOY" ]] && command -v linuxdeploy-x86_64.AppImage >/dev/null 2>&1; then
    FFUI_LINUXDEPLOY="$(command -v linuxdeploy-x86_64.AppImage)"
elif [[ -z "$FFUI_LINUXDEPLOY" && -x "$FFUI_ROOT/tools/linuxdeploy-x86_64.AppImage" ]]; then
    FFUI_LINUXDEPLOY="$FFUI_ROOT/tools/linuxdeploy-x86_64.AppImage"
fi

if [[ -n "$FFUI_LINUXDEPLOY" ]]; then
    [[ -x "$FFUI_LINUXDEPLOY" ]] || die \
        "FFUI_LINUXDEPLOY nie wskazuje pliku wykonywalnego: $FFUI_LINUXDEPLOY"
    FFUI_PACKAGER="$FFUI_LINUXDEPLOY"
    FFUI_PACKAGER_KIND="linuxdeploy"
else
    if [[ -z "$FFUI_APPIMAGETOOL" ]] && command -v appimagetool >/dev/null 2>&1; then
        FFUI_APPIMAGETOOL="$(command -v appimagetool)"
    elif [[ -z "$FFUI_APPIMAGETOOL" ]] && command -v appimagetool-x86_64.AppImage >/dev/null 2>&1; then
        FFUI_APPIMAGETOOL="$(command -v appimagetool-x86_64.AppImage)"
    elif [[ -z "$FFUI_APPIMAGETOOL" && -x "$FFUI_ROOT/tools/appimagetool-x86_64.AppImage" ]]; then
        FFUI_APPIMAGETOOL="$FFUI_ROOT/tools/appimagetool-x86_64.AppImage"
    fi
    [[ -n "$FFUI_APPIMAGETOOL" ]] || die \
        "Nie znaleziono linuxdeploy ani appimagetool. Zainstaluj jedno z tych narzędzi."
    [[ -x "$FFUI_APPIMAGETOOL" ]] || die \
        "FFUI_APPIMAGETOOL nie wskazuje pliku wykonywalnego: $FFUI_APPIMAGETOOL"
    FFUI_PACKAGER="$FFUI_APPIMAGETOOL"
    FFUI_PACKAGER_KIND="appimagetool"
fi

[[ -f "$FFUI_ROOT/packaging/ffmpeg-ui.desktop" ]] || die \
    "Brak packaging/ffmpeg-ui.desktop."
[[ -x "$FFUI_ROOT/packaging/AppRun" ]] || die \
    "Brak wykonywalnego packaging/AppRun."
[[ -f "$FFUI_ROOT/assets/icons/ffmpeg_ui.svg" ]] || die \
    "Brak assets/icons/ffmpeg_ui.svg."

printf 'Narzędzie pakujące: %s (%s)\n' "$FFUI_PACKAGER_KIND" "$FFUI_PACKAGER"
printf 'Katalog projektu: %s\n\n' "$FFUI_ROOT"

cd "$FFUI_ROOT"
printf '==> Pobieranie zależności Fluttera\n'
flutter pub get
if [[ "${FFUI_SKIP_CHECKS:-0}" != "1" ]]; then
    printf '\n==> Analiza statyczna\n'
    flutter analyze
    printf '\n==> Testy\n'
    flutter test
else
    printf '\n==> Pominięto analizę i testy (FFUI_SKIP_CHECKS=1)\n'
fi
printf '\n==> Build Linux release\n'
flutter build linux --release

[[ -x "$FFUI_BUNDLE/ffmpeg_ui" ]] || die "Brak zbudowanego pliku ffmpeg_ui."
mkdir -p "$FFUI_APPDIR/usr/bin" "$FFUI_APPDIR/usr/share/applications"
cp -a "$FFUI_BUNDLE/." "$FFUI_APPDIR/usr/bin/"
cp "$FFUI_ROOT/packaging/ffmpeg-ui.desktop" \
    "$FFUI_APPDIR/usr/share/applications/ffmpeg-ui.desktop"
cp "$FFUI_ROOT/packaging/ffmpeg-ui.desktop" "$FFUI_APPDIR/ffmpeg-ui.desktop"
cp "$FFUI_ROOT/packaging/AppRun" "$FFUI_APPDIR/AppRun"
chmod 0755 "$FFUI_APPDIR/AppRun"
cp "$FFUI_ROOT/assets/icons/ffmpeg_ui.svg" "$FFUI_APPDIR/ffmpeg_ui.svg"
ln -s "ffmpeg_ui.svg" "$FFUI_APPDIR/.DirIcon"

mkdir -p "$FFUI_EXPORT"
FFUI_VERSION="$(
    sed -n 's/^version:[[:space:]]*\([^+[:space:]]*\).*/\1/p' \
        "$FFUI_ROOT/pubspec.yaml"
)"
[[ -n "$FFUI_VERSION" ]] || die "Nie udało się odczytać wersji z pubspec.yaml."
FFUI_ARCH="$(uname -m)"
case "$FFUI_ARCH" in
    x86_64|aarch64) ;;
    *) die "Nieobsługiwana architektura AppImage: $FFUI_ARCH" ;;
esac
FFUI_OUTPUT="$FFUI_EXPORT/FFmpeg_UI-$FFUI_ARCH.AppImage"

cd "$FFUI_EXPORT"
shopt -s nullglob
FFUI_OLD_IMAGES=("$FFUI_EXPORT"/*.AppImage)
if ((${#FFUI_OLD_IMAGES[@]} > 0)); then
    printf '\n==> Usuwanie poprzednich plików AppImage z katalogu export\n'
    rm -f -- "${FFUI_OLD_IMAGES[@]}"
fi
shopt -u nullglob

printf '\n==> Pakowanie AppImage\n'
if [[ "$FFUI_PACKAGER_KIND" == "linuxdeploy" ]]; then
    # VERSION i APPIMAGE_EXTRACT_AND_RUN są publicznym interfejsem linuxdeploy.
    VERSION="$FFUI_VERSION" APPIMAGE_EXTRACT_AND_RUN=1 "$FFUI_PACKAGER" \
        --appdir "$FFUI_APPDIR" \
        --desktop-file "$FFUI_ROOT/packaging/ffmpeg-ui.desktop" \
        --icon-file "$FFUI_ROOT/assets/icons/ffmpeg_ui.svg" \
        --output appimage

    mapfile -t FFUI_LINUXDEPLOY_RESULTS < <(
        find "$FFUI_EXPORT" -maxdepth 1 -type f -name '*.AppImage' -print
    )
    ((${#FFUI_LINUXDEPLOY_RESULTS[@]} == 1)) || die \
        "linuxdeploy powinien utworzyć dokładnie jeden plik AppImage."
    if [[ "${FFUI_LINUXDEPLOY_RESULTS[0]}" != "$FFUI_OUTPUT" ]]; then
        mv -- "${FFUI_LINUXDEPLOY_RESULTS[0]}" "$FFUI_OUTPUT"
    fi
else
    printf 'Uwaga: appimagetool pakuje gotowy bundle, ale nie zbiera dodatkowych '
    printf 'bibliotek systemowych. Do publicznej, przenośnej paczki użyj linuxdeploy.\n'
    ARCH="$FFUI_ARCH" APPIMAGE_EXTRACT_AND_RUN=1 "$FFUI_PACKAGER" \
        "$FFUI_APPDIR" "$FFUI_OUTPUT"
fi

mapfile -t FFUI_RESULTS < <(
    find "$FFUI_EXPORT" -maxdepth 1 -type f -name '*.AppImage' -print | sort
)
((${#FFUI_RESULTS[@]} == 1)) || die \
    "Pakowanie powinno zakończyć się dokładnie jednym plikiem AppImage."
[[ "${FFUI_RESULTS[0]}" == "$FFUI_OUTPUT" ]] || die \
    "Końcowy plik AppImage ma nieoczekiwaną nazwę: ${FFUI_RESULTS[0]}"

printf '\nGotowy pojedynczy plik AppImage:\n%s\n' "$FFUI_OUTPUT"
