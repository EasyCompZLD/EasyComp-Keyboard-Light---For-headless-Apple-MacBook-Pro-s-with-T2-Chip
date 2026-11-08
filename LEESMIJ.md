# EasyComp Keyboard Light - voor headless Apple MacBook Pro's met T2-chip

**Geen scherm. Geen omgevingslichtsensor. Toch toetsenbordverlichting.** 💡

Bij de geteste MacBook Pro 16-inch uit 2019 (A2141 / MacBookPro16,1) verdwijnen de gewone toetsenbordverlichtingsknoppen uit macOS zodra het scherm en daarmee de lichtsensor is verwijderd. Apple lijkt je daarmee figuurlijk een **middelvinger** te geven: zonder sensor geen licht. Alleen: **de leds hebben die sensor helemaal niet nodig om aan te kunnen gaan.**

EasyComp Keyboard Light bewijst dat op het geteste apparaat door de toetsenbordverlichting rechtstreeks via de **USB-HID-interface van de T2** aan te sturen. Aan, uit en helderheid werken zonder scherm of lichtsensor. Dat is een waarneming over macOS en de hardware; geen bewijs dat Apple dit bewust blokkeert.

## Functies

- Native macOS-menubalkapp met aan/uit en helderheidsregeling
- Eigen appicoon, automatische start na inloggen, laatst gekozen helderheid onthouden
- Acht talen: Nederlands, Engels, Duits, Frans, Spaans, Italiaans, Portugees en Pools
- Automatische of handmatige taalkeuze
- Optionele herkenning van originele Touch Bar-verlichtingstoetsen als macOS de events nog verstuurt
- Geen externe verbinding, telemetrie, sudo, kernel-extensie, SIP- of FileVault-aanpassingen

## Ondersteuning

De HID-methode is werkend getest op de **MacBookPro16,1 / A2141 met Intel T2 en macOS Tahoe 26**. Andere modellen zijn niet getest en worden bewust door het installatieprogramma geweigerd. De bijgewerkte versie 1.1.0 moet na compilatie nog op het eigen apparaat worden nagekeken.

## Installeren

Pak de ZIP uit, open Terminal in de projectmap en voer uit:

```bash
bash Controleer-build.command
bash Installeer.command
```

De app wordt uit broncode opgebouwd en in `~/Applications` gezet. Apple Command Line Tools zijn vereist. Dit is geen door Apple genotariseerde distributie.

**Instellingen zitten in het menubalkmenu**, er is geen apart instellingenvenster. Het programma werkt pas na het inloggen en dus niet op het FileVault-ontgrendelscherm.

Meer details in [README.md](README.md). Publiceren via GitHub.com: [GITHUB-HANDLEIDING.md](GITHUB-HANDLEIDING.md).

**EasyComp Zeeland** · MIT License · Onafhankelijk van Apple.
