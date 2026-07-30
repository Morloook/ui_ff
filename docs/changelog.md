# Changelog

Ten dokument opisuje historię zmian w aplikacji FFmpeg UI.

## Zasady prowadzenia

- Każda wersja programu ma własną sekcję w formacie `MAJOR.MINOR.PATCH`.
- Nową sekcję wersji dodaje się na początku pliku; wpisy w jej ramach są
  dzielone na krótkie podsekcje tematyczne.
- Nie używa się osobnych sekcji ani dat dziennych. Zmiany oczekujące na wydanie
  opisuje najwyższa, przygotowywana wersja.
- Po wydaniu kolejnej wersji wcześniejsze sekcje pozostają zamknięte; korekty
  należy opisywać w nowej wersji, bez zmieniania historii wydania.
- Changelog opisuje efekty i zachowanie programu. Szczegółowy podział
  odpowiedzialności plików pozostaje wyłącznie w mapie projektu.

## 1.0.1

### Wersja aplikacji

- Interfejs odczytuje wersję `1.0.1` z `app_config.dart`, a pakiet Fluttera
  ma zgodną wersję techniczną `1.0.1+2`.
- Fallback metadanych pliku wykonywalnego Windows ma numer `1.0.1`, dzięki
  czemu pozostaje poprawny również poza standardowym buildem Fluttera.

### Zakres importu skryptów

- Dokumentacja i okno pomocy Skrypty jednoznacznie definiują gwarantowany
  format importu: jeden plik `.sh` zawierający jedno bezpośrednie wywołanie
  `ffmpeg`, proste przypisania i opcjonalne pytania `read`.
- Pętle, warunki, funkcje, potoki, przekierowania, podstawienia powłoki oraz
  inne programy, w tym `ffprobe`, nie są interpretowane ani uruchamiane.
  Złożony skrypt może zostać częściowo rozpoznany, lecz nie jest obsługiwanym
  kontraktem importu.

### Katalog skryptów

- W Ustawieniach katalog skryptów ma teraz własną, wyraźną sekcję bezpośrednio
  pod przyciskiem przywracania ustawień domyślnych.
- Ten sam edytowalny wybór katalogu znajduje się również w zakładce Skrypty.
  Pole tekstowe, przycisk wyboru katalogu i przywrócenie wartości domyślnej w
  obu miejscach zapisują wyłącznie `scripts.directoryPath` w `options.json`.
- Dodano test interakcji potwierdzający zapis ręcznie wpisanej ścieżki przez
  zakładkę Skrypty. Łączna liczba automatycznych testów wynosi 70.

### Publikacja Release

- Dodano `tools/publish-final-main-release.sh`. Skrypt wymaga czystego,
  w całości zakomitowanego repozytorium, lokalnej gałęzi `main`, zdalnej
  domyślnej gałęzi `origin/main`.
- Przed przepisaniem historii sprawdza zgodność wersji `app_config.dart` i
  `pubspec.yaml`, a także znaczniki wersji aktualnych artefaktów w `export/`.
  Stary albo niezweryfikowany build zatrzymuje publikację.
- Skrypty budowania Linux i Windows zapisują ignorowane znaczniki wersji w
  `build/release-manifests/`, poza końcowym katalogiem `export/`. Publikator
  może dzięki nim bezpiecznie rozpoznać aktualny build bez dodawania plików do
  artefaktów wydania.
- Publikator spłaszcza historię do jednego commita o nazwie `main`, wysyła go
  do `origin/main` przez `--force-with-lease`, celowo zastępując poprzednią
  historię zdalnego `main`, a następnie tworzy lub aktualizuje GitHub Release
  `v<wersja>`. Wysyła AppImage i/lub kompletny bundle Windows jako ZIP; brak
  jednego systemu nie blokuje wydania drugiego.
- Przed kontrolą wersji publikator wymaga dokładnie jednego lokalnego commita
  poza `origin/main`. Dwa lokalne commity, np. `bugs` i `checkpoint`, zatrzymują
  skrypt z komunikatem o konieczności ręcznego połączenia ich przed publikacją.
  Akceptowany jest też niezależny pojedynczy commit root utworzony przez starszy
  skrypt squashujący.

### Testy niezawodności

- Rozszerzono testy parsera pomocy o zachowanie nierozpoznanych linii, zakresy
  wartości oraz rozpoznawanie typu audio i wideo z kierunku filtrów FFmpeg.
