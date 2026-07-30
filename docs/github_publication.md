# Publishing the project on GitHub

## Before creating the repository

1. Choose a repository name and whether it will be public or private.
2. The MIT license is already in the root `LICENSE` file; do not add a second
   license through the repository creation form.
3. Confirm that `git status` contains no local media, `options.json`, SQLite
   databases, secrets, `skrypty/`, or files from `export`.
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

### Final single-commit publication

After committing all intended changes, build the available platforms with the
project build scripts. Each build writes an ignored version marker to
`build/release-manifests/`, outside the final `export/` directory. Then run:

```bash
./tools/publish-final-main-release.sh
```

The script stops before changing GitHub when the worktree is not clean, the
current branch or GitHub's default branch is not `main`, SSOT and package
versions differ, or an available build does not match the current version. It
also requires exactly one local commit beyond `origin/main`; two or more local
commits must be combined manually first. This also supports the independent
single root commit created by the older squash helper. It then rewrites the
remote state plus that one local commit to one commit named `main` and
force-with-lease pushes it to `origin/main`. It then creates or updates release
`v<version>` and uploads the current AppImage and/or a ZIP of the complete
Windows bundle. A missing Linux or Windows build does not block a release for
the other platform; the final message identifies what was sent.

This intentionally rewrites the public Git history. Do not run it while another
person is contributing commits to the repository.

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

### Końcowa publikacja z jednym commitem

Po wykonaniu commita wszystkich planowanych zmian zbuduj dostępne platformy
skryptami projektu. Każdy build zapisuje ignorowany znacznik wersji w
`build/release-manifests/`, poza końcowym katalogiem `export/`. Następnie
uruchom:

```bash
./tools/publish-final-main-release.sh
```

Skrypt przerywa przed zmianą GitHuba, gdy repozytorium ma niezacommitowane
zmiany, bieżąca gałąź albo domyślna gałąź GitHuba nie nazywa się `main`, wersje
SSOT i pakietu są różne albo dostępny build nie odpowiada bieżącej wersji.
Celowo zastępuje aktualną historię zdalnego `main` lokalnym, zakomitowanym
stanem projektu. Wymaga przy tym dokładnie jednego lokalnego commita
poza `origin/main`; dwa lub więcej commitów należy najpierw połączyć ręcznie.
Obsługuje również niezależny pojedynczy commit root, tworzony przez starszy
skrypt squashujący. Następnie łączy stan zdalny oraz ten jeden lokalny commit do
jednego commita o nazwie `main` i wysyła go do `origin/main` przez
`--force-with-lease`. Następnie tworzy lub aktualizuje release `v<wersja>` i
wysyła aktualny AppImage oraz/lub ZIP kompletnego bundla Windows. Brak buildu
Linux albo Windows nie blokuje publikacji drugiej platformy; końcowy komunikat
podaje, co zostało wysłane.

Ta operacja celowo przepisuje publiczną historię Git. Nie uruchamiaj jej, gdy
inna osoba dodaje commity do tego repozytorium.
