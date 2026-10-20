# Download

Fertige Spielversionen für **Windows**, **Linux** und **macOS**. Sie werden automatisch von
einer GitHub-Action gebaut (siehe [Build und Release](../skripte/werkzeuge.md#build-und-release))
und liegen jeweils als **GitHub Release** und als Spiegel auf dieser Seite.

<p>
<a class="download" href="../../downloads/Regatta-windows.zip"><strong>Windows</strong> (Regatta-windows.zip)</a><br>
<a class="download" href="../../downloads/Regatta-linux.zip"><strong>Linux</strong> x86_64 (Regatta-linux.zip)</a><br>
<a class="download" href="../../downloads/Regatta-macos.zip"><strong>macOS</strong> Intel und Apple Silicon (Regatta-macos.zip)</a>
</p>

Alle Versionen und die Änderungsnotizen stehen unter
[GitHub Releases](https://github.com/RincewindWizzard/regatta-game/releases/latest).
Gibt es noch kein Release, funktionieren die Links oben noch nicht.

## Starten

Zip-Datei entpacken und das Spiel starten. Es braucht keine Installation und keine weiteren
Dateien: Programm und Spieldaten stecken in einer einzigen Datei bzw. App.

### Windows

`Regatta.exe` doppelklicken. Windows warnt beim ersten Start („Der Computer wurde durch
Windows geschützt“), weil das Spiel nicht signiert ist: **Weitere Informationen →
Trotzdem ausführen**.

### Linux

```bash
unzip Regatta-linux.zip
chmod +x Regatta.x86_64     # falls das Ausführrecht fehlt
./Regatta.x86_64
```

### macOS

Das Spiel ist nicht von Apple signiert. Nach dem Entpacken einmal im Terminal:

```bash
xattr -cr Regatta.app                          # Quarantäne-Markierung entfernen
codesign --force --deep --sign - Regatta.app   # lokal ad-hoc signieren (nötig auf Apple Silicon)
open Regatta.app
```

Alternativ: Rechtsklick auf die App → **Öffnen** → im Dialog erneut **Öffnen**.

!!! note "Grafik"
    Das Spiel nutzt den Renderer „Forward Plus“ (Vulkan). Auf sehr alten Grafikkarten ohne
    Vulkan-Unterstützung läuft es nicht; dann hilft nur das Starten aus dem Quellcode mit
    `godot --rendering-method gl_compatibility`.

## Selbst bauen

Wer die Builds lokal erzeugen will, braucht Godot **4.7.2** samt Export-Vorlagen
(*Editor → Export-Vorlagen verwalten*) und ruft im Projektordner auf:

```bash
godot --headless --path . --export-release "Linux" build/linux/Regatta.x86_64
godot --headless --path . --export-release "Windows Desktop" build/windows/Regatta.exe
godot --headless --path . --export-release "macOS" build/macos/Regatta.zip
```

Die drei Export-Einstellungen („Presets“) stehen in `export_presets.cfg` im Projektordner.
