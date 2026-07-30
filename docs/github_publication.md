# Publishing the project on GitHub

## Before creating the repository

1. Choose a repository name and whether it will be public or private.
2. The MIT license is already in the root `LICENSE` file; do not add a second
   license through the repository creation form.
3. Confirm that `git status` contains no local media, `options.json`, SQLite
   databases, secrets, `docs/changelog.md`, `skrypty/`, or files from `export`.
4. Run:

   ```bash
   dart format --output=none --set-exit-if-changed lib test tool
   flutter analyze
   flutter test
   flutter build linux --release
   ```

## Create the repository

Create an empty GitHub repository. Do not create a separate README, `.gitignore`,
or license in the GitHub form because those files are already prepared locally.

Then add the GitHub address:

```bash
git remote add origin REPOSITORY_ADDRESS
git push -u origin main
```

Replace `REPOSITORY_ADDRESS` with the actual HTTPS or SSH address. Never commit
an access token.

## After the first push

- Enable private vulnerability reporting in repository security settings.
- Check the first **Linux CI** workflow run.
- Protect `main` and require CI before merging pull requests.
- Enable Dependabot alerts and security updates.
- Add repository topics such as `flutter`, `ffmpeg`, `ffprobe`, `linux`, and
  `desktop`.

## Publish the application

`export/` contains generated artifacts and is not committed. Attach the final
AppImage to a GitHub Release for the application version. Source code belongs in
the repository; generated packages belong in Releases.

---

## Wersja polska

## Przed utworzeniem repozytorium

1. Wybierz nazwę repozytorium i zdecyduj, czy ma być publiczne, czy prywatne.
2. Licencja MIT znajduje się w głównym pliku `LICENSE`; nie dodawaj drugiej
   licencji przez formularz tworzenia repozytorium.
3. Sprawdź `git status` i upewnij się, że nie ma lokalnych multimediów,
   `options.json`, baz SQLite, sekretów ani plików z katalogu `export`.
4. Uruchom:

   ```bash
   dart format --output=none --set-exit-if-changed lib test tool
   flutter analyze
   flutter test
   flutter build linux --release
   ```

## Utworzenie repozytorium

Utwórz na GitHubie puste repozytorium. Nie dodawaj przez formularz osobnego
README, `.gitignore` ani licencji, jeżeli odpowiednie pliki zostały już
przygotowane lokalnie.

Następnie ustaw adres otrzymany z GitHuba:

```bash
git remote add origin ADRES_REPOZYTORIUM
git push -u origin main
```

Przed wykonaniem tych poleceń trzeba zastąpić `ADRES_REPOZYTORIUM` prawdziwym
adresem HTTPS albo SSH. Nie należy commitować tokenu dostępu.

## Ustawienia po pierwszym pushu

- Włącz prywatne zgłaszanie podatności w ustawieniach bezpieczeństwa.
- Sprawdź pierwszy przebieg workflow **Linux CI**.
- Zabezpiecz gałąź `main`, wymagając przejścia CI przed scaleniem pull requestu.
- Włącz Dependabot alerts oraz aktualizacje zabezpieczeń zależności.
- Uzupełnij opis repozytorium i tematy, na przykład `flutter`, `ffmpeg`,
  `ffprobe`, `linux` i `desktop`.

## Publikowanie programu

Plik z katalogu `export` jest artefaktem, dlatego nie trafia do historii Git.
Gotowy AppImage należy dołączyć do osobnego GitHub Release odpowiadającego
wersji aplikacji. Kod źródłowy pozostaje w repozytorium, a wygenerowane paczki
w sekcji Releases.
