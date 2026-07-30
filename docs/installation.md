# Installation and distribution

## Running the released AppImage

The distributed AppImage runs on 64-bit Linux (`x86_64`) with a graphical
desktop session. FFmpeg and FFprobe are not included: install them in `PATH` or
select their executable paths on the **Environment** screen. ExifTool is
optional and only enables extended metadata reading and editing; a `skrypty/`
directory next to the AppImage is optional and only supplies personal workflows.

FUSE support allows normal AppImage mounting. If FUSE is unavailable, run the
package without mounting it:

```bash
APPIMAGE_EXTRACT_AND_RUN=1 ./FFmpeg_UI-x86_64.AppImage
```

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
AppImage files from `export` first. A public build requires `linuxdeploy`, which
collects eligible application libraries, adds AppStream metadata, and validates
the final SquashFS payload. It also requires `squashfs-tools` for `unsquashfs`.
When `appstreamcli` is installed, the script validates the AppStream metadata;
its absence skips only that additional check. `appimagetool` is available only
through the explicit local-development mode below; it packages the existing
bundle but does not collect additional system libraries.

```bash
tools/build-appimage.sh --dev
```

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

## Uruchamianie wydanego AppImage

Gotowy AppImage działa na 64-bitowym Linuxie (`x86_64`) z graficzną sesją
pulpitu. FFmpeg i FFprobe nie są dołączone: zainstaluj je w `PATH` albo wskaż
ich pliki wykonywalne na ekranie **Środowisko**. ExifTool jest opcjonalny i
umożliwia wyłącznie rozszerzony odczyt oraz edycję metadanych; katalog
`skrypty/` obok AppImage jest również opcjonalny i służy tylko do własnych
workflow.

Obsługa FUSE pozwala zwyczajnie montować AppImage. Gdy FUSE nie jest dostępny,
uruchom paczkę bez montowania:

```bash
APPIMAGE_EXTRACT_AND_RUN=1 ./FFmpeg_UI-x86_64.AppImage
```

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
buildzie istnieje tam tylko jeden aktualny artefakt AppImage. Prywatne skrypty
nie są kopiowane do paczki.

Publiczny build wymaga `linuxdeploy` dostępnego w `PATH` albo wykonywalnego
`tools/linuxdeploy-x86_64.AppImage`. Zbiera on kwalifikujące się biblioteki
aplikacji, dołącza metadane AppStream i sprawdza końcowy payload SquashFS.
Do tej kontroli wymagany jest pakiet `squashfs-tools`, udostępniający
`unsquashfs`. Gdy zainstalowano `appstreamcli`, skrypt sprawdza również
metadane AppStream; jego brak pomija wyłącznie tę dodatkową kontrolę.
`appimagetool` jest dostępny tylko przez jawny tryb lokalny:

```bash
tools/build-appimage.sh --dev
```

Tworzy on paczkę z gotowego bundle, ale nie wyszukuje dodatkowych bibliotek
systemowych, dlatego nie jest przeznaczony do publicznego wydania.

Analizę i testy można pominąć tylko podczas lokalnej diagnostyki:

```bash
FFUI_SKIP_CHECKS=1 tools/build-appimage.sh
```

`tools/build-windows-exe.bat` wykonuje analogiczną walidację na Windowsie,
buduje runner release i kopiuje kompletny bundle do
`export/FFmpeg_UI-Windows` razem z katalogiem `skrypty`.
