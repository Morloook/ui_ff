# FFmpeg UI

Desktopowy interfejs Flutter dla lokalnie zainstalowanych programów
`ffmpeg` i `ffprobe`. Aplikacja wykrywa możliwości konkretnej kompilacji,
buduje przeszukiwalny katalog i nie zakłada, że każdy użytkownik ma ten sam
zestaw kodeków, filtrów lub akceleracji sprzętowej.

> Oficjalne wydanie projektu: `1.0.1`.

Angielska wersja dla GitHuba jest dostępna w [README.md](README.md). Interfejs
aplikacji domyślnie uruchamia się po angielsku, lecz w **Ustawieniach** można
natychmiast przełączyć go na polski.

## Dostępne moduły

- diagnostyka ścieżek, wersji i konfiguracji FFmpeg/FFprobe;
- dynamiczny katalog opcji, kodeków, filtrów, formatów, urządzeń, protokołów
  i akceleracji, zapisywany w SQLite;
- leniwe pobieranie szczegółowej pomocy wybranego komponentu;
- inspektor plików FFprobe z widokiem strumieni, metadanych i surowego JSON;
- terminal eksperta uruchamiający wyłącznie FFmpeg/FFprobe bez powłoki;
- kreator zachowujący kolejność opcji globalnych, wejściowych i wyjściowych;
- automatyczny importer `.sh` z edytowalnymi formularzami i podglądem workflow;
- ręcznie uruchamiana kolejka poleceń oraz wieloetapowych workflow;
- konfiguracja SSOT z domyślnymi opcjami oraz osobny JSON nadpisań użytkownika.

## Wymagania

### Uruchamianie gotowej aplikacji

- 64-bitowy Linux (`x86_64`) z graficzną sesją pulpitu;
- obsługa FUSE do zwykłego montowania AppImage; jeśli nie jest dostępna,
  uruchom paczkę poleceniem
  `APPIMAGE_EXTRACT_AND_RUN=1 ./FFmpeg_UI-x86_64.AppImage`;
- FFmpeg i FFprobe dostępne w `PATH` albo wskazane ręcznie w aplikacji.

Binaria FFmpeg nie są dołączane do aplikacji. ExifTool jest opcjonalny i
rozszerza odczyt oraz edycję metadanych. Własne skrypty workflow są opcjonalne.

### Budowanie ze źródeł

- Flutter 3.44 lub nowszy;
- FFmpeg i FFprobe dostępne w `PATH` albo wskazane ręcznie;
- Linux lub Windows.

## Uruchomienie

```bash
flutter pub get
flutter run -d linux
```

W panelu VS Code **Uruchom i debuguj** dostępne są konfiguracje Linux/Windows
w trybach debug oraz release. Konfiguracje Windows należy uruchamiać na
Windowsie.

Build Linux:

```bash
flutter build linux
```

Build Windows należy wykonać na Windowsie:

```powershell
flutter build windows
```

Gotowe skrypty dystrybucyjne:

```bash
tools/build-appimage.sh
```

```bat
tools\build-windows-exe.bat
```

Publiczny build AppImage wymaga `linuxdeploy` dostępnego w `PATH` albo pliku
`tools/linuxdeploy-x86_64.AppImage`; narzędzie zbiera kwalifikujące się
biblioteki aplikacji. Do końcowej walidacji paczki wymagany jest także pakiet
`squashfs-tools`. Wynikiem jest jeden plik w katalogu `export`, z
zweryfikowanym payloadem SquashFS i metadanymi AppStream. Tryb
`tools/build-appimage.sh --dev` tworzy wyłącznie lokalną paczkę przez
`appimagetool`, która nie zbiera dodatkowych bibliotek systemowych. Jeżeli
zainstalowano `appstreamcli`, skrypt sprawdza też metadane przed buildem; jego
brak pomija wyłącznie tę dodatkową kontrolę.

Skrypt Windows kopiuje cały release bundle do `export/FFmpeg_UI-Windows`;
plik `.exe` wymaga bibliotek i katalogu `data` znajdujących się obok niego.

## Skrypty użytkownika

Prywatne skrypty nie są częścią publicznego repozytorium ani AppImage. Domyślnie
aplikacja czyta bezpośrednie pliki `.sh` z katalogu `skrypty/` obok pliku
wykonywalnego. Dla AppImage jest to katalog obok pliku `.AppImage`. W
**Ustawieniach → Katalog skryptów** można wskazać inny istniejący katalog i w
każdej chwili przywrócić domyślną lokalizację.

Gwarantowany zakres importu jest celowo wąski: pojedynczy skrypt powinien
zawierać jedno bezpośrednie wywołanie `ffmpeg`, proste przypisania oraz
opcjonalne pytania `read`. Pętle, warunki, funkcje, potoki, przekierowania,
podstawienia powłoki i wywołania innych programów (w tym `ffprobe`) nie są
interpretowane ani uruchamiane. Bardziej złożony plik może zostać zgłoszony
jako częściowo rozpoznany, ale nie należy do gwarantowanego formatu importu.

## Weryfikacja

```bash
flutter analyze
flutter test
dart run tools/catalog_diagnostics.dart
```

Szczegóły instalacji znajdują się w
[`docs/installation.md`](docs/installation.md), a podział odpowiedzialności w
[`docs/project_map.md`](docs/project_map.md).
Zasady SSOT opisuje [`docs/configuration.md`](docs/configuration.md).
Historia zmian znajduje się w polskiej wersji
[`docs/changelog.pl.md`](docs/changelog.pl.md). Angielska wersja dla GitHuba to
[`docs/changelog.md`](docs/changelog.md).
Pierwszą publikację prowadzi lista kontrolna
[`docs/github_publication.md`](docs/github_publication.md).

## Współtworzenie i zgłoszenia

Zasady przygotowania zmian znajdują się w
[`CONTRIBUTING.md`](CONTRIBUTING.md). Powtarzalne błędy i propozycje funkcji
można zgłaszać przez przygotowane formularze GitHub Issues.

Podatności należy przekazywać prywatnie zgodnie z
[`SECURITY.md`](SECURITY.md), a nie jako publiczne issue. Zasady dyskusji
opisuje [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).

## Autor i kontakt

Autor: **Morl / Morloook** — [https://github.com/Morloook](https://github.com/Morloook)
Kontakt: [git@vms.net.pl](mailto:git@vms.net.pl)

Jeśli wykorzystujesz kod projektu w swoim programie, proszę o dobrowolną
informację na powyższy adres e-mail. Nie jest to dodatkowy warunek licencji.

## Licencja

Kod jest udostępniony na licencji [MIT](LICENSE). Zachowaj informację o prawach
autorskich i treść licencji w kopiach lub istotnych częściach kodu.

## Bezpieczeństwo

Polecenia są uruchamiane jako plik wykonywalny i lista argumentów z
`runInShell: false`. Tekst wpisany w terminalu nie jest przekazywany do
bash, PowerShell ani `cmd.exe`. Tryb prywatny nie zapisuje polecenia w historii
bieżącej sesji.
