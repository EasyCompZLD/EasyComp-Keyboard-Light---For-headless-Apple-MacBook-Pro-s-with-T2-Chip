# EasyComp Keyboard Light — handmatig publiceren via GitHub.com

Je hoeft **niet ingelogd te zijn op GitHub in Terminal**. Dit doe je volledig via de website.

## Nieuwe openbare repository aanmaken

1. Open https://github.com/new in je browser en meld je aan.
2. Kies de gewenste **Owner** (je persoonlijke account of een organisatie die je beheert).
3. Repository name: **EasyComp-Keyboard-Light**.
4. Description: kopieer de tekst uit `GITHUB-INFO.md` (GitHub About).
5. Kies **Public**.
6. Laat **Add a README file**, **Add .gitignore** en **Choose a license** uit: die bestanden zitten al in dit project.
7. Klik **Create repository**.

## Projectbestanden via de browser uploaden

1. Pak `EasyComp-Keyboard-Light-v1.1.0.zip` uit op de Mac.
2. Open de zojuist aangemaakte repository op GitHub.
3. Kies **uploading an existing file** of **Add file → Upload files**.
4. Sleep **alle bestanden en mappen uit de uitgepakte projectmap** naar het uploadvak. Upload niet alleen het ZIP-bestand: GitHub pakt een ZIP in de repository niet automatisch uit.
5. De verborgen `.github`-map en `.gitignore` zijn belangrijk: druk in Finder zo nodig `Command + Shift + .` om ze zichtbaar te maken. Indien jouw browser de mappen niet goed verwerkt, kun je ze via **Add file → Create new file** met hun relatieve paden toevoegen of een browser gebruiken die het slepen van mappen ondersteunt.
6. Controleer of GitHub onder andere `README.md`, `LICENSE`, `Installeer.command`, `broncode/`, `Assets/` en `.github/workflows/build.yml` laat zien.
7. Controleer ook of `GITHUB-INFO.md`, `CONTRIBUTING.md` en `GITHUB-RELEASE.md` erbij staan. Commit message: `Initial public release v1.1.0`.
8. Klik **Commit changes**.

## Optioneel: echte release toevoegen

1. Open de repository → **Releases** → **Draft a new release**.
2. Tag: `v1.1.0` (maak de tag aan vanaf de hoofdbranch).
3. Titel: `EasyComp Keyboard Light v1.1.0`.
4. Gebruik de tekst uit `GITHUB-RELEASE.md` voor de beschrijving. Markeer de release als **Pre-release** zolang de bijgewerkte v1.1.0 niet op de Mac getest is.
5. Je kunt desgewenst het gehele broncode-ZIP toevoegen als release-asset (geen kant-en-klare, ondertekende `.app`). GitHub biedt ook zelf Source Code (zip) aan.
6. Kies **Publish release**.

## Controle

Na het committen kun je op GitHub onder **Actions** zien of de macOS-buildcontrole geslaagd is. Als de workflow wegens GitHub-repositoryinstellingen niet kan draaien, kan de eigenaar deze in de repositoryinstellingen activeren.

**Let op:** het project bouwt de app lokaal op de eigen Mac. Het is nog geen Apple-notarized installatiepakket of universeel geteste macOS-release.