- Dodano testy tymczasowej SQLite dla katalogu możliwości: snapshot nie jest
  używany przed oznaczeniem go jako kompletny, komponenty i opcje są poprawnie
  zapisywane oraz odczytywane, a stary fingerprint tej samej instalacji jest
  zastępowany.
- Dodano dedykowane testy runnera procesów dla rozdzielenia `stdout` i
  `stderr`, kodu błędu procesu, strumieni zdarzeń na żywo, danych przekazanych
  przez `stdin` oraz próby uruchomienia nieistniejącego programu.
- Repozytorium katalogu otrzymało opcjonalne wstrzykiwanie katalogu danych i
  factory SQLite, dzięki czemu testy nie korzystają z rzeczywistej bazy danych
  użytkownika.
- Dodano smoke test renderowania ekranów środowiska, katalogu, terminala i
  skryptów przed inicjalizacją katalogu możliwości.
- Dodano testy pełnego skanu `CapabilityService`, zapisu snapshotu, ponownego
  użycia cache, błędu pojedynczej sekcji oraz anulowania skanu. Poprawiono przy
  tym zakleszczenie, które mogło wystąpić przy zamykaniu strumienia postępu po
  anulowaniu skanowania.
- Ekran kolejki sprawdza aktywowanie przycisku ręcznego uruchomienia po dodaniu
  zadania, a testy interakcji sprawdzają ręczne ścieżki binariów, wyszukiwanie
  i otwieranie pozycji katalogu, odświeżanie skryptów oraz wybór FFmpeg/FFprobe
  w terminalu.

### Regresje parsera FFmpeg

- Dodano dwa zapisane profile rzeczywistych rewizji pakietu FFmpeg 8.1.2 z
  dostępnym NVENC. Testy weryfikują listy encoderów i filtrów oraz opcje
  `h264_nvenc`, w tym zakresy, wartości domyślne i enumy.
- Dodano narzędzie do zapisywania pełnego profilu dowolnego binarium FFmpeg
  (`-h full` i listy możliwości), aby kolejne buildy — w szczególności stockowy
  albo Windows — można było dołączyć jako regresję bez zmiany mechanizmu testu.
- Poprawiono rozpoznawanie typu filtra dla wielu wejść tego samego typu, na
  przykład `AA->A`; taki filtr jest teraz poprawnie katalogowany jako audio.

### Postęp zadań FFmpeg

- Kolejka zadań automatycznie dodaje do poleceń FFmpeg `-progress pipe:1` i
  `-nostats`, a następnie odczytuje rekordy `key=value` ze standardowego
  wyjścia. Terminal eksperta nie jest przez to zmieniany.
- Widok aktywnego zadania pokazuje dane strukturalne, takie jak liczba klatek,
  czas wyjściowy i szybkość, niezależnie od formatu komunikatów `stderr`.
- Kolejka zachowuje własne `-progress`, `pipe:1` i wszystkie polecenia inne niż
  FFmpeg bez zmian, aby nie psuć świadomie skonfigurowanego wyjścia użytkownika.
- Test integracyjny kolejki potwierdza przekazanie nowych argumentów do procesu
  i aktualizację widocznego postępu po otrzymaniu rekordów FFmpeg.

### Fundament `filter_complex`

- Kreator poleceń otrzymał osobny edytor surowego wyrażenia `filter_complex`.
  Graf jest przekazywany do FFmpeg jako pojedynczy argument, a mapowanie jego
  wyjść pozostaje świadomie edytowalne przez zwykłe opcje `-map`.
- Dodano podstawową walidację łańcuchów filtrów: cytaty, nawiasy etykiet,
  referencje wejść oraz wyświetlanie wykrytych etykiet. Nieprawidłowy graf nie
  może zostać dodany do kolejki.
- Jest to kompatybilny tekstowy fallback dla przyszłego edytora węzłów; nie
  próbuje on ograniczać poprawnych, zaawansowanych wyrażeń FFmpeg.
- Mapa projektu wskazuje zarówno model i usługę grafu, jak i edytor surowego
  wyrażenia w ekranie Kreator.

### Wydajność katalogu

- Dodano indeks FTS5 z tokenizerem trigramowym dla nazw, opisów i flag
  komponentów. Wyszukiwanie fragmentu, np. `x264` w `libx264`, nie wymaga już
  skanowania całej tabeli zwykłym `LIKE`.
