@echo off
setlocal EnableExtensions

set "MSG=%*"
if "%MSG%"=="" set "MSG=checkpoint"

git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (
  echo To nie jest repozytorium git.
  exit /b 1
)

git status --porcelain | findstr /r "." >nul
if not errorlevel 1 (
  echo Masz niezacommitowane zmiany. Zrob commit albo stash przed squashem.
  exit /b 1
)

for /f %%A in ('"git rev-list --count HEAD"') do set "COUNT=%%A"
if not defined COUNT (
  echo Nie udalo sie odczytac liczby commitow.
  exit /b 1
)

if %COUNT% LEQ 1 (
  echo Repo ma tylko jeden commit - nic do squasha.
  git --no-pager log --oneline -n 3
  exit /b 0
)

for /f %%A in ('"git rev-list --max-parents=0 HEAD"') do set "ROOT=%%A"
if not defined ROOT (
  echo Nie udalo sie odczytac root commita.
  exit /b 1
)

git reset --soft "%ROOT%"
if errorlevel 1 exit /b 1

git commit --amend -m "%MSG%"
if errorlevel 1 exit /b 1

echo OK: cala historia splaszczona do 1 commita.
git --no-pager log --oneline -n 5

exit /b 0
