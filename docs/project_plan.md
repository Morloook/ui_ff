# FFmpeg UI product plan

## Product scope

FFmpeg UI is a Flutter desktop application for Linux and Windows. It uses
locally installed `ffmpeg` and `ffprobe`, detects their versions and available
capabilities, and exposes those capabilities through a graphical interface.

“All options” means options and components advertised by the local binaries.
Unavailable compile-time features are not invented by the application.

The interface starts in English and can be changed to Polish from
**Settings and information → Interface language**. FFmpeg-originated help
remains in its original language.

## Functional goals

- Discover paths, versions, and build configuration of FFmpeg and FFprobe.
- Maintain a searchable local catalog of global, input, output, stream, codec,
  format, filter, protocol, device, acceleration, pixel-format, sample-format,
  and bitstream-filter capabilities.
- Preserve raw help whenever a parser cannot interpret a line reliably.
- Inspect media through FFprobe, including streams, metadata, chapters,
  programs, packets, frames, raw JSON, export, and metadata editing.
- Provide an expert terminal for FFmpeg and FFprobe only, never arbitrary shell
  commands.
- Build ordered FFmpeg commands, queue jobs, show progress and logs, cancel,
  retry, and manage user presets.
- For queued FFmpeg jobs, request structured progress through
  `-progress pipe:1` and parse its `key=value` records; do not infer primary
  progress from human-readable `stderr` lines such as `time=`. The expert
  terminal keeps the arguments entered by the user unchanged.
- Import user-provided `.sh` workflow files into editable forms. Personal
  scripts are intentionally not included in the public repository.

## Architecture

- `BinaryInstallation` describes a detected executable.
- `CapabilitySnapshot` identifies a full catalog for one installation.
- `FfmpegComponent` represents a codec, filter, format, device, protocol, or
  other component.
- `OptionDefinition` stores name, type, scope, values, default, flags,
  description, and raw help.
- `CommandDraft` contains an executable and ordered arguments, never a shell
  command string.
- `ProcessSession` tracks process state, output, errors, progress, and
  cancellation.

## Acceptance criteria

- Parsers keep every recognized line in the catalog or explicitly preserve it
  as raw data.
- Catalog refreshes after a binary path, version, or configuration changes.
- Searches remain responsive with large local catalogs.
- Catalog search uses SQLite indexing (preferably FTS5 where available), a
  debounced query, result limits or pagination, and lazily built result rows.
  Regression tests use captured help from multiple FFmpeg builds and a large
  synthetic catalog.
- Process execution handles spaces, Polish characters, and quotes without
  invoking a shell.
- The terminal cannot start an executable other than configured FFmpeg or
  FFprobe.
- Inspector and queue handle successful, failed, cancelled, and interrupted
  work without blocking the interface.
- Linux widget and service tests pass; Windows build and runtime validation are
  performed separately on Windows.
- A filter-graph editor is a separate delivery phase: it needs typed input and
  output ports, graph validation, serialization to `filter_complex`, and
  fallback editing of the raw graph expression.

---

## Wersja polska

## Założenie produktu

Powstanie desktopowa aplikacja Flutter dla Linuxa i Windowsa. Będzie korzystać z lokalnie zainstalowanych `ffmpeg` i `ffprobe`, wykrywać ich wersję oraz rzeczywiście dostępne możliwości.

„Obsługa wszystkich opcji” oznacza wszystko, co dana instalacja FFmpeg zgłasza w pomocy i listach możliwości. Opcje niedostępne w konkretnej kompilacji nie będą sztucznie pokazywane.

Interfejs będzie po polsku, ale od początku przygotowany do późniejszych tłumaczeń. Program najpierw powstaje dla autora, lecz architektura ma umożliwić publiczne wydanie.

## Główne możliwości

- Automatyczne wykrywanie ścieżek, wersji i konfiguracji `ffmpeg`/`ffprobe`.
- Kompletny, przeszukiwalny katalog:
  - opcji globalnych, wejściowych, wyjściowych i strumieniowych,
  - kodeków, encoderów i decoderów,
  - muxerów, demuxerów i formatów,
  - filtrów audio/wideo oraz `filter_complex`,
  - protokołów, urządzeń, akceleracji sprzętowej, formatów pikseli i próbek,
  - bitstream filters i pozostałych elementów zgłaszanych przez lokalne binaria.
