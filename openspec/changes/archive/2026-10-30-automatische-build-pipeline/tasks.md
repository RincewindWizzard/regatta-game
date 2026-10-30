# Tasks

## 1. Workflow

- [x] 1.1 `release.yml`: Auslöser (jeder Push auf `main`, Tags `v*`, manuell), Plattformen Linux, Windows und macOS, `concurrency`
- [x] 1.2 Test vor dem Export: Level-Check plus ein Headless-Spieltest; bei Fehler kein Release
- [x] 1.3 Dateien erzeugen: `Regatta-windows.zip`, `Regatta-linux.zip`, `Regatta-macos.zip`, `SHA256SUMS.txt`, `VERSION.txt` (Commit, Datum, Godot-Version, Lauf-Nr.)
- [x] 1.4 Snapshot-Release (Tag `snapshot-<Datum>-<Commit>`, Vorabversion) anlegen und danach alle älteren `snapshot-`-Releases samt Tags löschen; Tags `v*` erzeugen feste Releases und werden nie gelöscht
- [x] 1.5 Doku-Neubau nach erfolgreichem Build anstoßen (`docs.yml` auf `main`)

## 2. Doku

- [x] 2.1 `docs.yml`: neuesten Snapshot und neuestes festes Release nach `site/downloads/snapshot` bzw. `site/downloads/stabil` laden, Versionsabschnitte erzeugen, strikt bauen
- [x] 2.2 `tools/make_download_page.py`: Abschnitte „Stabil“ und „Snapshot“ (Version, Datum, Größe, Prüfsumme, Links für alle drei Plattformen) aus `VERSION.txt`/`SHA256SUMS.txt`; Hinweis bei fehlendem Release
- [x] 2.3 `docs/spielen/download.md`: Installationsanleitung für Windows, Linux und macOS (Voraussetzungen, Entpacken, Starten, SmartScreen, `chmod +x`, macOS-Quarantäne und Signatur, Controller, Netzwerk/Firewall, Prüfsumme, Fehlerbehebung, Deinstallation)
- [x] 2.4 `docs/skripte/werkzeuge.md` (Build und Release neu beschreiben) und `README.md` (Installation)

## 3. Prüfung

- [x] 3.1 Workflows lokal prüfen: YAML gültig, Exportschritte lokal mit Godot 4.7.2 und Vorlagen für Linux, Windows und macOS, Snapshot-Bereinigung als Trockenlauf, Prüfsummen und Skript `make_download_page.py` mit Beispieldateien
- [x] 3.2 `mkdocs build --strict`, `openspec validate automatische-build-pipeline`
- [x] 3.3 Hinweis an den Nutzer: einmalig Actions-Schreibrechte und Pages-Quelle „GitHub Actions“ einstellen; erster Lauf durch Push
