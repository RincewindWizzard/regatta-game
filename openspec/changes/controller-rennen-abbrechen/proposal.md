## Why

Ein Rennen ließ sich nur mit der Tastatur (`Esc`) abbrechen. Wer ausschließlich mit dem
Controller spielt (auch einzelner Joy-Con), musste zur Tastatur greifen.

## What Changes

- Im Rennen bricht ein Controller das Rennen ab, wenn die Zurück-Taste (Select/Minus)
  1 Sekunde gehalten wird; danach geht es ins Menü (Host: Lobby, Mitspieler: verlässt die Runde).
- Die HUD zeigt bei verbundenem Controller den Hinweis „Zurück-Taste halten: Rennen abbrechen“
  und beim Halten einen Fortschrittsbalken.
- Das Rennen im Menü zu starten ging mit dem Controller bereits (Start-Taste bzw. A); das ist
  jetzt in Anleitung und README dokumentiert.

## Impact

- Betroffener Code: `scripts/main.gd` (`_process`, `abort_progress`), `scripts/hud.gd`
  (`_draw_abort_hint`)
- Dokumentation: `docs/spielen/anleitung.md`, `README.md`
