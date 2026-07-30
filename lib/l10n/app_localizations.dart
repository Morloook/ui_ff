import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('pl'), Locale('en')];

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations) ??
      const AppLocalizations(Locale('pl'));

  bool get isEnglish => locale.languageCode == 'en';

  String translate(String source) {
    if (!isEnglish || source.isEmpty) return source;
    final exact = _english[source];
    if (exact != null) return exact;
    return _translateDynamic(source);
  }

  String _translateDynamic(String source) {
    final replacements = <(RegExp, String Function(Match))>[
      (RegExp(r'^Wejście (\d+)$'), (match) => 'Input ${match.group(1)}'),
      (RegExp(r'^Wyjście (\d+)$'), (match) => 'Output ${match.group(1)}'),
      (RegExp(r'^Etapy: (.+)$'), (match) => 'Steps: ${match.group(1)}'),
      (RegExp(r'^Czas: (.+)$'), (match) => 'Duration: ${match.group(1)}'),
      (
        RegExp(r'^Kod zakończenia: (.+)$'),
        (match) => 'Exit code: ${match.group(1)}',
      ),
      (
        RegExp(
          r'^Oczekujące: (\d+)\. Dodanie zadania nie uruchamia go automatycznie\.$',
        ),
        (match) =>
            'Waiting: ${match.group(1)}. Adding a job does not start it automatically.',
      ),
      (RegExp(r'^Flagi: (.+)$'), (match) => 'Flags: ${match.group(1)}'),
      (RegExp(r'^Domyślnie: (.+)$'), (match) => 'Default: ${match.group(1)}'),
      (
        RegExp(r'^Etap (\d+)/(\d+): (.+)$'),
        (match) =>
            'Step ${match.group(1)}/${match.group(2)}: ${match.group(3)}',
      ),
      (
        RegExp(r'^Nie znaleziono plików \.sh\.\nDodaj pliki do: (.+)$'),
        (match) => 'No .sh files were found.\nAdd files to: ${match.group(1)}',
      ),
      (
        RegExp(r'^Walidacja podstawowa: poprawna\. Etykiety: (.+)$'),
        (match) => 'Basic validation: valid. Labels: ${match.group(1)}',
      ),
      (
        RegExp(r'^Nie można pobrać szczegółów opcji: (.+)$'),
        (match) => 'Unable to load option details: ${match.group(1)}',
      ),
      (RegExp(r'^Uzupełnij: (.+)$'), (match) => 'Complete: ${match.group(1)}'),
      (
        RegExp(r'^Kopia oryginału: (.+)$'),
        (match) => 'Original backup: ${match.group(1)}',
      ),
      (
        RegExp(r'^ExifTool · (\d+) tagów$'),
        (match) => 'ExifTool · ${match.group(1)} tags',
      ),
      (
        RegExp(r'^FFprobe · (\d+) tagów$'),
        (match) => 'FFprobe · ${match.group(1)} tags',
      ),
    ];
    for (final (pattern, replacement) in replacements) {
      final match = pattern.firstMatch(source);
      if (match != null) return replacement(match);
    }
    return source
        .replaceAll(
          'Dodanie zadania nie uruchamia go automatycznie.',
          'Adding a job does not start it automatically.',
        )
        .replaceAll(
          'Aplikacja nie zawiera binariów FFmpeg. Korzysta z narzędzi '
              'zainstalowanych lokalnie przez użytkownika.',
          'The application does not include FFmpeg binaries. It uses tools '
              'installed locally by the user.',
        )
        .replaceAll('Autor:', 'Author:')
        .replaceAll('Kontakt:', 'Contact:')
        .replaceAll('zmieniono ręcznie', 'changed manually')
        .replaceAll('Zakończono poprawnie', 'Completed successfully')
        .replaceAll('Oczekuje na uruchomienie', 'Waiting to start')
        .replaceAll('W trakcie', 'Running')
        .replaceAll('Anulowano', 'Cancelled')
        .replaceAll('Metadane zostały zapisane.', 'Metadata has been saved.')
        .replaceAll(
          'Nie można przywrócić ustawień:',
          'Unable to restore settings:',
        )
        .replaceAll(
          'Nie można zmienić katalogu skryptów:',
          'Unable to change scripts directory:',
        )
        .replaceAll('Nie zapisano metadanych:', 'Metadata was not saved:')
        .replaceAll(
          'Wartość wykrywana lub wyliczana automatycznie; można ją zmienić.',
          'The value is detected or calculated automatically and can be changed.',
        )
        .replaceAll(
          'Wartość wymagana przez pytanie w skrypcie.',
          'A value required by a prompt in the script.',
        )
        .replaceAll(
          'Przełącznik odczytany bezpośrednio z polecenia FFmpeg.',
          'A switch read directly from the FFmpeg command.',
        )
        .replaceAll(
          'Wartość opcji odczytana bezpośrednio z polecenia FFmpeg.',
          'An option value read directly from the FFmpeg command.',
        );
  }

  static const _english = <String, String>{
    'Środowisko': 'Environment',
    'Możliwości': 'Capabilities',
    'Inspektor': 'Inspector',
    'Terminal': 'Terminal',
    'Kreator': 'Builder',
    'Skrypty': 'Scripts',
    'Zadania': 'Jobs',
    'Ustawienia': 'Settings',
    'Ustawienia i informacje': 'Settings and information',
    'Zmiany są zapisywane jako JSON użytkownika i łączone z SSOT.':
        'Changes are saved in the user JSON and merged with the SSOT.',
    'Konfiguracja aplikacji': 'Application configuration',
    'Wartości domyślne pochodzą wyłącznie z lib/core/app_config.dart. Plik użytkownika zawiera tylko zmienione wartości.':
        'Default values come exclusively from lib/core/app_config.dart. The user file contains only changed values.',
    'Motyw': 'Theme',
    'Zgodny z systemem': 'Follow system',
    'Jasny': 'Light',
    'Ciemny': 'Dark',
    'Język interfejsu': 'Interface language',
    'Polski': 'Polish',
    'Angielski': 'English',
    'Automatycznie skanuj po pierwszym uruchomieniu':
        'Scan automatically on first launch',
    'Aktualny cache nadal jest wczytywany automatycznie.':
        'The current cache is still loaded automatically.',
    'Ostrzegaj przed możliwym nadpisaniem': 'Warn before possible overwrite',
    'Plik ustawień użytkownika:': 'User settings file:',
    'Kopiuj ścieżkę': 'Copy path',
    'Przywróć ustawienia domyślne': 'Restore default settings',
    'Przywrócić ustawienia domyślne?': 'Restore default settings?',
    'Wszystkie ustawienia zapisane przez użytkownika zostaną usunięte z options.json. Program ponownie zastosuje wartości z app_config.dart i odświeży interfejs.\n\nKatalog możliwości, zadania i pliki użytkownika nie zostaną usunięte.':
        'All user-saved settings will be removed from options.json. The application will apply values from app_config.dart again and refresh the interface.\n\nThe capabilities catalog, jobs, and user files will not be deleted.',
    'Przywróć domyślne': 'Restore defaults',
    'Przywrócono ustawienia domyślne.': 'Default settings restored.',
    'Anuluj': 'Cancel',
    'Baza możliwości': 'Capabilities database',
    'Brak przeskanowanych możliwości': 'No scanned capabilities',
    'Katalog skryptów obok programu':
        'Scripts directory next to the application',
    'Katalog skryptów': 'Scripts directory',
    'Domyślny: obok programu': 'Default: next to the application',
    'Wybrany przez użytkownika': 'Selected by user',
    'Wybierz katalog skryptów': 'Choose scripts directory',
    'Użyj domyślnego katalogu': 'Use default directory',
    'Zmieniono katalog skryptów.': 'Scripts directory changed.',
    'Przywrócono domyślny katalog skryptów.':
        'Default scripts directory restored.',
    'Nie można zmienić katalogu skryptów:':
        'Unable to change scripts directory:',
    'Niedostępny': 'Unavailable',
    'Uruchamianie procesów': 'Process execution',
    'Bez powłoki systemowej. Terminal uruchamia wyłącznie ffmpeg/ffprobe.':
        'No system shell. The terminal runs only ffmpeg/ffprobe.',
    'O aplikacji': 'About',
    'Aplikacja nie zawiera binariów FFmpeg. Korzysta z narzędzi zainstalowanych lokalnie przez użytkownika.':
        'The application does not include FFmpeg binaries. It uses tools installed locally by the user.',
    'Licencje zależności Flutter': 'Flutter dependency licenses',
    'Wykrywanie FFmpeg i przygotowanie listy możliwości…':
        'Detecting FFmpeg and preparing the capabilities list…',
    'Nie można uruchomić aplikacji': 'The application could not be started',
    'Środowisko FFmpeg': 'FFmpeg environment',
    'Wykryte narzędzia i możliwości tej instalacji FFmpeg.':
        'Detected tools and capabilities of this FFmpeg installation.',
    'Ścieżka do ffmpeg': 'Path to ffmpeg',
    'Ścieżka do ffprobe': 'Path to ffprobe',
    'Skanuj możliwości': 'Scan capabilities',
    'Sprawdź ścieżki': 'Check paths',
    'Konfiguracja kompilacji': 'Build configuration',
    'Możliwości nie zostały jeszcze przeskanowane.':
        'Capabilities have not been scanned yet.',
    'Możliwości FFmpeg i FFprobe': 'FFmpeg and FFprobe capabilities',
    'Opcje i komponenty zgłoszone przez lokalne ffmpeg oraz ffprobe.':
        'Options and components reported by the local ffmpeg and ffprobe.',
    'Szukaj nazwy, opisu albo flag…': 'Search name, description, or flags…',
    'Najpierw przeskanuj możliwości na ekranie Środowisko.':
        'Scan capabilities on the Environment screen first.',
    'Odśwież wyniki': 'Refresh results',
    'Wszystkie': 'All',
    'Kategoria': 'Category',
    'Media': 'Media',
    'Brak wyników.': 'No results.',
    'Wybierz element, aby zobaczyć szczegóły.':
        'Select an item to see details.',
    'Opcje': 'Options',
    'Surowa pomoc FFmpeg': 'Raw FFmpeg help',
    'Inspektor FFprobe': 'FFprobe Inspector',
    'Przeciągnij plik albo wybierz go, aby odczytać strukturę i metadane.':
        'Drag or select a file to read its structure and metadata.',
    'Plik źródłowy': 'Source file',
    'Wybierz plik': 'Select file',
    'Wybierz plik wynikowy': 'Select output file',
    'Kopiuj JSON': 'Copy JSON',
    'Zmień ten tag': 'Edit this tag',
    'Eksportuj JSON': 'Export JSON',
    'Analizuj': 'Analyze',
    'Opcje zaawansowane': 'Advanced options',
    'Pakiety': 'Packets',
    'Ramki': 'Frames',
    'Pełne metadane ExifTool': 'Full ExifTool metadata',
    'Upuść plik tutaj': 'Drop the file here',
    'Nie wybrano pliku.': 'No file selected.',
    'Podsumowanie': 'Summary',
    'Strumienie': 'Streams',
    'Metadane': 'Metadata',
    'Surowy JSON': 'Raw JSON',
    'Brak strumieni.': 'No streams.',
    'Dodaj lub zmień': 'Add or change',
    'Zmień metadane pliku': 'Edit file metadata',
    'Nazwa tagu': 'Tag name',
    'Nowa wartość': 'New value',
    'Zapisz metadane': 'Save metadata',
    'Terminal eksperta': 'Expert terminal',
    'Uruchamia wyłącznie lokalne ffmpeg lub ffprobe, bez powłoki systemowej.':
        'Runs only local ffmpeg or ffprobe without a system shell.',
    'Program': 'Program',
    'Argumenty': 'Arguments',
    'Uruchom': 'Run',
    'Zatrzymaj': 'Stop',
    'Możliwe nadpisanie pliku': 'Possible file overwrite',
    'Sesja prywatna — nie dodawaj do historii':
        'Private session — do not add to history',
    'Kopiuj log': 'Copy log',
    'Wyczyść log': 'Clear log',
    'Połączone': 'Combined',
    'Wyślij': 'Send',
    'Historia': 'History',
    'Odpowiedź dla uruchomionego procesu': 'Input for the running process',
    'Kreator polecenia': 'Command builder',
    'Kolejność sekcji odpowiada kolejności argumentów wymaganej przez FFmpeg.':
        'Section order matches the argument order required by FFmpeg.',
    'Opcje globalne': 'Global options',
    'Umieszczane przed wszystkimi wejściami.': 'Placed before all inputs.',
    'Dodaj wejście': 'Add input',
    'Dodaj wyjście': 'Add output',
    'Kopiuj': 'Copy',
    'Do terminala': 'Send to terminal',
    'Dodaj do kolejki': 'Add to queue',
    'Dodano do kolejki.': 'Added to queue.',
    'Dodaj opcję': 'Add option',
    'Dodaj': 'Add',
    'Opcja': 'Option',
    'Wartość (opcjonalna)': 'Value (optional)',
    'Sortowanie': 'Sorting',
    'Szukaj nazwy lub opisu': 'Search name or description',
    'Rodzaj': 'Type',
    'Ścieżka': 'Path',
    'Usuń sekcję': 'Remove section',
    'Wyczyść całą ścieżkę': 'Clear the entire path',
    'Dodaj opcję przed tą ścieżką': 'Add an option before this path',
    'Wybierz skrypt z listy.': 'Select a script from the list.',
    'Skrypty .sh są analizowane bez uruchamiania powłoki. Dane formularza nie są zapisywane.':
        '.sh scripts are analyzed without running a shell. Form data is not saved.',
    'Dane i opcje': 'Data and options',
    'Podgląd workflow': 'Workflow preview',
    'Edytuj końcowe polecenia i dodaj do kolejki':
        'Edit final commands and add to queue',
    'Oryginalna treść skryptu': 'Original script source',
    'Pomoc': 'Help',
    'Odśwież skrypty': 'Refresh scripts',
    'Wybierz katalog': 'Choose directory',
    'Użyj domyślnego': 'Use default',
    'Dodać workflow do kolejki?': 'Add workflow to the queue?',
    'Workflow jest kompletny i gotowy do kolejki.':
        'The workflow is complete and ready for the queue.',
    'Workflow nie jest jeszcze kompletny': 'The workflow is not complete yet',
    'Ręczna edycja końcowych poleceń': 'Manual editing of final commands',
    'Możesz poprawić pełną listę argumentów każdego etapu. Program nadal uruchomi wyłącznie pokazany plik FFmpeg bez Basha, PowerShella ani interpretowania operatorów powłoki.':
        'You can edit the complete argument list for each step. The application will still run only the displayed FFmpeg executable, without Bash, PowerShell, or shell operator interpretation.',
    'Pole jest zablokowane ze względów bezpieczeństwa.':
        'This field is locked for security.',
    'Cudzysłowy grupują jeden argument; składnia powłoki nie jest wykonywana.':
        'Quotes group a single argument; shell syntax is not executed.',
    'Program wykonywalny': 'Executable',
    'Końcowa lista argumentów': 'Final argument list',
    'Przywróć wygenerowane': 'Restore generated',
    'Zastosuj i przejdź dalej': 'Apply and continue',
    'Pomoc — automatyczny importer skryptów':
        'Help — automatic script importer',
    'Zakładka Skrypty zamienia obsługiwany fragment pliku .sh na tymczasowy formularz i bezpieczne argumenty FFmpeg.':
        'The Scripts tab converts supported parts of a .sh file into a temporary form and safe FFmpeg arguments.',
    'Podczas startu program skanuje wyłącznie katalog skrypty obok uruchomionego pliku wykonywalnego.':
        'At startup, the application scans only the skrypty directory next to the running executable.',
    'Przycisk „Odśwież skrypty” ponownie czyta pliki bez restartowania programu.':
        'The “Refresh scripts” button reads the files again without restarting the application.',
    'Wybranie skryptu tworzy pola z jego zmiennych i pytań read.':
        'Selecting a script creates fields from its variables and read prompts.',
    'Opcje zapisane bezpośrednio w poleceniu FFmpeg również stają się polami. Przełączniki bez wartości, np. -hide_banner i -stats, można włączyć albo wyłączyć.':
        'Options written directly in the FFmpeg command also become fields. Valueless switches such as -hide_banner and -stats can be enabled or disabled.',
    'Program automatycznie proponuje między innymi tytuły, ścieżki wynikowe, wariant kodowania audio i filtr Shorta.':
        'The application automatically suggests titles, output paths, an audio encoding variant, and a Short filter.',
    'Każdą propozycję można zmienić. Przycisk przy polu przywraca wartość odczytaną ze skryptu albo wyliczoną automatycznie.':
        'Every suggestion can be changed. The field button restores the value read from the script or calculated automatically.',
    'Dopóki brakuje wymaganej wartości lub pliku, dodanie do kolejki jest zablokowane.':
        'Adding to the queue remains disabled while a required value or file is missing.',
    'Przed ostatecznym potwierdzeniem otwiera się osobny edytor wszystkich argumentów każdego etapu. Program wykonywalny pozostaje zablokowany na wykrytym FFmpeg.':
        'Before final confirmation, a separate editor opens for all arguments of each step. The executable remains locked to the detected FFmpeg.',
    'Kilka poleceń FFmpeg staje się jednym workflow z kolejnymi etapami.':
        'Multiple FFmpeg commands become one workflow with sequential steps.',
    'Formularze są wyłącznie sesyjne i nie są zapisywane w options.json.':
        'Forms are session-only and are not saved in options.json.',
    'Najpewniejszy wynik dają proste skrypty, które przygotowują zmienne, pytają o dane, a następnie wywołują FFmpeg.':
        'Simple scripts that prepare variables, ask for input, and then invoke FFmpeg produce the most reliable result.',
    'Pliki z rozszerzeniem .sh znajdujące się bezpośrednio w katalogu skrypty obok pliku wykonywalnego.':
        'Files with the .sh extension located directly in the skrypty directory next to the executable.',
    'Proste przypisania do zmiennych zapisanych wielkimi literami, np. CRF="20".':
        'Simple assignments to uppercase variables, for example CRF="20".',
    'Jedno albo kilka poleceń rozpoczynających się od ffmpeg.':
        'One or more commands beginning with ffmpeg.',
    'Pliki wejściowe i wynikowe rozpoznawane po nazwach zmiennych, np. INPUT_FILE, AUDIO_FILE, IMAGE_FILE i OUTPUT_FILE.':
        'Input and output files recognized by variable names such as INPUT_FILE, AUDIO_FILE, IMAGE_FILE, and OUTPUT_FILE.',
    'Edytowalne wartości kodeków, CRF, presetu, bitrate, ID3 oraz nadpisywania.':
        'Editable codec, CRF, preset, bitrate, ID3, and overwrite values.',
    'Literalne opcje FFmpeg z wartością oraz przełączniki bez wartości, np. -hide_banner, -stats i -shortest.':
        'Literal FFmpeg options with values and valueless switches such as -hide_banner, -stats, and -shortest.',
    'Własne nazwy zmiennych i ścieżki; brak wbudowanych prywatnych workflow w publicznej wersji programu.':
        'Custom variable names and paths; the public application contains no bundled private workflows.',
    'Importer nie jest interpreterem Basha. Nie uruchamia całego skryptu i nie gwarantuje obsługi dowolnego programu powłoki.':
        'The importer is not a Bash interpreter. It does not run the whole script and does not support arbitrary shell programs.',
    'Nie uruchamia Basha, PowerShella ani cmd.exe.':
        'It does not run Bash, PowerShell, or cmd.exe.',
    'Nie wykonuje poleceń systemowych takich jak rm, mv, cp, sudo, curl, wget, Python albo eval.':
        'It does not execute system commands such as rm, mv, cp, sudo, curl, wget, Python, or eval.',
    'Nie wykonuje własnych programów i funkcji zdefiniowanych w skrypcie.':
        'It does not execute custom programs or functions defined in the script.',
    'Nie odtwarza dowolnych pętli, rekursji, potoków, przekierowań ani dynamicznie tworzonego kodu.':
        'It does not reproduce arbitrary loops, recursion, pipes, redirections, or dynamically generated code.',
    'Nie wysyła do kolejki nierozwiązanych zmiennych ani symboli zastępczych.':
        'It does not send unresolved variables or placeholders to the queue.',
    'Nie zapisuje ścieżek, metadanych, jakości ani innych danych formularza.':
        'It does not save paths, metadata, quality, or other form data.',
    'Skrypt częściowo rozpoznany wymaga sprawdzenia ostrzeżeń i ręcznego uzupełnienia brakujących pól.':
        'A partially recognized script requires reviewing warnings and manually completing missing fields.',
    'Nietypowa lub niejednoznaczna składnia argumentów może wymagać poprawienia w końcowym edytorze polecenia przed kolejką.':
        'Unusual or ambiguous argument syntax may require correction in the final command editor before queueing.',
    'Ten plik zostanie wykryty bez dodatkowego manifestu. Wszystkie wartości użyte przez FFmpeg pojawią się w edytowalnym formularzu.':
        'This file will be detected without an additional manifest. All values used by FFmpeg will appear in an editable form.',
    'Działanie': 'How it works',
    'Rozpoznaje': 'Recognized',
    'Ograniczenia': 'Limitations',
    'Przykład': 'Example',
    'Kopiuj przykład': 'Copy example',
    'Zamknij': 'Close',
    'Kolejka zadań': 'Job queue',
    'Dodanie zadania nie uruchamia go automatycznie.':
        'Adding a job does not start it automatically.',
    'Usuń zakończone': 'Remove completed',
    'Uruchom kolejkę': 'Start queue',
    'Wstrzymaj po bieżącym': 'Pause after current job',
    'Kolejka jest pusta. Dodaj zadanie z kreatora.':
        'The queue is empty. Add a job from the builder.',
    'Zakończono poprawnie': 'Completed successfully',
    'Błąd': 'Error',
    'Anulowano': 'Cancelled',
    'Oczekuje na uruchomienie': 'Waiting to start',
    'W trakcie': 'Running',
    'Ponów': 'Retry',
    'Kopiuj pełny log': 'Copy full log',
    'Skopiowano pełny log zadania.': 'The full job log was copied.',
    'Uruchomione polecenie:': 'Executed command:',
    'Błąd uruchomienia': 'Startup error',
    'Globalna': 'Global',
    'Wejście': 'Input',
    'Wyjście': 'Output',
    'Strumień': 'Stream',
    'Wideo': 'Video',
    'Napisy': 'Subtitles',
    'Dane': 'Data',
    'Załącznik': 'Attachment',
    'Inne': 'Other',
    'Opcje FFmpeg': 'FFmpeg options',
    'Opcje FFprobe': 'FFprobe options',
    'Encodery': 'Encoders',
    'Decodery': 'Decoders',
    'Filtry': 'Filters',
    'Formaty': 'Formats',
    'Urządzenia': 'Devices',
    'Protokoły': 'Protocols',
    'Filtry strumienia bitowego': 'Bitstream filters',
    'Akceleracja sprzętowa': 'Hardware acceleration',
    'Formaty pikseli': 'Pixel formats',
    'Formaty próbek': 'Sample formats',
    'Układy kanałów': 'Channel layouts',
    'Kodeki': 'Codecs',
    'Dyspozycje': 'Dispositions',
    'Nazwy kolorów': 'Color names',
    'Wartość wykrywana lub wyliczana automatycznie; można ją zmienić.':
        'The value is detected or calculated automatically and can be changed.',
    'Wartość wymagana przez pytanie w skrypcie.':
        'A value required by a prompt in the script.',
    'Przełącznik odczytany bezpośrednio z polecenia FFmpeg.':
        'A switch read directly from the FFmpeg command.',
    'Wartość opcji odczytana bezpośrednio z polecenia FFmpeg.':
        'An option value read directly from the FFmpeg command.',
    'Podgląd': 'Preview',
    'Graf filtrów (filter_complex)': 'Filter graph (filter_complex)',
    'Wpisz pełne wyrażenie FFmpeg. Jest przekazywane jako jeden argument -filter_complex; mapowanie wyników dodaj jako opcje wyjścia, np. -map [wynik].':
        'Enter the complete FFmpeg expression. It is passed as one -filter_complex argument; add output mapping as output options, for example -map [result].',
    'Wyrażenie filter_complex': 'filter_complex expression',
    'Walidacja podstawowa: poprawna. Etykiety: brak':
        'Basic validation: valid. Labels: none',
    'Walidacja podstawowa: wykryto błędy.':
        'Basic validation: errors detected.',
    'Nazwa A–Z': 'Name A–Z',
    'Nazwa Z–A': 'Name Z–A',
    'Typ mediów, potem nazwa': 'Media type, then name',
    'Lista lokalnych opcji FFmpeg': 'Local FFmpeg options list',
    'Wybierz pozycję, aby uzupełnić pole opcji i zobaczyć opis.':
        'Select an item to fill the option field and view its description.',
    'Brak pasujących opcji. Możesz wpisać własną.':
        'No matching options. You can enter your own.',
    'Brak opisu w pomocy FFmpeg.': 'No description in FFmpeg help.',
    'Możesz zmienić wybraną opcję albo wpisać własną.':
        'You can change the selected option or enter your own.',
    'Typ wartości:': 'Value type:',
    'Zakres:': 'Range:',
    'Dozwolone:': 'Allowed:',
    'Eksport wyniku inspektora': 'Export inspector result',
    'ExifTool zmodyfikuje wskazany plik. Przy pierwszej zmianie zachowa oryginał jako plik z końcówką _original.':
        'ExifTool will modify the selected file. On the first change, it will keep the original as a file ending in _original.',
    'Uwaga: pakiety i ramki mogą tworzyć bardzo duże wyniki.':
        'Warning: packets and frames can produce very large results.',
    'ExifTool ·': 'ExifTool ·',
    'FFprobe ·': 'FFprobe ·',
    'Ścieżka do katalogu skryptów': 'Scripts directory path',
    'Domyślnie: katalog skrypty obok uruchomionego programu.':
        'Default: the skrypty directory next to the running application.',
    'Katalog wybrany przez użytkownika.': 'Directory selected by the user.',
    'Zastosuj katalog': 'Apply directory',
    'Wskazany katalog skryptów nie istnieje.':
        'The specified scripts directory does not exist.',
    'Zapisano katalog skryptów.': 'Scripts directory saved.',
    'Przywrócono domyślny katalog skryptów obok programu.':
        'The default scripts directory next to the application was restored.',
    'Nie można zapisać katalogu skryptów:': 'Unable to save scripts directory:',
    'Windows: zainstaluj FFmpeg i dodaj katalog bin do PATH albo wskaż pliki ffmpeg.exe i ffprobe.exe ręcznie.\n\nLinux: dostępność NVENC, VAAPI, Vulkan i innych metod zależy od kompilacji FFmpeg oraz sterowników.':
        'Windows: install FFmpeg and add its bin directory to PATH, or select ffmpeg.exe and ffprobe.exe manually.\n\nLinux: availability of NVENC, VAAPI, Vulkan, and other methods depends on the FFmpeg build and drivers.',
    'zmieniono ręcznie': 'changed manually',
  };

  static const delegate = _AppLocalizationsDelegate();
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String tr(String source) => l10n.translate(source);
}
