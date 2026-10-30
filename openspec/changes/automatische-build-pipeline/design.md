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
- Kein Code-Signing, keine Installer (MSI/Deb), keine Auto-Updates.
- Keine macOS-Builds im Normalfall; keine Web-/Mobile-Exporte.

## Decisions

1. **Auslöser:** `push` auf `main` mit `paths`-Filter (`scripts/**`, `scenes/**`, `levels/**`,
   `models/**`, `audio/**`, `addons/**`, `project.godot`, `export_presets.cfg`, der Workflow selbst),
   `push` von Tags `v*` und `workflow_dispatch` (Option „mit macOS“). Doku-/Teständerungen lösen
   keinen Build aus, bauen aber die Doku weiter über `docs.yml`. Alternative: bei jedem Push bauen –
   verworfen (unnötige Minuten und Release-Rauschen).
2. **Rolling Release „Aktueller Stand“:** fester Tag `latest-build`, als Vorabversion markiert.
   Bei jedem Build wird der Tag auf den Commit gesetzt und das Release mit neuen Dateien ersetzt
   (`gh release` löschen und neu anlegen oder Dateien mit `--clobber` ersetzen). Alternative: nur
   Workflow-Artefakte – verworfen (laufen ab, keine stabile URL).
3. **Dateien:** `Regatta-windows.zip`, `Regatta-linux.zip` (stabile Namen), `SHA256SUMS.txt`,
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
   `docs.yml` auf `main` auf (wie bisher per `gh workflow run`); `docs.yml` holt das Release „Aktueller
   Stand“ (sonst das neueste feste) nach `site/downloads`, erzeugt den Versionsabschnitt und baut
   strikt. Pages-Größe: zwei Zips etwa 180 MB, unter dem Limit.
7. **Concurrency:** `concurrency: group: build` mit `cancel-in-progress` für Branch-Pushes, damit
   nur der neueste Stand gebaut wird.
8. **Installationsanleitung** auf `download.md`: je Windows und Linux Schritt für Schritt,
   Voraussetzungen (Vulkan-fähige Grafik; Hinweis auf `--rendering-method gl_compatibility`),
   SmartScreen („Weitere Informationen → Trotzdem ausführen“), `chmod +x`, Controller (Joy-Con per
   Bluetooth), Netzwerkspiel (UDP-Port aus der Spielanleitung, Firewall-Freigabe), Prüfsumme
   (`certutil`/`sha256sum`), Fehlerbehebung, Deinstallation (Ordner löschen, Einstellungsordner
   `user://` nennen).

Annahme: macOS bleibt als manuelle Option erhalten (nicht entfernt), weil die Presets bereits
funktionieren; die Download-Seite nennt dann einen zusätzlichen macOS-Link nur, wenn die Datei im
Release liegt.

## Risks / Trade-offs

- Rolling Release wird oft überschrieben → Versionsangabe und Prüfsummen auf der Seite geben
  Nachvollziehbarkeit; feste Releases über Tags für Stabilität.
- Workflow-Berechtigungen (Schreibrechte, Pages) lassen sich nur im Repository einstellen → in der
  Doku und im Workflow-Kopf beschrieben; ohne sie schlägt der Lauf mit klarer Meldung fehl.
- Build-Zeit (Godot- und Vorlagen-Download ~1,3 GB) → Cache wie bisher.
- Ein defekter Build blockiert den Doku-Neubau nicht (Doku läuft eigenständig weiter).
