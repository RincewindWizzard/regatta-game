# Design

## Context

`release.yml` exportiert mit Godot 4.7.2 und den Presets in `export_presets.cfg` drei Plattformen,
legt ein Release an und stößt `docs.yml` an; der wird nur per Hand (`workflow_dispatch`) oder durch
einen `v*`-Tag gestartet. `docs.yml` baut MkDocs strikt, lädt die Dateien des neuesten Releases nach
`site/downloads` und deployt Pages nur von `main`. Die Seite `docs/spielen/download.md` ist statisch
und enthält Links auf `../../downloads/Regatta-*.zip`.

## Goals / Non-Goals

**Goals:**
- Jeder relevante Push auf `main` ergibt ohne Handarbeit Linux- und Windows-Builds und eine
  aktuelle Download-Seite.
- Stabile Download-Namen, nachvollziehbare Version, Prüfsummen.

**Non-Goals:**
- Kein Code-Signing/Notarisierung, keine Installer (MSI/Deb/DMG), keine Auto-Updates.
- Keine Web-/Mobile-Exporte.

## Decisions

1. **Auslöser:** `push` auf `main` (jeder Push, ohne Pfadfilter), `push` von Tags `v*` und
   `workflow_dispatch`. Alternative: Pfadfilter nur für Spieldateien – verworfen, weil jeder Push
   einen Snapshot erzeugen soll.
2. **Snapshot-Release:** Tag `snapshot-<Datum>-<Commit7>`, als Vorabversion markiert. Nach der
   Veröffentlichung löscht ein Schritt alle anderen Releases, deren Tag mit `snapshot-` beginnt
   (samt Tag). Dadurch ist immer nur der neueste Snapshot vorhanden; getaggte Releases (`v*`)
   werden nie angefasst. Feste Releases entstehen bei `v*`-Tags (nicht als Vorabversion).
   Alternative: ein einziges Rolling-Release mit überschriebenen Dateien – verworfen, weil
   eindeutige Snapshot-Tags die Version nachvollziehbar machen.
3. **Dateien:** `Regatta-windows.zip`, `Regatta-linux.zip`, `Regatta-macos.zip` (stabile Namen), `SHA256SUMS.txt`,
   `VERSION.txt` (Commit, Datum, Godot-Version, Lauf-Nr.). Die Version steht zusätzlich in der
   Release-Beschreibung.
4. **Test vor dem Export:** Level-Check (wie heute) plus ein schneller Headless-Spieltest
   (`hazard_test` mit einem Szenario), damit kein offensichtlich kaputtes Spiel veröffentlicht wird.
5. **Doku-Seite wird erzeugt:** Ein kleines Skript (`tools/make_download_page.py`) schreibt aus
   `VERSION.txt` und `SHA256SUMS.txt` den Abschnitt „Aktuelle Version“ (Datum, Commit, Größe,
   Prüfsumme) in `docs/spielen/download.md` (zwischen Markierungen) bzw. liefert ihn als Include. Die
   Anleitung selbst bleibt handgeschriebener Text in `download.md`. Ohne Release zeigt das Skript
   „noch kein Download“. Alternative: Seite komplett generieren – verworfen, weil die Anleitung
   redaktionell gepflegt wird.
6. **Reihenfolge:** `release.yml` baut/veröffentlicht, dann ruft der Job `docs` den Workflow
   `docs.yml` auf `main` auf (wie bisher per `gh workflow run`); `docs.yml` holt den neuesten
   Snapshot und das neueste feste Release nach `site/downloads/snapshot` und
   `site/downloads/stabil`, erzeugt die Versionsabschnitte und baut strikt. Pages-Größe: drei Zips je
   Bereich (etwa 340 MB bei beiden Bereichen) liegt unter dem Limit; sollte es eng werden, verweist
   der stabile Bereich nur noch auf das Release.
7. **Concurrency:** `concurrency: group: build` mit `cancel-in-progress` für Branch-Pushes, damit
   nur der neueste Stand gebaut wird.
8. **Installationsanleitung** auf `download.md`: je Windows, Linux und macOS Schritt für Schritt,
   Voraussetzungen (Vulkan-fähige Grafik; Hinweis auf `--rendering-method gl_compatibility`),
   SmartScreen („Weitere Informationen → Trotzdem ausführen“), `chmod +x`, macOS `xattr -cr` und
   `codesign --force --deep --sign -` (ungesignierte App), Controller (Joy-Con per
   Bluetooth), Netzwerkspiel (UDP-Port aus der Spielanleitung, Firewall-Freigabe), Prüfsumme
   (`certutil`/`sha256sum`), Fehlerbehebung, Deinstallation (Ordner löschen, Einstellungsordner
   `user://` nennen).

## Risks / Trade-offs

- Snapshots werden bei jedem Push ersetzt → Versionsangabe und Prüfsummen auf der Seite geben
  Nachvollziehbarkeit; feste Releases über Tags für Stabilität.
- Das Löschen alter Snapshots ist unwiderruflich → es betrifft nur Tags mit Präfix `snapshot-`.
- macOS-Builds sind unsigniert (Quarantäne, Apple-Silicon verlangt lokale Signatur) → in der
  Anleitung beschrieben; ein Push kostet drei Exporte (Cache).
- Workflow-Berechtigungen (Schreibrechte, Pages) lassen sich nur im Repository einstellen → in der
  Doku und im Workflow-Kopf beschrieben; ohne sie schlägt der Lauf mit klarer Meldung fehl.
- Build-Zeit (Godot- und Vorlagen-Download ~1,3 GB) → Cache wie bisher.
- Ein defekter Build blockiert den Doku-Neubau nicht (Doku läuft eigenständig weiter).
