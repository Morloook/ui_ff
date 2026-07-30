#!/usr/bin/env bash
set -Eeuo pipefail

# Publikuje pojedynczy commit "main" oraz GitHub Release z aktualnymi
# artefaktami. Skrypt celowo nie buduje pakietów: publikuje wyłącznie wcześniej
# zweryfikowane buildy znajdujące się w export/.

FFUI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FFUI_REMOTE="${FFUI_REMOTE:-origin}"
FFUI_BRANCH="main"
FFUI_COMMIT_MESSAGE="main"
FFUI_EXPORT="$FFUI_ROOT/export"
FFUI_WINDOWS_EXPORT="$FFUI_EXPORT/FFmpeg_UI-Windows"
FFUI_MANIFEST_DIRECTORY="$FFUI_ROOT/build/release-manifests"
FFUI_LINUX_VERSION_FILE="$FFUI_MANIFEST_DIRECTORY/linux.version"
FFUI_WINDOWS_VERSION_FILE="$FFUI_MANIFEST_DIRECTORY/windows.version"
FFUI_RELEASE_WORK=""

die() {
  printf 'Błąd: %s\n' "$1" >&2
  exit 1
}

cleanup() {
  if [[ -n "$FFUI_RELEASE_WORK" && -d "$FFUI_RELEASE_WORK" ]]; then
    rm -rf -- "$FFUI_RELEASE_WORK"
  fi
}
trap cleanup EXIT

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Brak wymaganego programu: $1"
}

read_version() {
  local value
  value="$(sed -n 's/^version:[[:space:]]*\([^+[:space:]]*\).*/\1/p' "$FFUI_ROOT/pubspec.yaml")"
  [[ -n "$value" ]] || die "Nie udało się odczytać wersji z pubspec.yaml."
  printf '%s\n' "$value"
}

read_ssot_version() {
  local value
  value="$(sed -n "s/.*applicationVersion = '\([^']*\)'.*/\1/p" "$FFUI_ROOT/lib/core/app_config.dart")"
  [[ -n "$value" ]] || die "Nie udało się odczytać applicationVersion z app_config.dart."
  printf '%s\n' "$value"
}

validate_build_version() {
  local platform="$1"
  local version_file="$2"
  local expected_version="$3"
  local actual_version
  [[ -f "$version_file" ]] || die \
    "Brak manifestu wersji buildu $platform: $version_file. Uruchom właściwy skrypt budowania ponownie."
  actual_version="$(tr -d '[:space:]' < "$version_file")"
  [[ "$actual_version" == "$expected_version" ]] || die \
    "Build $platform ma wersję '$actual_version', a kod ma '$expected_version'. Zbuduj go ponownie."
}

cd "$FFUI_ROOT"

require_command git

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die \
  "Ten skrypt musi zostać uruchomiony wewnątrz repozytorium Git."

[[ "$(git rev-parse --show-toplevel)" == "$FFUI_ROOT" ]] || die \
  "Uruchom skrypt z jego katalogu projektu, bez kopiowania do innego repozytorium."
[[ "$(git branch --show-current)" == "$FFUI_BRANCH" ]] || die \
  "Aktywna gałąź musi nazywać się '$FFUI_BRANCH'."
if [[ -n "$(git status --porcelain)" ]]; then
  die "Są niezacommitowane zmiany. Najpierw wykonaj commit albo stash."
fi
require_command gh
git remote get-url "$FFUI_REMOTE" >/dev/null 2>&1 || die \
  "Nie znaleziono zdalnego repozytorium '$FFUI_REMOTE'."
gh auth status >/dev/null 2>&1 || die \
  "GitHub CLI nie jest zalogowane. Uruchom: gh auth login"

printf '==> Sprawdzanie zdalnej gałęzi %s/%s\n' "$FFUI_REMOTE" "$FFUI_BRANCH"
git fetch --prune "$FFUI_REMOTE" \
  "+refs/heads/$FFUI_BRANCH:refs/remotes/$FFUI_REMOTE/$FFUI_BRANCH"
FFUI_REMOTE_SHA="$(git rev-parse "$FFUI_REMOTE/$FFUI_BRANCH")"
FFUI_REMOTE_HEAD_REF="$(git ls-remote --symref "$FFUI_REMOTE" HEAD 2>/dev/null | awk '/^ref:/ { print $2; exit }')"
[[ "$FFUI_REMOTE_HEAD_REF" == "refs/heads/$FFUI_BRANCH" ]] || die \
  "Domyślna gałąź zdalnego repozytorium musi być '$FFUI_BRANCH', a jest '${FFUI_REMOTE_HEAD_REF:-nieustawiona}'."
FFUI_AHEAD_COUNT="$(git rev-list --count "$FFUI_REMOTE_SHA..HEAD")"
[[ "$FFUI_AHEAD_COUNT" == "1" ]] || die \
  "Oczekiwano dokładnie jednego lokalnego commita nad $FFUI_REMOTE/main (np. checkpoint), znaleziono: $FFUI_AHEAD_COUNT. Najpierw ręcznie połącz swoje lokalne commity."

