# Download und Installation

Fertige Spielversionen für **Windows**, **Linux** und **macOS**. Sie werden von einer GitHub-Action
automatisch gebaut (siehe [Build und Release](../skripte/werkzeuge.md#build-und-release)) und
liegen als **GitHub Release** und als Spiegel auf dieser Seite.

* **Stabil** ist die neueste feste Version (Tag `v1.2.0` usw.). Sie ändert sich nur bei einem neuen Tag.
* **Snapshot** ist der neueste Stand von `main`. Er entsteht bei jedem Push automatisch, ist der
  aktuellste, aber nicht ausführlich getestet. Es gibt immer nur den neuesten Snapshot.

## Downloads

<!-- DOWNLOADS:START -->
Die Downloads erscheinen hier, sobald die Seite von der Pipeline gebaut wurde.
<!-- DOWNLOADS:END -->

Alle Versionen und Änderungsnotizen: [GitHub Releases](https://github.com/RincewindWizzard/regatta-game/releases).

## Voraussetzungen

| | Windows | Linux | macOS |
|---|---|---|---|
| System | Windows 10 oder 11, 64 Bit | 64-Bit-Linux (x86_64), z. B. Ubuntu 22.04 oder neuer | macOS 11 oder neuer (Intel und Apple Silicon) |
| Grafik | Grafikkarte mit **Vulkan** (aktueller Treiber) | **Vulkan**-fähiger Treiber (Mesa oder proprietär) | Metal (jedes Mac seit etwa 2014) |
| Platz | rund 150 MB | rund 100 MB | rund 200 MB |

Das Spiel braucht **keine Installation** und keine weiteren Programme: Programm und Spieldaten
stecken in einer Datei (Windows, Linux) bzw. in der App (macOS).

## Prüfsumme prüfen (optional)

Der Anfang der SHA-256-Prüfsumme steht in der Tabelle oben, vollständig in `SHA256SUMS.txt`
des Releases. So prüfst du, ob der Download unverändert angekommen ist:

```bash
# Linux und macOS
sha256sum Regatta-linux.zip        # macOS: shasum -a 256 Regatta-macos.zip
```

```powershell
# Windows (PowerShell)
Get-FileHash .\Regatta-windows.zip -Algorithm SHA256
```

## Windows

1. `Regatta-windows.zip` herunterladen und in einen Ordner deiner Wahl **entpacken** (Rechtsklick →
   „Alle extrahieren“), z. B. `C:\Spiele\Regatta`.
2. `Regatta.exe` doppelklicken.
3. Windows warnt beim ersten Start („Der Computer wurde durch Windows geschützt“), weil das Spiel
   nicht signiert ist: **Weitere Informationen → Trotzdem ausführen**.
4. Optional: Rechtsklick auf `Regatta.exe` → „Verknüpfung erstellen“ und auf den Desktop legen.

## Linux

```bash
unzip Regatta-linux.zip -d ~/Spiele/Regatta
cd ~/Spiele/Regatta
chmod +x Regatta.x86_64        # falls das Ausführrecht fehlt
./Regatta.x86_64
```

Wenn das Fenster schwarz bleibt oder das Spiel mit einer Grafikmeldung abbricht, fehlt meist ein
Vulkan-Treiber. Dann hilft der Kompatibilitätsmodus mit OpenGL:

```bash
./Regatta.x86_64 --rendering-method gl_compatibility
```

## macOS

Die App ist nicht von Apple signiert. Nach dem Entpacken einmal im Terminal:

```bash
unzip Regatta-macos.zip
xattr -cr Regatta.app                          # Quarantäne-Markierung entfernen
codesign --force --deep --sign - Regatta.app   # lokal ad-hoc signieren (nötig auf Apple Silicon)
open Regatta.app
```

Alternativ: Rechtsklick auf die App → **Öffnen** → im Dialog erneut **Öffnen**. Wer die App nach
`Programme` verschiebt, startet sie wie jede andere.

## Controller

Ein Controller wird automatisch erkannt (USB oder Bluetooth; auch **Switch-Pro-Controller** und
**Joy-Con**, ein einzelner Joy-Con genügt). Die Belegung steht in der
[Spielanleitung](anleitung.md#steuerung). Ein Rennen brichst du mit der **Zurück-Taste (1 s halten)** ab.

## Netzwerkspiel

Im LAN finden sich Spiele automatisch. Beim Host muss die **Firewall** das Spiel zulassen
(Windows: beim ersten Start „Zugriff zulassen“ wählen). Übers Internet gibt der Host im Router den
**UDP-Port 24850** frei, Details in [Mehrspieler](mehrspieler.md).

## Fehlerbehebung

| Problem | Lösung |
|---|---|
| Windows blockiert den Start | „Weitere Informationen → Trotzdem ausführen“; bei Virenscanner-Meldung die Datei per Prüfsumme (oben) prüfen |
| Linux: „Permission denied“ | `chmod +x Regatta.x86_64` |
| Linux/Windows: schwarzes Fenster, Absturz beim Start | Grafiktreiber aktualisieren; sonst mit `--rendering-method gl_compatibility` starten |
| macOS: „App ist beschädigt“ | `xattr -cr Regatta.app` und `codesign --force --deep --sign - Regatta.app` (siehe oben) |
| Ruckeln | unten rechts steht die FPS-Anzeige; Vollbild mit `F11`, andere Programme schließen |
| Kein Controller erkannt | Controller vor dem Start verbinden; Bluetooth-Kopplung prüfen |

## Deinstallation

Den Ordner (bzw. die App) löschen. Einstellungen des Spiels liegen getrennt davon, zum
vollständigen Entfernen auch diesen Ordner löschen:

| System | Ordner |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\Regatta` |
| Linux | `~/.local/share/godot/app_userdata/Regatta` |
| macOS | `~/Library/Application Support/Godot/app_userdata/Regatta` |

## Selbst bauen

Wer die Builds lokal erzeugen will, braucht Godot **4.7.2** samt Export-Vorlagen
(*Editor → Export-Vorlagen verwalten*) und ruft im Projektordner auf:

```bash
godot --headless --path . --export-release "Linux" build/linux/Regatta.x86_64
godot --headless --path . --export-release "Windows Desktop" build/windows/Regatta.exe
godot --headless --path . --export-release "macOS" build/macos/Regatta.zip
```

Die drei Export-Einstellungen („Presets“) stehen in `export_presets.cfg` im Projektordner.
