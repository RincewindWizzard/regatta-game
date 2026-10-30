# Projekt: Regatta

Segel-Rennspiel auf der Seekarte (Godot 4.7.2, GDScript) für bis zu vier Skipper an einem Bildschirm,
im LAN oder übers Internet. Dokumentation: `docs/` (MkDocs). Tests laufen headless (`tests/`).

## Konventionen

- Sprache: Deutsch (Doku, Meldungen, Spezifikationen).
- Arbeit direkt auf `main`; jede Anforderung als OpenSpec-Change unter `openspec/changes/`, nach der
  Umsetzung archivieren (`openspec/changes/archive/<Datum>-<name>/`, Spec-Deltas in `openspec/specs/`).
- `tests/level_check.gd` muss „ALLE OK“ melden, `mkdocs build --strict` muss sauber laufen.

## Hinweis zur Historie

Die ersten 24 Changes wurden nachträglich aus der Entwicklungsgeschichte formuliert und von Hand
archiviert (der OpenSpec-CLI war in der Entwicklungsumgebung nicht installierbar). Neue Changes
bitte mit dem CLI (`openspec archive <name>`) archivieren.
