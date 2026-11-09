# GitHub-publicatiehandleiding — v1.2.0-beta6

Deze ZIP is een volledige **broncode-update** voor EasyComp Keyboard Light. Je kunt hem via de GitHub-website uploaden; GitHub CLI, Terminal-login en Xcode op de publicerende computer zijn niet nodig.

## Wat uploaden?

Pak de ZIP eerst uit. Upload daarna de **inhoud** van de map `EasyComp-Keyboard-Light-v1.2.0-beta6`, niet de map als extra niveau en niet uitsluitend het ZIP-bestand.

De update bevat onder meer:

- `README.md`, `LEESMIJ.md`, `START-HERE.md`, `BETA-RELEASE.md` en `GITHUB-RELEASE.md` (de laatste bevat tekst voor de GitHub-release)
- `Assets/` inclusief de iconen, je GIF en de video `EasyComp Keyboardlight install and demo.mp4`
- `broncode/`, inclusief Swift, C, de wizard en de **acht app- en wizard-vertalingen**
- `Languages/`, met acht taalmappen met README's en aanklikbare commando's
- `scripts/`, de gedeelde installatiehulpmiddelen
- `.github/ISSUE_TEMPLATE/` en `.github/workflows/` (verborgen map, moet óók mee)
- `.gitignore`, `LICENSE`, `CONTRIBUTING.md` en de volledige `.command`-bestanden

**Let op:** de eerdere `Assets/IMG_0919.gif` bestaat al in de repository. De video is toegevoegd aan deze bijgewerkte ZIP; je kunt die ook zelf apart uploaden onder precies dezelfde naam.

## Via de GitHub-website

1. Ga naar https://github.com/EasyCompZLD/EasyComp-Keyboard-Light---For-headless-Apple-MacBook-Pro-s-with-T2-Chip
2. Kies de `main`-branch, **Add file → Upload files**.
3. Upload alle gewijzigde en nieuwe bestanden **met de juiste mappenstructuur**. Vervang bestaande bestanden door de versies uit deze ZIP.
4. Voor GitHub geldt een limiet van 100 bestanden per uploadactie en 25 MiB per bestand. Dit pakket bevat meer dan 100 bestanden: **verdeel de upload over minimaal twee acties/commits**, bijvoorbeeld eerst de rootbestanden, Assets, broncode, scripts en `.github`, daarna de volledige map `Languages/`. Controleer na afloop of de submappen intact zijn.
5. Gebruik bijvoorbeeld `Prepare v1.2.0-beta6 multilingual installer and diagnostics` als commitbericht.
6. Controleer de README en de videolink op GitHub voordat je een release aanmaakt.

Tip: in Finder toont `Command + Shift + .` verborgen bestanden zoals `.github` en `.gitignore`.

## Bèta-release publiceren

1. Open **Releases → Draft a new release**.
2. Kies de tag `v1.2.0-beta6`, vanaf de geüploade `main`-branch.
3. Titel: `EasyComp Keyboard Light v1.2.0-beta6`.
4. Gebruik de inhoud van `GITHUB-RELEASE.md` als Release Description. Controleer de videolink in de release: relatieve paden naar `Assets` werken niet altijd vanuit een releasebeschrijving, dus gebruik daar liever de volledige repositorylink.
5. Voeg de ZIP toe als downloadbestand (de geïnstalleerde app is **niet** als kant-en-klare `.app` bijgevoegd).
6. Vink **Set as a pre-release** aan. Laat v1.1.0 de stabiele release totdat de nieuwe hardwarefuncties uitgebreid getest zijn.

**Belangrijk:** GitHub-websiteuploads slaan `.command`-bestanden mogelijk zonder uitvoerbaarheidsattribuut (`chmod +x`) op. Bied daarom het meegeleverde **release-ZIP** aan als primaire download; daarin zijn de uitvoerbare bestandsrechten behouden. Wie de automatisch gegenereerde GitHub Source code ZIP downloadt, kan desnoods de scripts via `bash Install.command` starten.

## Video in de README

De README bevat een klikbare GIF-preview die verwijst naar `Assets/EasyComp Keyboardlight install and demo.mp4`. Op GitHub kan een direct geüploade repo-MP4 als bestand worden bekeken of gedownload. Voor een inline speler is meestal een GitHub-hosted video-attachment nodig; een gewone Markdown-link claimt geen inline afspelen.

## Privacy

Controleer of de video geen persoonlijke gegevens, serienummers of andere gevoelige informatie toont. Publiceer geen diagnostische rapporten zonder die zelf na te kijken.
