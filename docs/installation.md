# Installation and distribution

## Linux

Install Flutter with Linux desktop dependencies and install FFmpeg from the
distribution repository. On Arch/CachyOS:

```bash
sudo pacman -S ffmpeg
```

Extended metadata reading in the inspector optionally uses ExifTool:

```bash
sudo pacman -S perl-image-exiftool
```

Verify the tools:

```bash
ffmpeg -version
ffprobe -version
exiftool -ver
flutter doctor -v
```

NVENC, VAAPI, Vulkan, OpenCL, and similar acceleration require a compatible
FFmpeg build and working drivers. The **Environment** screen displays the
detected build configuration.

## Windows

1. Install Flutter with Windows desktop support.
2. Install FFmpeg.
3. Optionally install ExifTool and add `exiftool.exe` to `PATH` for extended
   metadata inspection.
4. Add the directory containing `ffmpeg.exe` and `ffprobe.exe` to `PATH`, or
   select both files on the **Environment** screen.
5. Run `flutter build windows`.

Build and test Windows on Windows. A successful Linux build does not validate
Windows plugins or process integration.

## Interface language

The interface starts in English. Change it to Polish from
**Settings and information → Interface language**. The setting is stored in
the user settings JSON and restored at the next start.

## Application data

The capabilities catalog is local and can be rebuilt safely. Updating FFmpeg
changes the fingerprint, so the application scans the new installation.

FFmpeg is not included in distribution packages. The user is responsible for
installing a build with the needed codecs and acceptable license terms.

## Distribution scripts

`tools/build-appimage.sh` runs analysis, tests, a Linux release build, and
creates one file: `export/FFmpeg_UI-<architecture>.AppImage`. It removes older
AppImage files from `export` first. The script uses `linuxdeploy` when
available and otherwise `appimagetool`. The fallback packs the existing bundle
but does not collect additional system libraries, so `linuxdeploy` is preferred
for a broadly portable public package.

For local diagnostics only, analysis and tests can be skipped:

```bash
FFUI_SKIP_CHECKS=1 tools/build-appimage.sh
```

`tools/build-windows-exe.bat` performs equivalent validation on Windows,
builds the release runner, and copies the complete bundle to
`export/FFmpeg_UI-Windows`.

Personal scripts are excluded from the public repository and never copied into
the AppImage. Put user-provided `.sh` files directly in `skrypty/` next to the
application executable. For AppImage, this means a `skrypty/` directory next to
the `.AppImage` file; for the Windows release bundle, use the `skrypty/`
directory next to `ffmpeg_ui.exe`.

---

## Wersja polska

## Linux

Zainstaluj Flutter wraz z zależnościami desktopowymi oraz FFmpeg z repozytorium
dystrybucji. Dla Arch/CachyOS:

```bash
sudo pacman -S ffmpeg
```

Rozszerzony odczyt wszystkich dostępnych metadanych w inspektorze korzysta
opcjonalnie z ExifTool. Dla Arch/CachyOS:

```bash
sudo pacman -S perl-image-exiftool
```

Sprawdzenie:

```bash
ffmpeg -version
ffprobe -version
exiftool -ver
flutter doctor -v
```

Akceleracje takie jak NVENC, VAAPI, Vulkan lub OpenCL wymagają odpowiedniej
kompilacji FFmpeg i działających sterowników. Ekran **Środowisko** pokazuje
konfigurację wykrytej kompilacji.

## Windows

1. Zainstaluj Flutter z obsługą Windows Desktop.
2. Zainstaluj FFmpeg.
3. Opcjonalnie zainstaluj ExifTool i dodaj `exiftool.exe` do `PATH`, aby
   inspektor odczytywał rozszerzone metadane.
4. Dodaj katalog zawierający `ffmpeg.exe` i `ffprobe.exe` do `PATH` albo wskaż
   oba pliki na ekranie **Środowisko**.
5. Uruchom `flutter build windows`.

Kompilację i testy Windows należy wykonywać na Windowsie. Poprawny build Linux
nie potwierdza działania pluginów ani integracji procesów na Windowsie.

## Dane aplikacji

Katalog możliwości jest lokalny i może zostać bezpiecznie odbudowany. Po
aktualizacji FFmpeg zmieni się fingerprint, więc aplikacja automatycznie wykona
nowy skan.

FFmpeg nie jest dołączany do paczek. Użytkownik odpowiada za instalację wersji
zgodnej z potrzebnymi kodekami i warunkami licencji.

## Skrypty dystrybucyjne

`tools/build-appimage.sh` wykonuje analizę, testy, build release i tworzy jeden
plik `export/FFmpeg_UI-<architektura>.AppImage`. Przed pakowaniem
usuwa wcześniejsze pliki `.AppImage` z katalogu `export`, dlatego po udanym
buildzie istnieje tam tylko jeden aktualny artefakt AppImage. Do paczki
kopiowany jest również katalog wbudowanych skryptów.

Skrypt w pierwszej kolejności korzysta z `linuxdeploy` dostępnego w `PATH` albo
z wykonywalnego `tools/linuxdeploy-x86_64.AppImage`. Jeżeli go nie znajdzie,
automatycznie używa `appimagetool` z `PATH` albo
`tools/appimagetool-x86_64.AppImage`. `appimagetool` pakuje gotowy bundle, ale
nie wyszukuje dodatkowych bibliotek systemowych; do publicznej paczki
przeznaczonej dla różnych dystrybucji zalecany jest `linuxdeploy`.

Analizę i testy można pominąć tylko podczas lokalnej diagnostyki:

```bash
FFUI_SKIP_CHECKS=1 tools/build-appimage.sh
```

`tools/build-windows-exe.bat` wykonuje analogiczną walidację na Windowsie,
buduje runner release i kopiuje kompletny bundle do
`export/FFmpeg_UI-Windows` razem z katalogiem `skrypty`.