- Gdy lokalna SQLite nie udostępnia FTS5, aplikacja bezpiecznie wraca do
  poprzedniego zapytania `LIKE`; katalog pozostaje dostępny.
- Ekran katalogu odrzuca spóźnione wyniki starszego zapytania, nadal stosuje
  debounce i listę budowaną leniwie, a użytkownik widzi liczbę wyników oraz
  informację o osiągniętym limicie.
- Test dużego katalogu sprawdza wyszukiwanie fragmentu i limit 25 wyników.
- Pełna walidacja Fluttera obejmuje obecnie 70 przechodzących testów.

### Szczegółowy zakres automatycznej walidacji

- Konfiguracja SSOT i ustawienia użytkownika: walidacja domyślnych wartości,
  zapis JSON, odzyskiwanie uszkodzonego pliku, reset ustawień oraz wybór języka.
- Parser i katalog FFmpeg: zakresy, wartości domyślne, enumy, flagi mediów,
  nieznane linie, profile rzeczywistych buildów NVENC, SQLite, fingerprinty,
  błędy sekcji, anulowanie skanu i wyszukiwanie dużego katalogu.
- Wykonywanie procesów: argumenty ze spacjami i Unicode, brak powłoki,
  rozdzielenie `stdout`/`stderr`, wejście `stdin`, błąd uruchomienia,
  zatrzymanie aktywnego procesu i poprawne zamykanie usług.
- Kolejka: ręczne rozpoczęcie, kolejność etapów workflow, anulowanie, log na
  żywo, strukturalny postęp FFmpeg oraz uruchamianie kolejnego zadania dopiero
  po zakończeniu poprzedniego.
- Interfejs: smoke testy ekranów, ręczne ścieżki binariów, katalog i debounce,
  terminal FFmpeg/FFprobe, skrypty, kreator opcji i ścieżek, `filter_complex`,
  edycja workflow oraz przycisk uruchomienia kolejki.
- Inspektor i skrypty: poprawne, uszkodzone i niedostępne pliki, integracja
  FFprobe/ExifTool, bezpieczny import `.sh`, katalog domyślny lub wybrany przez
  użytkownika oraz okno pomocy skryptów.

### Uruchamianie testów

- Dodano `tools/run-tests.sh`, który automatycznie przekazuje Flutterowi cały
  bieżący zestaw testów, pokazuje ich postęp na żywo i wypisuje liczbę wykrytych
  plików, wynik oraz czas wykonania. Dodanie nowego pliku `*_test.dart` nie
  wymaga modyfikacji skryptu.

## 1.0.0

### Wydanie 1.0

- Ustalono oficjalną wersję aplikacji na `1.0`. Wartość wyświetlana przez
  interfejs pochodzi z `app_config.dart`, a techniczna wersja pakietu Fluttera
  została ustawiona na zgodne `1.0.0+1`.

### Fundament aplikacji

- Utworzono projekt Flutter Desktop przeznaczony dla Linuxa i Windowsa.
- Dodano główną nawigację oraz polski interfejs przygotowany do późniejszej
  lokalizacji.
- Rozdzielono modele danych, logikę usług, stan aplikacji i warstwę interfejsu.
- Dodano diagnostykę startową oraz czytelny ekran błędu, gdy konfiguracja
  aplikacji jest nieprawidłowa.

### FFmpeg i katalog możliwości

- Dodano automatyczne wykrywanie lokalnych programów FFmpeg i FFprobe oraz
  możliwość ręcznego wskazania ich ścieżek.
- Program odczytuje wersję i konfigurację kompilacji obu narzędzi.
- Dodano dynamiczny skan opcji, kodeków, encoderów, decoderów, filtrów,
  formatów, urządzeń, protokołów i akceleracji dostępnych lokalnie.
- Katalog można przeszukiwać i filtrować według kategorii oraz rodzaju mediów.
- Szczegółowa pomoc komponentów jest pobierana dopiero po ich otwarciu.
- Pełne, nierozpoznane fragmenty pomocy są zachowywane jako dane surowe.

### Pamięć katalogu

- Dodano lokalny cache SQLite powiązany z fingerprintem pary FFmpeg/FFprobe.
- Aktualizacja ścieżki, wersji lub konfiguracji któregoś narzędzia powoduje
  utworzenie nowego katalogu.
