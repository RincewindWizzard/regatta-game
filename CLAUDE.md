# Hinweise für Claude

- Das Projekt wird mit **Godot 4.7.2** entwickelt und getestet (nicht mehr 4.3). Download:
  `https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip`
  (Export-Vorlagen: `..._export_templates.tpz` im selben Release).
- Tests laufen headless, siehe `docs/skripte/werkzeuge.md`; `tests/level_check.gd` muss „ALLE OK“ melden.
- Branches beginnen mit `claude/`. Dokumentation: `mkdocs build --strict` muss sauber durchlaufen.
