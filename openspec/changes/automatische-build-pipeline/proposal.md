# Proposal

## Why

Die vorhandene Pipeline erzeugt Builds nur auf Handarbeit (Workflow starten oder Tag setzen).
Wer das Spiel ausprobieren will, bekommt dadurch nicht automatisch den aktuellen Stand, und die
Doku verweist auf Dateien, die veraltet oder gar nicht vorhanden sein können. Es fehlt außerdem eine
vollständige Installationsanleitung.

## What Changes

- Neue, **automatische** Build-Pipeline: Bei jedem Push auf `main`, der Spielinhalt ändert (Skripte,
  Level, Modelle, Klänge, Szenen, Projekt- und Export-Einstellungen), werden Builds für **Linux** und
  **Windows** erzeugt, getestet (Level-Check) und veröffentlicht.
- Veröffentlicht wird in ein fortlaufend aktualisiertes Release „Aktueller Stand“ (Vorabversion,
  fester Tag), mit stabilen Dateinamen, Versionsangabe (Commit, Datum) und Prüfsummen.
  Versions-Tags (`v*`) erzeugen weiterhin ein festes Release.
- Die **Doku-Seite „Download“** wird bei jedem Build automatisch neu erzeugt: Sie bietet die
  Binaries direkt zum Herunterladen an (Spiegel auf GitHub Pages und Link zum Release) und zeigt
  Version, Build-Datum und Prüfsummen.
- Neue **Installationsanleitung** auf der Download-Seite für Windows und Linux: Voraussetzungen
  (Grafik/Vulkan), Entpacken, Starten, SmartScreen-Hinweis, Ausführrecht unter Linux, Controller,
  Netzwerkspiel (Firewall/Port), Fehlerbehebung, Deinstallation, Prüfsumme prüfen.
- macOS wird nicht mehr bei jedem Push gebaut, bleibt aber manuell wählbar (Option beim Start).

## Capabilities

### New Capabilities

(keine)

### Modified Capabilities
- `build`: Builds für Linux und Windows entstehen automatisch bei Änderungen auf `main`, werden als
  Release veröffentlicht und mit Version und Prüfsummen versehen.
- `doku`: Die Download-Seite wird automatisch mit den aktuellen Binaries erzeugt und enthält eine
  vollständige Installationsanleitung.

## Impact

- `.github/workflows/release.yml` (Auslöser, Plattformen, Rolling-Release), `.github/workflows/docs.yml`
  (Download-Seite und Dateien aus dem Release), ggf. kleines Skript zum Erzeugen der Download-Seite.
- `docs/spielen/download.md` (Installationsanleitung, Versionsangabe), `docs/skripte/werkzeuge.md`,
  `README.md`.
- Einmalige Repository-Einstellung: Actions-Schreibrechte und Pages-Quelle „GitHub Actions“.
- Keine Spielcode-Änderung; Build nutzt die vorhandenen `export_presets.cfg`.