- Przerwany albo nieudany skan nie jest uznawany za gotowy i nie zostanie użyty
  przy następnym uruchomieniu.
- Dodano wersjonowane migracje bazy danych.

### Inspektor FFprobe

- Dodano wybieranie i przeciąganie plików do analizy.
- Wyniki są prezentowane jako podsumowanie, strumienie, metadane i surowy JSON.
- Dodano eksport JSON oraz zaawansowane opcje wyboru wpisów, strumieni,
  przedziałów, pakietów i ramek.
- Ustawienia inspektora są zapamiętywane pomiędzy uruchomieniami.
- Dodano opcjonalną integrację z programem ExifTool wykrywanym w `PATH`.
  Inspektor żąda duplikatów, nieznanych tagów, danych osadzonych i dodatkowych
  tagów `RequestAll`, a następnie łączy wynik z metadanymi formatu, strumieni i
  rozdziałów FFprobe.
- Metadane ExifTool oraz FFprobe są prezentowane w oddzielnych, grupowanych
  sekcjach ładowanych dopiero po rozwinięciu grupy, co ogranicza koszt
  renderowania dużych wyników.
- Zakładka surowego JSON i eksport zawierają teraz połączony wynik FFprobe,
  stan ExifTool, ewentualny błąd oraz wszystkie odczytane tagi.
- Brak ExifTool nie blokuje analizy FFprobe; zakładka metadanych pokazuje wtedy
  instrukcję instalacji pakietu `perl-image-exiftool`.
- Dodano formularz dodawania i nadpisywania pojedynczego tagu metadanych oraz
  przyciski edycji przy obsługiwanych grupach. Przed zapisem program informuje
  o modyfikacji pliku, przekazuje nazwę i wartość jako oddzielny argument bez
  powłoki, a po powodzeniu ponownie analizuje dane.
- Przy pierwszej zmianie ExifTool zachowuje pierwotny plik z końcówką
  `_original`. Kolejne zmiany nie zastępują tej pierwszej kopii bezpieczeństwa.

### Terminal eksperta

- Dodano terminal uruchamiający wyłącznie FFmpeg albo FFprobe bez pośrednictwa
  powłoki systemowej.
- Dodano obsługę ścieżek ze spacjami, cudzysłowów i znaków Unicode.
- Rozdzielono widoki stdout i stderr oraz dodano widok połączony.
- Dodano stdin, zatrzymywanie procesu, kod zakończenia, czas działania i
  kopiowanie logów.
- Dodano ostrzeżenie przed możliwym nadpisaniem pliku.
- Dodano historię bieżącej sesji oraz tryb prywatny, który nie zapisuje
  polecenia w historii.
- Treść argumentów terminala nie jest zapisywana między uruchomieniami.
  Istniejący wpis `terminal.defaultArguments` ze starszego `options.json` jest
  automatycznie usuwany, natomiast wybór FFmpeg albo FFprobe pozostaje
  ustawieniem użytkownika.

### Kreator, skrypty i kolejka

- Dodano kreator wielu wejść i wyjść z zachowaniem kolejności argumentów
  wymaganej przez FFmpeg.
- Opcje można przypisywać do zakresu globalnego, wejścia, wyjścia lub
  strumienia.
- Wygenerowane polecenie można skopiować, przenieść do terminala albo dodać do
  kolejki.
- Dodano sekwencyjną kolejkę z pauzą, zatrzymaniem, ponawianiem i logami.
- Dodanie polecenia do kolejki nie uruchamia już procesu. Ekran zadań otrzymał
  osobny przycisk `Uruchom kolejkę`, który wykonuje oczekujące zadania kolejno.
- Wstrzymanie aktywnej kolejki pozwala dokończyć bieżące zadanie, ale nie
  uruchamia następnego. Zatrzymanie procesu również zatrzymuje dalsze
  wykonywanie kolejki.
- Na ekranie zadań stale wyświetla się konsola bieżącego procesu z poleceniem,
  wyjściem standardowym, wyjściem błędów i przyciskiem zatrzymania. Każde
  zadanie ma również jednoznaczny polski opis aktualnego stanu.
- Widok zakończonego zadania pokazuje raport każdego etapu: dokładne polecenie,
  kod zakończenia, czas wykonania oraz oddzielne sekcje `stdout` i
  `stderr/postęp FFmpeg`. Pełny log można skopiować jednym przyciskiem.
