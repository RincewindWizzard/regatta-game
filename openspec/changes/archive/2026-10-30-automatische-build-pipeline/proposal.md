# Proposal

## Why

Die vorhandene Pipeline erzeugt Builds nur auf Handarbeit (Workflow starten oder Tag setzen).
Wer das Spiel ausprobieren will, bekommt dadurch nicht automatisch den aktuellen Stand, und die
Doku verweist auf Dateien, die veraltet oder gar nicht vorhanden sein können. Es fehlt außerdem eine
vollständige Installationsanleitung.

## What Changes

- Neue, **automatische** Build-Pipeline: **Jeder Push auf `main`** erzeugt eine **Snapshot-Version**
  mit Builds für **Linux, Windows und macOS**. Vor dem Export laufen Level-Check und ein
  Headless-Spieltest.
- Snapshots werden als Vorabversion veröffentlicht (Tag `snapshot-<Datum>-<Commit>`), mit stabilen
  Dateinamen, Versionsangabe (Commit, Datum) und Prüfsummen. Es wird **immer nur der neueste
  Snapshot** vorgehalten, ältere Snapshots werden gelöscht.
- **Versions-Tags (`v*`) erzeugen weiterhin ein festes Release** (alle drei Plattformen); alle
  getaggten Releases bleiben dauerhaft erhalten.
- Die **Doku-Seite „Download“** wird bei jedem Build automatisch neu erzeugt: Sie bietet die
  Binaries zum Herunterladen an (Spiegel auf GitHub Pages und Link zum Release), getrennt nach
  **Stabil** (neuester Versions-Tag) und **Snapshot** (neuester Stand von `main`), mit Version,
  Datum, Größe und Prüfsumme.
- Neue **Installationsanleitung** auf der Download-Seite für Windows, Linux und macOS:
  Voraussetzungen (Grafik/Vulkan), Entpacken, Starten, SmartScreen-Hinweis, Ausführrecht unter
  Linux, Quarantäne und Signatur unter macOS, Controller, Netzwerkspiel (Firewall/Port),
  Fehlerbehebung, Deinstallation, Prüfsumme prüfen.

## Capabilities

### New Capabilities

(keine)

### Modified Capabilities
- `build`: Jeder Push auf `main` erzeugt automatisch einen Snapshot für Linux, Windows und macOS
  (nur der neueste bleibt erhalten); Versions-Tags erzeugen feste Releases.
- `doku`: Die Download-Seite wird automatisch mit Stabil- und Snapshot-Binaries erzeugt und enthält
  eine vollständige Installationsanleitung.

## Impact

- `.github/workflows/release.yml` (Auslöser, Plattformen, Snapshot-Release mit Bereinigung),
  `.github/workflows/docs.yml` (Download-Seite und Dateien aus den Releases), kleines Skript zum
  Erzeugen des Versionsabschnitts.
- `docs/spielen/download.md` (Installationsanleitung, Versionsabschnitte), `docs/skripte/werkzeuge.md`,
  `README.md`.
- Einmalige Repository-Einstellung: Actions-Schreibrechte und Pages-Quelle „GitHub Actions“.
- Keine Spielcode-Änderung; Build nutzt die vorhandenen `export_presets.cfg`.
