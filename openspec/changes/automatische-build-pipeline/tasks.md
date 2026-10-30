# Tasks

## 1. Workflow

- [ ] 1.1 `release.yml`: Auslöser (Push auf `main` mit Pfadfilter, Tags `v*`, manuell mit Option macOS), Plattformen Linux und Windows, `concurrency`
- [ ] 1.2 Test vor dem Export: Level-Check plus ein Headless-Spieltest; bei Fehler kein Release
- [ ] 1.3 Dateien erzeugen: `Regatta-windows.zip`, `Regatta-linux.zip`, `SHA256SUMS.txt`, `VERSION.txt` (Commit, Datum, Godot-Version, Lauf-Nr.)
- [ ] 1.4 Rolling Release „Aktueller Stand“ (Tag `latest-build`, Vorabversion) aktualisieren; Tags `v*` erzeugen feste Releases
- [ ] 1.5 Doku-Neubau nach erfolgreichem Build anstoßen (`docs.yml` auf `main`)

## 2. Doku

- [ ] 2.1 `docs.yml`: Release „Aktueller Stand“ (sonst neuestes festes) nach `site/downloads` laden, Versionsabschnitt erzeugen, strikt bauen
- [ ] 2.2 `tools/make_download_page.py`: Abschnitt „Aktuelle Version“ (Datum, Commit, Größe, Prüfsumme, Links) aus `VERSION.txt`/`SHA256SUMS.txt`; Hinweis bei fehlendem Release
- [ ] 2.3 `docs/spielen/download.md`: Installationsanleitung für Windows und Linux (Voraussetzungen, Entpacken, Starten, SmartScreen, `chmod +x`, Controller, Netzwerk/Firewall, Prüfsumme, Fehlerbehebung, Deinstallation)
- [ ] 2.4 `docs/skripte/werkzeuge.md` (Build und Release neu beschreiben) und `README.md` (Installation)

## 3. Prüfung

- [ ] 3.1 Workflows lokal prüfen: YAML gültig, Exportschritte lokal mit Godot 4.7.2 und Vorlagen für Linux und Windows, Prüfsummen und Skript `make_download_page.py` mit Beispieldateien
- [ ] 3.2 `mkdocs build --strict`, `openspec validate automatische-build-pipeline`
- [ ] 3.3 Hinweis an den Nutzer: einmalig Actions-Schreibrechte und Pages-Quelle „GitHub Actions“ einstellen; erster Lauf durch Push