- Konsola zachowuje kolejność komunikatów odbieranych na żywo. Po zakończeniu
  raport korzysta z kompletnego wyniku sesji procesu, również gdy bardzo
  krótki proces wypisał dane przed pojawieniem się podglądu. Znaki powrotu
  karetki używane przez postęp FFmpeg są zamieniane na czytelne wiersze.
- Dla poleceń używających `-loglevel error` raport wyjaśnia, że brak informacji
  o wejściu, mapowaniu i kodekach wynika z poziomu logowania wybranego w
  skrypcie, a nie z błędu konsoli.
- Usunięto uproszczone karty presetów, które przekazywały do terminala
  niekompletne argumenty z symbolami zastępczymi.
- Dodano oddzielny ekran `Skrypty`. Program podczas startu oraz po ręcznym
  odświeżeniu analizuje bezpośrednio pliki `.sh` bez dodatkowych manifestów.
- Importer rozpoznaje przypisania, wartości początkowe, pytania `read`,
  zmienne, tablice argumentów oraz jedno lub wiele wywołań FFmpeg. Wykryte
  pytania i nierozwiązane wartości stają się polami formularza.
- Program automatycznie proponuje tytuły, bezpieczne nazwy, ścieżki wynikowe,
  wariant kopiowania albo kodowania audio oraz filtry Shorta. Każda propozycja,
  a także wykryte parametry jakości, kodeki, bitrate i preset, pozostają
  edytowalne i mogą zostać przywrócone do wartości automatycznej.
- Importer udostępnia również `LOG_LEVEL` i `STATS_PERIOD` jako edytowalne pola,
  dzięki czemu użytkownik może zachować oszczędny log `error` albo wybrać
  dokładniejszy poziom, na przykład `info`.
- Importer tworzy edytowalne pola także dla pozostałych literalnych opcji
  FFmpeg. Przełączniki bez wartości, między innymi `-hide_banner`, `-stats`
  i `-shortest`, można niezależnie wyłączyć bez pozostawiania pustego argumentu.
- Przed potwierdzeniem dodania workflow do kolejki otwiera się osobne okno
  ręcznej edycji końcowej listy argumentów każdego etapu. Edytor ponownie
  rozdziela argumenty z uwzględnieniem cudzysłowów, pozwala przywrócić wynik
  wygenerowany z formularza i nie pozwala zmienić programu wykonywalnego.
- Nazwa importowanego zadania pochodzi z głównego nagłówka skryptu, a nie z
  nagłówka pomocniczego umieszczonego wewnątrz funkcji.
- Formularz blokuje dodanie do kolejki, dopóki wymagane pliki i zmienne nie są
  kompletne. Przed dodaniem pokazuje pełne argumenty wszystkich etapów i prosi
  o potwierdzenie.
- Dane formularzy skryptów są wyłącznie sesyjne i nigdy nie są zapisywane w
  `options.json`.
- Domyślnym źródłem skryptów jest wyłącznie katalog `skrypty/` obok
  uruchomionego pliku wykonywalnego. Program nie przeszukuje już katalogu
  roboczego, katalogu danych aplikacji ani prywatnych skryptów dołączonych do
  pakietu.
- Dla AppImage katalog `skrypty/` znajduje się obok pliku `.AppImage`, a nie
  w jego montowanym, tylko do odczytu wnętrzu. Skrypty prywatne nie są
  kopiowane do paczki AppImage; build Windows tworzy pusty katalog `skrypty/`
  obok pliku EXE.
- W Ustawieniach dodano wybór innego istniejącego katalogu skryptów. Wybrana
  ścieżka jest zapisywana jako nadpisanie użytkownika, od razu skanowana i może
  zostać jednym przyciskiem przywrócona do domyślnego katalogu obok programu.
- Nierozpoznane lub niebezpieczne polecenia systemowe są raportowane i nie są
  wykonywane. Kolejka otrzymuje wyłącznie kompletne polecenia FFmpeg bez
  uruchamiania Basha.
- Kolejkę rozszerzono o workflow zawierające wiele etapów. Wszystkie etapy
  jednego skryptu tworzą jedno zadanie, są wykonywane po kolei i mają wspólny
  log z oznaczeniem aktualnego kroku.
- Zakładka `Skrypty` otrzymała osobne okno pomocy podzielone na opis działania,
  obsługiwane konstrukcje, ograniczenia importera i kompletny przykład `.sh`.
  Przykład można skopiować bezpośrednio z okna.