- Szczegóły każdej opcji: typ, opis, zakres, wartość domyślna, dozwolone wartości, flagi i zastosowanie.
- Zachowanie oryginalnej pomocy FFmpeg jako widoku awaryjnego, gdy jakiejś informacji nie da się jednoznacznie sparsować.
- Inspektor plików oparty na `ffprobe`: format, strumienie, metadane, rozdziały, programy, pakiety i ramki.
- Oddzielny terminal eksperta obsługujący dowolne argumenty `ffmpeg` i `ffprobe`, ale bez uruchamiania dowolnych poleceń systemowych.
- Późniejszy kreator poleceń, kolejka zadań, historia, presety, postęp, anulowanie i ponawianie.
- Użytkownicy mogą dodawać własne kompatybilne skrypty `.sh` do katalogu
  `skrypty/` obok programu albo wybrać inny katalog w Ustawieniach.

## Etapy implementacji

### 1. Fundament projektu

- Zainicjalizować aplikację Flutter Desktop z obsługą Linuxa i Windowsa oraz repozytorium Git.
- Zachować obecne skrypty i narzędzia gitowe jako materiały referencyjne.
- Uporządkować `.gitignore`, szczególnie tak, aby zasoby graficzne aplikacji nie były przypadkowo ignorowane.
- Wprowadzić modułową strukturę: środowisko, katalog możliwości, inspektor, terminal, zadania, presety i ustawienia.
- Rozdzielić warstwę UI od wykrywania binariów, parsowania pomocy, zapisu danych i uruchamiania procesów.

### 2. Dynamiczny katalog wszystkich możliwości

- Wykonywać listujące polecenia obu narzędzi oraz `-h full`.
- Leniwie pobierać szczegóły poszczególnych encoderów, decoderów, filtrów, formatów, protokołów i urządzeń.
- Zapisywać katalog lokalnie w SQLite, identyfikując go odciskiem: ścieżka binarium, wersja i konfiguracja kompilacji.
- Automatycznie unieważniać katalog po zmianie lub aktualizacji binariów.
- Udostępnić wyszukiwanie, kategorie, filtry typu audio/wideo/subtitles, zakres opcji i informację o dostępności.
- Pokazywać postęp skanowania, błędy poszczególnych sekcji i możliwość ręcznego ponowienia skanu.
- Testować parsery na zapisanych wynikach kilku rzeczywistych kompilacji: co
  najmniej pakietowej oraz takiej z dodatkowymi możliwościami sprzętowymi (na
  przykład NVENC, jeśli jest dostępny). Fixture przechowuje także surową pomoc,
  aby nieznane lub zmienione linie nie znikały bez śladu.
- Wyszukiwanie realizować przez indeks SQLite (preferowane FTS5), opóźnienie
  zapytania podczas pisania, limit lub stronicowanie wyników i leniwe budowanie
  wierszy listy. Testy regresyjne obejmą sztucznie duży katalog.

### 3. FFprobe Inspector

- Dodawanie pliku przez wybór oraz przeciągnięcie do okna.
- Czytelny widok podsumowania, strumieni, metadanych, rozdziałów i danych technicznych.
- Zakładka surowego JSON oraz kopiowanie i eksport wyników.
- Zaawansowany formularz odpowiadający opcjom `ffprobe`, w tym `show_entries`, wybór strumieni, interwały odczytu oraz format wyjściowy.
- Obsługa dużych wyników dotyczących ramek i pakietów bez blokowania interfejsu.

### 4. Terminal eksperta i wykonywanie procesów

- Wybór `ffmpeg` albo `ffprobe` oraz edytowanie pełnej listy argumentów.
- Uruchamianie przez `Process.start(executable, arguments, runInShell: false)`, dzięki czemu ścieżki i argumenty nie będą interpretowane przez bash ani PowerShell.
- Poprawna obsługa cudzysłowów, spacji i znaków Unicode na obu systemach.
- Osobne strumienie stdout/stderr, wejście stdin, czas działania, kod zakończenia, zatrzymanie procesu i kopiowanie logu.
- Dla zadań FFmpeg dodawać `-progress pipe:1` i `-nostats`, a następnie
  interpretować rekordy `key=value` ze strukturalnego strumienia postępu.
  Nie wyliczać głównego postępu z tekstu `time=` na `stderr`, ponieważ jego
  format nie jest stabilnym API. Terminal eksperta zachowuje dokładnie argumenty
  wpisane przez użytkownika i nie dopisuje tych opcji samodzielnie.
- Ostrzeżenie przed potencjalnym nadpisaniem pliku, ale bez ograniczania legalnych opcji eksperckich.
- Historia terminala nie będzie zapisywać danych, które użytkownik oznaczy jako poufne.

### 5. Kreator poleceń i zadania

