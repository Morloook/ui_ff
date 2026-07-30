import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/localized_text.dart';

const compatibleScriptExample = r'''#!/usr/bin/env bash
set -Eeuo pipefail

# Nazwy zmiennych używanych przez formularz zapisuj wielkimi literami.
OVERWRITE="-n"
VIDEO_CODEC="libx264"
AUDIO_CODEC="aac"
ENCODING_PRESET="medium"
CRF="20"
AUDIO_BITRATE="192k"

read -e -p "Wybierz plik wejściowy: " INPUT_FILE
read -e -p "Wybierz plik wynikowy: " OUTPUT_FILE

ffmpeg "$OVERWRITE" \
    -hide_banner \
    -i "$INPUT_FILE" \
    -c:v "$VIDEO_CODEC" \
    -preset "$ENCODING_PRESET" \
    -crf "$CRF" \
    -c:a "$AUDIO_CODEC" \
    -b:a "$AUDIO_BITRATE" \
    "$OUTPUT_FILE"
''';

Future<void> showScriptsHelpDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const ScriptsHelpDialog(),
  );
}

class ScriptsHelpDialog extends StatelessWidget {
  const ScriptsHelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      child: SizedBox(
        width: (size.width - 48).clamp(320.0, 940.0),
        height: (size.height - 48).clamp(420.0, 760.0),
        child: DefaultTabController(
          length: 4,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
                child: Row(
                  children: [
                    const Icon(Icons.help_outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pomoc — automatyczny importer skryptów',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: context.tr('Zamknij'),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              TabBar(
                tabs: [
                  Tab(text: context.tr('Działanie')),
                  Tab(text: context.tr('Rozpoznaje')),
                  Tab(text: context.tr('Ograniczenia')),
                  Tab(text: context.tr('Przykład')),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    _HowItWorksTab(),
                    _SupportedTab(),
                    _UnsupportedTab(),
                    _ExampleTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowItWorksTab extends StatelessWidget {
  const _HowItWorksTab();

  @override
  Widget build(BuildContext context) {
    return const _HelpList(
      intro:
          'Zakładka Skrypty zamienia obsługiwany fragment pliku .sh na '
          'tymczasowy formularz i bezpieczne argumenty FFmpeg.',
      items: [
        'Podczas startu program skanuje wyłącznie katalog skrypty obok '
            'uruchomionego pliku wykonywalnego.',
        'Przycisk „Odśwież skrypty” ponownie czyta pliki bez restartowania '
            'programu.',
        'Wybranie skryptu tworzy pola z jego zmiennych i pytań read.',
        'Opcje zapisane bezpośrednio w poleceniu FFmpeg również stają się '
            'polami. Przełączniki bez wartości, np. -hide_banner i -stats, '
            'można włączyć albo wyłączyć.',
        'Program automatycznie proponuje między innymi tytuły, ścieżki '
            'wynikowe, wariant kodowania audio i filtr Shorta.',
        'Każdą propozycję można zmienić. Przycisk przy polu przywraca wartość '
            'odczytaną ze skryptu albo wyliczoną automatycznie.',
        'Dopóki brakuje wymaganej wartości lub pliku, dodanie do kolejki jest '
            'zablokowane.',
        'Przed ostatecznym potwierdzeniem otwiera się osobny edytor wszystkich '
            'argumentów każdego etapu. Program wykonywalny pozostaje '
            'zablokowany na wykrytym FFmpeg.',
        'Kilka poleceń FFmpeg staje się jednym workflow z kolejnymi etapami.',
        'Formularze są wyłącznie sesyjne i nie są zapisywane w options.json.',
      ],
    );
  }
}

class _SupportedTab extends StatelessWidget {
  const _SupportedTab();

  @override
  Widget build(BuildContext context) {
    return const _HelpList(
      intro:
          'Najpewniejszy wynik dają proste skrypty, które przygotowują '
          'zmienne, pytają o dane, a następnie wywołują FFmpeg.',
      items: [
        'Pliki z rozszerzeniem .sh znajdujące się bezpośrednio w katalogu '
            'skrypty obok pliku wykonywalnego.',
        'Proste przypisania do zmiennych zapisanych wielkimi literami, np. '
            'CRF="20".',
        'Pytania read z opcją -p, w tym wariant read -e. Wartości zależne '
            'od wyrażeń Basha mogą wymagać automatycznego wyliczenia albo '
            'ręcznej korekty.',
        r'Zmienne $NAME, ${NAME} oraz tablice argumentów ${ARGS[@]}.',
        'Jedno albo kilka poleceń rozpoczynających się od ffmpeg.',
        r'Polecenia wielowierszowe zakończone znakiem \.',
        'Pliki wejściowe i wynikowe rozpoznawane po nazwach zmiennych, np. '
            'INPUT_FILE, AUDIO_FILE, IMAGE_FILE i OUTPUT_FILE.',
        'Edytowalne wartości kodeków, CRF, presetu, bitrate, ID3 oraz '
            'nadpisywania.',
        'Literalne opcje FFmpeg z wartością oraz przełączniki bez wartości, '
            'np. -hide_banner, -stats i -shortest.',
        'Własne nazwy zmiennych i ścieżki; brak wbudowanych prywatnych '
            'workflow w publicznej wersji programu.',
      ],
    );
  }
}

class _UnsupportedTab extends StatelessWidget {
  const _UnsupportedTab();

  @override
  Widget build(BuildContext context) {
    return const _HelpList(
      intro:
          'Importer nie jest interpreterem Basha. Nie uruchamia całego '
          'skryptu i nie gwarantuje obsługi dowolnego programu powłoki.',
      items: [
        'Nie uruchamia Basha, PowerShella ani cmd.exe.',
        'Nie wykonuje poleceń systemowych takich jak rm, mv, cp, sudo, curl, '
            'wget, Python albo eval.',
        'Nie wykonuje własnych programów i funkcji zdefiniowanych w skrypcie.',
        'Nie odtwarza dowolnych pętli, rekursji, potoków, przekierowań ani '
            'dynamicznie tworzonego kodu.',
        'Nie wykonuje dowolnych wywołań FFprobe lub ExifTool zapisanych w '
            'skrypcie. FFprobe jest używany przez aplikację tylko do '
            'kontrolowanego wykrywania danych wejściowych.',
        'Nie należy umieszczać alternatywnych poleceń FFmpeg w różnych '
            'gałęziach if/case. Zamiast tego przygotuj zmienną albo tablicę '
            'argumentów i użyj jednego polecenia FFmpeg.',
        'Nie wysyła do kolejki nierozwiązanych zmiennych ani symboli '
            'zastępczych.',
        'Nie zapisuje ścieżek, metadanych, jakości ani innych danych formularza.',
        'Skrypt częściowo rozpoznany wymaga sprawdzenia ostrzeżeń i ręcznego '
            'uzupełnienia brakujących pól.',
        'Nietypowa lub niejednoznaczna składnia argumentów może wymagać '
            'poprawienia w końcowym edytorze polecenia przed kolejką.',
      ],
    );
  }
}

class _ExampleTab extends StatelessWidget {
  const _ExampleTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ten plik zostanie wykryty bez dodatkowego manifestu. Wszystkie '
            'wartości użyte przez FFmpeg pojawią się w edytowalnym formularzu.',
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => Clipboard.setData(
                const ClipboardData(text: compatibleScriptExample),
              ),
              icon: const Icon(Icons.copy),
              label: const Text('Kopiuj przykład'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SingleChildScrollView(
                padding: EdgeInsets.all(14),
                child: SelectableText(
                  compatibleScriptExample,
                  style: TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpList extends StatelessWidget {
  const _HelpList({required this.intro, required this.items});

  final String intro;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(intro, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.circle, size: 7),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(item)),
              ],
            ),
          ),
      ],
    );
  }
}