FFUI_VERSION="$(read_version)"
FFUI_SSOT_VERSION="$(read_ssot_version)"
[[ "$FFUI_VERSION" == "$FFUI_SSOT_VERSION" ]] || die \
  "Niezgodne wersje: pubspec.yaml=$FFUI_VERSION, app_config.dart=$FFUI_SSOT_VERSION."
FFUI_TAG="v$FFUI_VERSION"

shopt -s nullglob
FFUI_LINUX_ARTIFACTS=("$FFUI_EXPORT"/FFmpeg_UI-*.AppImage)
shopt -u nullglob
if ((${#FFUI_LINUX_ARTIFACTS[@]} > 1)); then
  die "W export/ jest więcej niż jeden AppImage. Pozostaw tylko aktualny build."
fi

FFUI_LINUX_ARTIFACT=""
FFUI_WINDOWS_ARTIFACT=""
FFUI_LINUX_READY=false
FFUI_WINDOWS_READY=false
if ((${#FFUI_LINUX_ARTIFACTS[@]} == 1)); then
  FFUI_LINUX_ARTIFACT="${FFUI_LINUX_ARTIFACTS[0]}"
  validate_build_version "Linux" "$FFUI_LINUX_VERSION_FILE" "$FFUI_VERSION"
  FFUI_LINUX_READY=true
fi
if [[ -f "$FFUI_WINDOWS_EXPORT/ffmpeg_ui.exe" ]]; then
  validate_build_version "Windows" "$FFUI_WINDOWS_VERSION_FILE" "$FFUI_VERSION"
  FFUI_WINDOWS_READY=true
fi
if [[ "$FFUI_LINUX_READY" == false && "$FFUI_WINDOWS_READY" == false ]]; then
  die "Nie znaleziono aktualnego buildu Linux ani Windows w export/."
fi

if [[ "$FFUI_WINDOWS_READY" == true ]]; then
  require_command zip
  FFUI_RELEASE_WORK="$(mktemp -d -t ffmpeg-ui-release-XXXXXXXX)"
  FFUI_WINDOWS_ARTIFACT="$FFUI_RELEASE_WORK/FFmpeg_UI-Windows-x64.zip"
  (
    cd "$FFUI_EXPORT"
    zip -qr "$FFUI_WINDOWS_ARTIFACT" "FFmpeg_UI-Windows"
  )
fi

printf '\n==> Spłaszczanie historii lokalnego main do jednego commita\n'
FFUI_ROOT_COMMIT="$(git rev-list --max-parents=0 HEAD)"
git reset --soft "$FFUI_ROOT_COMMIT"
git commit --amend -m "$FFUI_COMMIT_MESSAGE"

printf '\n==> Wymuszone wysłanie pojedynczego commita do %s/%s\n' \
  "$FFUI_REMOTE" "$FFUI_BRANCH"
git push --force-with-lease="$FFUI_BRANCH:$FFUI_REMOTE_SHA" \
  "$FFUI_REMOTE" "HEAD:$FFUI_BRANCH"

FFUI_ASSETS=()
[[ "$FFUI_LINUX_READY" == true ]] && FFUI_ASSETS+=("$FFUI_LINUX_ARTIFACT")
[[ "$FFUI_WINDOWS_READY" == true ]] && FFUI_ASSETS+=("$FFUI_WINDOWS_ARTIFACT")

printf '\n==> Publikowanie GitHub Release %s\n' "$FFUI_TAG"
if gh release view "$FFUI_TAG" >/dev/null 2>&1; then
  while IFS= read -r asset_name; do
    case "$asset_name" in
      *.AppImage|FFmpeg_UI-Windows-x64.zip)
        gh release delete-asset "$FFUI_TAG" "$asset_name" --yes
        ;;
    esac
  done < <(gh release view "$FFUI_TAG" --json assets --jq '.assets[].name')
  gh release upload "$FFUI_TAG" "${FFUI_ASSETS[@]}"
else
  gh release create "$FFUI_TAG" "${FFUI_ASSETS[@]}" \
    --title "FFmpeg UI $FFUI_VERSION" \
    --generate-notes
fi

printf '\nSukces: origin/main zawiera jeden commit o nazwie "%s".\n' \
  "$FFUI_COMMIT_MESSAGE"
printf 'Opublikowano release %s z platformą: ' "$FFUI_TAG"
if [[ "$FFUI_LINUX_READY" == true && "$FFUI_WINDOWS_READY" == true ]]; then
  printf 'Linux i Windows.\n'
elif [[ "$FFUI_LINUX_READY" == true ]]; then
  printf 'tylko Linux (brak aktualnego buildu Windows).\n'
else
  printf 'tylko Windows (brak aktualnego buildu Linux).\n'
fi