- Formularz dodawania argumentu rozszerzono o rozwijany selektor wszystkich
  opcji z aktywnego katalogu lokalnego FFmpeg. Lista obsługuje wyszukiwanie po
  nazwie, opisie, flagach i rodzaju mediów, sortowanie A–Z, Z–A albo według
  rodzaju oraz filtrowanie audio, wideo, napisów, danych i załączników.
- Wybrana pozycja wypełnia edytowalne pole opcji i pokazuje oryginalny opis
  FFmpeg, flagi, typ wartości, wartość domyślną, zakres oraz dozwolone wartości,
  jeśli parser je rozpoznał. Nadal można wpisać własną nazwę i wartość.
- Sortowanie i filtr kreatora są zapisywane w `options.json`, a sama lista
  pozostaje dynamiczna i zależna od wykrytej kompilacji FFmpeg.
- Pola ścieżek wejściowych i wyjściowych otrzymały przycisk usuwający jednym
  kliknięciem całą wpisaną zawartość.
- Widoczną nazwę ekranu `Katalog` zmieniono na `Możliwości`, a jego nagłówek na
  `Możliwości FFmpeg i FFprobe`, aby jednoznacznie informować, że ekran pokazuje
  opcje i komponenty odczytane z lokalnych programów.

### Konfiguracja SSOT

- Wprowadzono jedno źródło domyślnych opcji aplikacji pod stałą, łatwą do
  zapamiętania nazwą `app_config.dart`.
- Dodano do SSOT nazwę i wyświetlaną wersję aplikacji, ustawioną obecnie na
  `0.1`; interfejs pobiera ją bezpośrednio z konfiguracji zamiast powielać
  numer wersji.
- Zmiany użytkownika są zapisywane osobno w pliku `options.json`.
- Plik użytkownika przechowuje wyłącznie wartości zmienione względem domyślnych.
- Podczas startu brakujące ustawienia użytkownika są rekurencyjnie uzupełniane
  wartościami z SSOT.
- Dodano walidację typów, wymaganych kluczy i dozwolonych wartości.
- Konfiguracją objęto motyw, ścieżki binariów, autoskan, katalog, terminal,
  inspektor, katalog skryptów i początkowy stan kolejki. Pusta domyślna
  wartość `scripts.directoryPath` oznacza katalog `skrypty/` obok programu.
- Ekran Ustawienia otrzymał przełącznik języka polskiego i angielskiego.
  Wybrane locale jest zapisywane jako `ui.locale` w `options.json`, stosowane
  natychmiast bez restartu i przywracane podczas następnego uruchomienia.
- Domyślny język nowych instalacji i konfiguracji po przywróceniu ustawień
  zmieniono z polskiego na angielski. Istniejące nadpisanie użytkownika nadal
  ma pierwszeństwo.
- Dodano centralną warstwę lokalizacji PL/EN obejmującą nawigację, nagłówki,
  przyciski, formularze, okna dialogowe, pomoc importera, kolejkę oraz
  podstawowe komunikaty. Oryginalne opisy FFmpeg, argumenty, nazwy plików i
  logi procesów nie są automatycznie tłumaczone.
- Wersja jest widoczna w głównej nawigacji, ekranie informacji oraz oknie
  licencji.
- Domyślny motyw ustawiono jako zgodny z motywem systemowym; wybór zapisany
  wcześniej przez użytkownika nadal ma pierwszeństwo.
- Dodano przycisk przywracania wszystkich ustawień domyślnych z oknem
  potwierdzenia. Reset usuwa nadpisania z `options.json`, ponownie stosuje
  wartości z `app_config.dart`, odświeża wykrywanie binariów i przebudowuje
  ekrany bez usuwania katalogu możliwości, zadań ani plików użytkownika.
- Uszkodzony składniowo albo niezgodny z modelem `options.json` nie zatrzymuje
  już startu. Program kopiuje go do pliku `options.invalid-<czas>.json`,
  zastępuje nadpisania pustym obiektem, uruchamia pełne wartości z SSOT i
  pokazuje ostrzeżenie ze ścieżką do zachowanej kopii. Nieprawidłowy wbudowany
  SSOT nadal jest traktowany jako błąd aplikacji i zatrzymuje start.

### Budowanie i uruchamianie

