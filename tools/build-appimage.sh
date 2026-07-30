#!/usr/bin/env bash
set -Eeuo pipefail

FFUI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FFUI_BUNDLE="$FFUI_ROOT/build/linux/x64/release/bundle"
FFUI_EXPORT="$FFUI_ROOT/export"
FFUI_MANIFEST_DIRECTORY="$FFUI_ROOT/build/release-manifests"
FFUI_WORK="$(mktemp -d -t ffmpeg-ui-appimage-XXXXXXXX)"
FFUI_APPDIR="$FFUI_WORK/AppDir"
FFUI_PACKAGER=""
FFUI_PACKAGER_KIND=""
FFUI_BUILD_MODE="release"

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

usage() {
    cat <<'EOF'
Użycie: tools/build-appimage.sh [--dev]

Domyślnie tworzy publiczny AppImage przy użyciu linuxdeploy, który zbiera
kwalifikujące się biblioteki aplikacji. Tryb --dev pozwala użyć appimagetool
wyłącznie do lokalnego testu gotowego bundle Fluttera.
EOF
}

while (($# > 0)); do
    case "$1" in
        --dev)
            FFUI_BUILD_MODE="dev"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            die "Nieznana opcja: $1"
            ;;
    esac
    shift
done

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
elif [[ "$FFUI_BUILD_MODE" == "dev" ]]; then
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
else
    die "Nie znaleziono linuxdeploy. Publiczny AppImage wymaga linuxdeploy; do lokalnego testu użyj --dev."
fi

[[ -f "$FFUI_ROOT/packaging/io.github.Morloook.FFmpegUI.desktop" ]] || die \
    "Brak packaging/io.github.Morloook.FFmpegUI.desktop."
[[ -f "$FFUI_ROOT/packaging/io.github.Morloook.FFmpegUI.appdata.xml" ]] || die \
    "Brak packaging/io.github.Morloook.FFmpegUI.appdata.xml."
[[ -x "$FFUI_ROOT/packaging/AppRun" ]] || die \
    "Brak wykonywalnego packaging/AppRun."
[[ -f "$FFUI_ROOT/assets/icons/ffmpeg_ui.svg" ]] || die \
    "Brak assets/icons/ffmpeg_ui.svg."
command -v unsquashfs >/dev/null 2>&1 || die \
    "Brak unsquashfs (pakiet squashfs-tools), potrzebnego do walidacji AppImage."

if command -v appstreamcli >/dev/null 2>&1; then
    printf '==> Walidacja metadanych AppStream\n'
    appstreamcli validate --no-net \
        "$FFUI_ROOT/packaging/io.github.Morloook.FFmpegUI.appdata.xml"
else
    printf 'Uwaga: brak appstreamcli; pominięto walidację metadanych AppStream.\n'
fi

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
mkdir -p "$FFUI_APPDIR/usr/bin" \
    "$FFUI_APPDIR/usr/share/applications" \
    "$FFUI_APPDIR/usr/share/metainfo"
cp -a "$FFUI_BUNDLE/." "$FFUI_APPDIR/usr/bin/"
cp "$FFUI_ROOT/packaging/io.github.Morloook.FFmpegUI.desktop" \
    "$FFUI_APPDIR/usr/share/applications/io.github.Morloook.FFmpegUI.desktop"
cp "$FFUI_ROOT/packaging/io.github.Morloook.FFmpegUI.appdata.xml" \
    "$FFUI_APPDIR/usr/share/metainfo/io.github.Morloook.FFmpegUI.appdata.xml"
cp "$FFUI_ROOT/packaging/io.github.Morloook.FFmpegUI.desktop" \
    "$FFUI_APPDIR/io.github.Morloook.FFmpegUI.desktop"
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
    # LINUXDEPLOY_OUTPUT_VERSION i APPIMAGE_EXTRACT_AND_RUN są publicznym
    # interfejsem linuxdeploy.
    LINUXDEPLOY_OUTPUT_VERSION="$FFUI_VERSION" APPIMAGE_EXTRACT_AND_RUN=1 "$FFUI_PACKAGER" \
        --appdir "$FFUI_APPDIR" \
        --desktop-file "$FFUI_ROOT/packaging/io.github.Morloook.FFmpegUI.desktop" \
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
    printf 'Tryb deweloperski: appimagetool nie zbiera dodatkowych bibliotek systemowych.\n'
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

printf '\n==> Walidacja gotowego AppImage\n'
FFUI_SQUASHFS_OFFSET="$("$FFUI_OUTPUT" --appimage-offset)"
[[ "$FFUI_SQUASHFS_OFFSET" =~ ^[0-9]+$ ]] || die \
    "Nie udało się odczytać offsetu SquashFS z gotowego AppImage."
unsquashfs -s -o "$FFUI_SQUASHFS_OFFSET" "$FFUI_OUTPUT" >/dev/null

mkdir -p "$FFUI_MANIFEST_DIRECTORY"
printf '%s\n' "$FFUI_VERSION" > "$FFUI_MANIFEST_DIRECTORY/linux.version"

printf '\nGotowy pojedynczy plik AppImage:\n%s\n' "$FFUI_OUTPUT"
printf 'Zapisano metadane wersji buildu Linux poza export/: %s\n' "$FFUI_VERSION"