- Model wielu wejść i wyjść z zachowaniem kolejności argumentów FFmpeg.
- Osobne zakresy opcji: globalny, dotyczący wejścia, wyjścia i wybranego strumienia.
- Edytor mapowania strumieni, metadanych i rozdziałów.
- Podgląd wygenerowanego polecenia oraz możliwość przeniesienia go do terminala eksperta.
- Kolejka zadań z postępem, pauzą kolejki, anulowaniem, ponowieniem i logami.
- Presety użytkownika oraz migracja trzech obecnych skryptów do formularzy zachowujących ich aktualne zachowanie.

### 6. Edytor grafów filtrów `filter_complex`

- Traktować jako osobną, wieloetapową fazę, a nie pojedynczą kontrolkę kreatora.
- Zbudować edytor węzłów z wejściami i wyjściami o znanych typach audio/wideo,
  połączeniami, walidacją oraz komunikatami o niezgodnych portach.
- Generować i odtwarzać wyrażenia `filter_complex`, zawsze udostępniając
  edytowalny widok tekstowy jako fallback dla grafów, których UI jeszcze nie
  potrafi przedstawić.
- Testować serializację grafu, walidację połączeń i zachowanie surowej
  konfiguracji nieobsługiwanej przez edytor.

### 7. Dystrybucja

- Diagnostyka pierwszego uruchomienia i wskazanie brakujących binariów.
- Paczki Linux i Windows bez dołączania FFmpeg.
- Dokumentacja instalacji FFmpeg, różnic systemowych i akceleracji GPU.
- Informacje licencyjne aplikacji i wykrytej kompilacji FFmpeg.
- Przygotowanie mechanizmu migracji lokalnej bazy między wersjami aplikacji.

## Najważniejsze modele i interfejsy

- `BinaryInstallation` — ścieżka, wersja, konfiguracja i stan binarium.
- `CapabilitySnapshot` — pełny katalog dla konkretnej instalacji.
- `FfmpegComponent` — kodek, filtr, format, urządzenie, protokół lub inny element.
- `OptionDefinition` — nazwa, typ, zakres, wartości, domyślna wartość, flagi, opis i surowa pomoc.
- `CommandDraft` — wykonywalny program oraz uporządkowana lista argumentów bez składania polecenia powłoki.
- `ProcessSession` — stan procesu, wyjście, błędy, postęp i możliwość anulowania.
- Parser będzie tolerował nieznane linie i zawsze zachowa surowe dane zamiast pomijać nierozpoznane opcje.

## Testy i kryteria akceptacji

- Testy parserów na zapisanych wynikach FFmpeg 8.1.2 z Linuxa, reprezentatywnych danych z Windowsa oraz co najmniej dwóch różnych kompilacji FFmpeg, w tym builda z dodatkowymi możliwościami sprzętowymi, gdy jest dostępny.
- Test potwierdzający, że każda rozpoznana linia opcji trafia do katalogu albo jawnie do sekcji danych surowych.
- Testy wartości domyślnych, zakresów, enumów, aliasów i flag audio/wideo/subtitles.
- Test odświeżenia katalogu po zmianie wersji lub ścieżki binarium.
- Testy wyszukiwania w dużym katalogu z indeksem, debounce i leniwą listą bez zauważalnego blokowania UI.
- Testy ścieżek ze spacjami, polskimi znakami i cudzysłowami.
- Test potwierdzający, że terminal nie uruchamia powłoki ani dodatkowych poleceń.
- Testy poprawnych, uszkodzonych i niedostępnych plików w inspektorze FFprobe.
- Testy postępu opartego na `-progress pipe:1`, anulowania, błędu procesu i nieoczekiwanego zamknięcia aplikacji.
- Testy widgetów na Linuxie oraz osobna walidacja kompilacji i działania na Windowsie.

## Przyjęte decyzje

- Pierwszym używalnym wydaniem będzie pełny katalog lokalnie dostępnych opcji.
- Program obsłuży Linux i Windows; macOS pozostaje możliwym późniejszym rozszerzeniem.
- FFmpeg i FFprobe nie będą dołączane do aplikacji.
- Opisy pochodzące bezpośrednio z FFmpeg pozostaną w oryginalnym języku, natomiast nawigacja i objaśnienia aplikacji będą po polsku.
- Terminal eksperta uruchomi wyłącznie skonfigurowane `ffmpeg` lub `ffprobe`.
- Pierwsza wersja katalogu obejmuje dane reklamowane przez binaria; wygodne formularze dla każdej grupy będą rozwijane na tym samym dynamicznym modelu.
