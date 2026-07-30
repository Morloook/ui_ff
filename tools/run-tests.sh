#!/usr/bin/env bash
# Runs every Flutter test discovered by the project. Optional arguments are
# forwarded to `flutter test`, for example: ./tools/run-tests.sh --coverage.

set -Eeuo pipefail

FFUI_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FFUI_LOG="$(mktemp -t ffmpeg-ui-tests-XXXXXXXX.log)"
FFUI_STARTED_AT="$(date +%s)"

cleanup() {
    rm -f -- "$FFUI_LOG"
}
trap cleanup EXIT

die() {
    printf 'Błąd: %s\n' "$1" >&2
    exit 1
}

command -v flutter >/dev/null 2>&1 || die 'Nie znaleziono Fluttera w PATH.'

cd "$FFUI_ROOT"

FFUI_FILE_COUNT="$(find test -type f -name '*_test.dart' -print | wc -l | tr -d '[:space:]')"
printf 'FFmpeg UI — pełna bateria testów\n'
printf 'Katalog projektu: %s\n' "$FFUI_ROOT"
printf 'Wykryte pliki testów: %s\n\n' "$FFUI_FILE_COUNT"
printf '==> Flutter uruchamia testy i pokazuje postęp na żywo\n\n'

set +e
flutter test --reporter expanded "$@" 2>&1 | tee "$FFUI_LOG"
FFUI_TEST_EXIT="${PIPESTATUS[0]}"
set -e

FFUI_DURATION="$(( $(date +%s) - FFUI_STARTED_AT ))"
FFUI_PASSED="$(sed -n 's/.*+\([0-9][0-9]*\): All tests passed!.*/\1/p' "$FFUI_LOG" | tail -n 1)"

printf '\n==> Podsumowanie\n'
printf 'Pliki testów: %s\n' "$FFUI_FILE_COUNT"
printf 'Czas: %ss\n' "$FFUI_DURATION"

if [[ "$FFUI_TEST_EXIT" -eq 0 && -n "$FFUI_PASSED" ]]; then
    printf 'Wynik: sukces — zaliczono %s testów.\n' "$FFUI_PASSED"
    exit 0
fi

if [[ "$FFUI_TEST_EXIT" -eq 0 ]]; then
    printf 'Wynik: błąd — Flutter nie potwierdził ukończenia wszystkich testów.\n' >&2
    exit 1
fi

printf 'Wynik: błąd — Flutter zakończył testy kodem %s.\n' "$FFUI_TEST_EXIT" >&2
exit "$FFUI_TEST_EXIT"