- Dodano build release dla Linuxa oraz natywne szkielety Linux i Windows.
- Skrypt budowania AppImage automatycznie korzysta z `linuxdeploy`, a gdy go
  brakuje, używa dostępnego `appimagetool`. Przed pakowaniem sprawdza wymagane
  pliki, czytelnie wskazuje etap ewentualnego błędu i zawsze umieszcza wynik w
  katalogu `export`.
- Kolejne uruchomienie skryptu usuwa wcześniejsze pliki AppImage z katalogu
  eksportu. Udany build pozostawia dokładnie jeden samodzielny plik o nazwie
  `FFmpeg_UI-<architektura>.AppImage`, niezależnie od numeru wersji aplikacji.
- Dodano skrypt Windows budujący plik EXE i kopiujący kompletny bundle wymagany
  do jego uruchomienia.
- Dodano ikonę i metadane aplikacji dla paczki Linux.
- Dodano konfiguracje panelu VS Code „Uruchom i debuguj” dla Linuxa i Windowsa,
  osobno w trybach debug oraz release.

### Repozytorium GitHub

- Dodano automatyczną walidację Linux dla zmian trafiających na gałąź `main`
  i pull requestów. Kontrola obejmuje formatowanie, analizę, wszystkie testy
  oraz build release.
- Dodano formularze zgłoszenia błędu i propozycji funkcji, szablon pull
  requestu, zasady współtworzenia, zasady społeczności oraz instrukcję
  prywatnego zgłaszania podatności.
- Rozszerzono ignorowanie plików o lokalne ustawienia użytkownika, bazy SQLite,
  sekrety, środowiska `.env`, raporty pokrycia i lokalne narzędzia pakujące.
- Dodano kontrolę zakończeń linii, aby skrypty bashowe zachowywały format LF,
  a skrypty BAT format CRLF na wszystkich systemach.
- Dodano instrukcję pierwszej publikacji, zabezpieczenia gałęzi, konfiguracji
  prywatnych zgłoszeń bezpieczeństwa i umieszczania AppImage w GitHub Releases
  bez commitowania artefaktu do historii.
- Przywrócono wyświetlaną wersję aplikacji do ustalonej wartości `0.1`, zgodnej
  z testem SSOT i techniczną wersją pakietu `0.1.0`.
- Test SSOT weryfikuje teraz jedynie obecność wersji, dzięki czemu ręczna zmiana
  numeru w `app_config.dart` nie wymaga modyfikowania testu.
- W informacjach „O aplikacji” dodano autora `Morl / Morloook` oraz kontakt
  `git@vms.net.pl`.
- Dodano licencję MIT, opis autora i kontaktu w README oraz zaproszenie do
  dobrowolnego zgłaszania wykorzystania kodu przez e-mail. Kontakt e-mail jest
  również awaryjną drogą prywatnego zgłaszania podatności i problemów
  społecznościowych.

### Dokumentacja

- Publiczne nazwy plików dokumentacji zmieniono na angielskie:
  `installation.md`, `configuration.md`, `project_map.md`,
  `project_plan.md` i `github_publication.md`. Poprawiono odnośniki w obu
  wersjach README, zasadach współtworzenia oraz mapie projektu.
- Dokumentacja publiczna zachowuje angielski tekst jako wersję domyślną dla
  GitHuba, a każdy plik z `docs/` otrzymał równoległą sekcję polską. Dodano
  też osobny polski plik `README.pl.md`; oba README prowadzą do drugiej wersji
  językowej. Prywatny changelog pozostaje wyłącznie po polsku.
- Utworzono instrukcję instalacji i dystrybucji dla Linuxa i Windowsa.
- Opisano zasady konfiguracji SSOT i pliku ustawień użytkownika.
- Utworzono mapę projektu z opisem struktury, działania programu i
  odpowiedzialności wszystkich plików źródłowych.
- Sekcję testów w mapie projektu uzupełniono o drzewo plików z krótkim opisem,
  liczbą testów w każdym pliku oraz aktualną liczbą wszystkich testów.
- Zachowano pierwotny plan prac jako osobny dokument projektowy.

### Poprawki

- Poprawiono parser, który początkowo odrzucał prawidłowe wpisy encoderów
  zaczynające się flagą audio lub wideo.
- Poprawiono obsługę globalnych opcji bez flag AVOption.
- Przyspieszono zapis dużego katalogu przez grupowanie operacji SQLite.
- Rozszerzono unieważnianie cache tak, aby uwzględniało zarówno FFmpeg, jak i
  FFprobe.
