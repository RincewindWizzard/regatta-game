# Dokumentation bauen

Diese Dokumentation ist mit **[MkDocs](https://www.mkdocs.org)** und dem Theme **readthedocs**
geschrieben. Die Quelltexte sind Markdown-Dateien in `docs/`, die Konfiguration steht in
`mkdocs.yml`.

## Lokal ansehen

```bash
pip install -r requirements-docs.txt
mkdocs serve                 # http://127.0.0.1:8000, baut bei jeder Änderung neu
mkdocs build --strict        # statische Seite nach site/, Warnungen sind Fehler
```

`--strict` ist wichtig: Es lässt den Build fehlschlagen, wenn ein Querverweis ins Leere geht
(`[Text](datei.md)`) oder eine Seite nicht in der Navigation steht.

## Aufbau der Dateien

```
mkdocs.yml                  Navigation, Theme, Markdown-Erweiterungen
requirements-docs.txt       Python-Pakete (mkdocs, pymdown-extensions)
.github/workflows/docs.yml  GitHub Action: bauen und auf GitHub Pages veröffentlichen
docs/
├── index.md                Startseite
├── spielen/                Spielanleitung, Bahnen, Gefahren, Mehrspieler
├── nachbauen/              Fahrplan, Godot-Grundlagen, Architektur, Projekt
├── skripte/                jedes Skript im Detail
├── referenz/               Bahnen bauen, Konstanten, Glossar, diese Seite
└── bilder/                 Screenshots
```

## Veröffentlichen auf GitHub Pages

Das übernimmt die Action `.github/workflows/docs.yml`:

1. **Einmalig** im Repository unter *Settings → Pages* bei **Source** den Eintrag
   **GitHub Actions** wählen.
2. Bei jedem Push auf `main`, `master` oder einen Zweig `claude/*`, der `docs/`, `mkdocs.yml`
   oder die Workflow-Datei ändert, baut die Action die Seite mit `mkdocs build --strict`.
3. **Veröffentlicht** wird nur vom Hauptzweig (`main`/`master`). Auf `claude/*`-Zweigen und bei
   Pull Requests wird nur **gebaut** (Prüfung). Die Umgebung `github-pages` erlaubt ein
   Veröffentlichen von anderen Zweigen ohnehin standardmäßig nicht.
4. Die Adresse steht anschließend im Lauf der Action
   (`https://<Benutzer>.github.io/<Repository>/`).

## Schreiben: Hinweise

* **Querverweise** immer relativ und mit `.md`: `[Das Boot](../skripte/boot.md)`. Mit Anker auf
  eine Überschrift: `…boot.md#segelphysik-schritt-fur-schritt`.
* **Eigene Anker** für Überschriften mit Sonderzeichen: `## boat.gd { #boat-gd }`.
* **Hinweiskästen:** `!!! note "Titel"`, `!!! tip`, `!!! warning` mit eingerücktem Text.
* **Code:** Zäune mit Sprache: ` ```gdscript `, ` ```ini `, ` ```bash `.
* **Bilder** liegen in `docs/bilder/` und werden relativ eingebunden: `![Text](../bilder/x.png)`.
* Screenshots entstehen mit den Skripten aus [Werkzeuge und Tests](../skripte/werkzeuge.md).