- Poprawiono ignorowanie plików, aby zasoby aplikacji mogły być wersjonowane,
  a lokalne media i artefakty nadal pozostawały poza repozytorium.

### Diagnostyka i zamykanie

- Dodano wspólny format logów debugowych z czasem, poziomem i nazwą modułu.
- Dodano komunikaty diagnostyczne dla startu, konfiguracji, wykrywania
  binariów, SQLite, skanowania katalogu, FFprobe, procesów i kolejki.
- Logowanie poleceń nie ujawnia pełnej listy argumentów ani ścieżki
  analizowanego pliku.
- Dodano obserwację cyklu życia głównego okna, przechwycenie natywnego
  zamknięcia na Linuxie i Windowsie oraz wykrywanie odłączenia aplikacji.
- Podczas poprawnego zamknięcia anulowany jest skan, zatrzymywane są aktywne
  procesy, a baza SQLite zostaje zamknięta.
- Po rozpoczęciu zamykania runner nie przyjmuje nowych procesów.
- Zdiagnozowano zawieszenie startu uruchamianego przez debugger VS Code.
  Kontrola `quick_check` potwierdziła prawidłową bazę i schemat, a uruchomienie
  bez adaptera otworzyło ten sam plik poprawnie. Przyczyną był zatrzymany przez
  `--start-paused` dodatkowy izolat `sqflite_common_ffi`.
- Build debug otwiera teraz SQLite bez dodatkowego izolatu, natomiast build
  release nadal wykonuje operacje bazy w izolacie roboczym. Dodano również
  konfigurowalny limit czasu otwierania; po jego przekroczeniu ekran startowy
  pokazuje błąd zamiast pozostawać bez końca na animacji ładowania.

### Weryfikacja

- Analiza statyczna Fluttera zakończyła się bez problemów.
- Dodano testy parsera, argumentów, bezpieczeństwa procesów, kolejności
  poleceń, konfiguracji SSOT i fallbacku ustawień.
- Dodano test integracyjny prawdziwego FFprobe dla ścieżki ze spacją i polskim
  znakiem.
- Zbudowano i uruchomiono wersje Linux debug oraz release.
- Zweryfikowano pełny skan lokalnego FFmpeg 8.1.2 i poprawne migracje SQLite.
- Walidacja projektu obejmuje obecnie 35 przechodzących testów.
- Dodano test zatrzymania aktywnego procesu i blokady nowych uruchomień po
  zamknięciu runnera.
- Dodano test potwierdzający, że reset zapisuje pusty obiekt JSON i przywraca
  wartości SSOT.
- Dodano test migracji usuwającej zapamiętane argumenty terminala oraz test
  rzeczywistego zapisu metadanych z zachowaniem kopii `_original`.
- Dodano test odzyskiwania uszkodzonego `options.json`, zachowania jego
  oryginalnej treści w kopii i uruchomienia wartości domyślnych z SSOT.
- Dodano test widgetu selektora kreatora, opisu opcji oraz automatycznego
  uzupełnienia pola argumentu.
- Dodano test czyszczenia całej ścieżki wejściowej bez naruszania ścieżki
  wyjściowej.
- Dodano test potwierdzający, że samo dodanie zadania nie uruchamia procesu,
  a wykonanie rozpoczyna się dopiero po świadomym uruchomieniu kolejki.
- Dodano testy importu ogólnych plików `.sh` bez manifestu, kompletności
  generowanych poleceń oraz sekwencyjnego wykonania wieloetapowego workflow.
- Dodano test okna pomocy, jego ograniczeń i zgodnego przykładu skryptu.
- Dodano test zachowania kolejności `stdout` i `stderr` w konsoli oraz test
  wyboru głównego nagłówka skryptu i edytowalnych ustawień szczegółowości logu.
- Dodano test wyłączania literalnego przełącznika FFmpeg oraz test ręcznej
  edycji końcowych argumentów bez możliwości zmiany programu wykonywalnego.
- Dodano test angielskiego interfejsu oraz test zapisu i ponownego odczytu
  języka użytkownika z `options.json`.
- Dodano test wykrywania katalogu `skrypty/` obok pliku wykonywalnego, test
  zastąpienia go katalogiem wybranym przez użytkownika oraz test zapisu i
  ponownego odczytu tej ścieżki z `options.json`.
