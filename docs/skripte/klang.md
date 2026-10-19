# Klang (`sfx.gd`, `tools/make_audio.py`)

Alle Töne sind **selbst erzeugt**: `tools/make_audio.py` synthetisiert sie mit Python und
schreibt `audio/*.ogg`; `scripts/sfx.gd` spielt sie ab. Jede Datei kann durch eine echte
Aufnahme gleichen Namens ersetzt werden.

## `sfx.gd`

`class_name Sfx`, `extends Node`, 110 Zeilen. Kein Autoload, sondern **selbstverwaltet**: Der
erste, der `Sfx.ensure(get_tree())` aufruft, legt eine Instanz an und hängt sie an die
**Wurzel** des Baums, sodass sie über Szenenwechsel hinweg lebt (die Musik läuft im Menü
weiter). Deshalb ruft jede Szene (`menu`, `lobby`, `main`) `ensure` auf.

```gdscript
const AUDIO_DIR := "res://audio/"
const MUSIC_DB := -8.0     # Lautstärke Musik
const SFX_DB := -10.0      # einmalige Effekte
const LOOP_DB := -12.0     # Dauergeräusche

static var instance: Sfx
static var _cache := {}    # Name -> AudioStream, damit jede Datei nur einmal geladen wird
```

### Drei Arten von Klängen

| Art | Aufruf | Beispiel |
|---|---|---|
| **Einmalig** | `Sfx.play("bell", volume_db, pitch)` | Glocke beim Runden, `go`, `crunch`, `explosion` |
| **Schleife** | `Sfx.make_loop_player("water_loop")` liefert einen `AudioStreamPlayer` | Wasser, Flattern, Motor, Wind |
| **Musik** | automatisch beim Start (`music_loop`), `M` schaltet stumm | Renn-Shanty |

```gdscript
static func _play(sound: String, volume_db: float, pitch: float) -> void:
    var p := AudioStreamPlayer.new()
    p.stream = stream(sound)
    p.volume_db = volume_db + SFX_DB
    p.pitch_scale = pitch                       # Tonhöhe leicht variieren: Abwechslung
    instance.add_child(p)
    p.finished.connect(p.queue_free)            # nach dem Abspielen aufräumen
    p.play()
```

`stream(name)` lädt `res://audio/<name>.ogg`, setzt bei Namen mit `_loop` am Ende
`loop = true` und gibt bei **fehlender Datei `null`** zurück: Das Spiel bleibt dann einfach
still, statt abzustürzen. Zum Nachbauen kann man also **ohne Klang** beginnen.

### Netzwerk-Hinweis

`Sfx.play` gibt im Netzwerk-Rennen den Ton an die Clients weiter (`Net.send_event("sfx", …)`),
**außer** `starter`: Den Anlasser erkennen Clients am Motorzustand selbst. `Sfx.play_local`
spielt nur lokal.

### Dauerklänge am Boot

In `boat.gd` `_process`:

```gdscript
_snd_water.volume_db = linear_to_db(clampf(spd / 5.0, 0.0, 1.0) * 0.5 + 0.0001) + Sfx.LOOP_DB
_snd_water.pitch_scale = 0.8 + clampf(spd / 6.0, 0.0, 0.6)
```

Lautstärke **und** Tonhöhe folgen dem Tempo, das klingt nach mehr Fahrt. `linear_to_db`
rechnet von 0…1 in Dezibel um; `+ 0.0001` verhindert `−∞` bei 0.

## `tools/make_audio.py` { #tools-make-audio-py }

Aufruf: `python tools/make_audio.py` (benötigt `numpy`, `scipy`, `soundfile`). Teilbereiche:

```bash
python tools/make_audio.py motor      # nur Motorgeräusche
python tools/make_audio.py music      # nur Soundtrack
python tools/make_audio.py hazards    # Explosion, Polizeisirene, Sirenengesang
```

### Bausteine

| Funktion | Macht |
|---|---|
| `noise(dur, color)` | weißes, rosa, braunes Rauschen |
| `lp`, `hp`, `bp` | Tief-, Hoch-, Bandpass (Butterworth) |
| `smooth_random(dur, rate)` | weiche Zufallskurve 0…1 für Modulation |
| `env_adsr(n, a, d, s, r)` | Lautstärkehüllkurve (Attack, Decay, Sustain, Release) |
| `reverb(x, wet, size, damp)` | kleiner Schroeder-Hall (vier Kammfilter, zwei Allpässe) |
| `make_loop(x, fade)` | nahtlose Schleife: Ende über den Anfang blenden |
| `save(name, x, peak_db)` | normalisieren und als OGG/Vorbis in Blöcken schreiben |

### Wie klingt etwas „nach Wasser“?

```python
def water_loop():
    ...  # braunes Rauschen, tiefpassgefiltert, langsam in der Lautstärke moduliert
```

Fast alle Naturgeräusche sind **gefiltertes Rauschen mit Hüllkurve**. Ein Schlag (Explosion):

```python
def explosion():
    thump = np.sin(2*np.pi*(95*np.exp(-t*3.5)+28)*t) * np.exp(-t*2.2)   # fallender Sinus = Wumms
    boom  = lp(noise(dur, "brown"), 380) * np.exp(-t*2.6)               # dumpfes Rauschen
    crack = hp(noise(dur), 900) * np.exp(-t*14) * 0.5                   # kurzes Knacken
    ...
```

* **fallende Frequenz** (`95·e^(−3,5t) + 28`) lässt den Schlag „absacken“,
* **exponentielles Abklingen** (`e^(−k·t)`) ist der natürliche Klang jedes Schlags.

### Sirenengesang

Zwei Stimmen im Abstand einer großen Terz (`ratio 1,2599`), jede mit vier Obertönen
(`1·f, 2·f, 3·f, 4·f`), **Vibrato** (`1 + 0,006·sin(2π·5,2·t)`) und Formantfilter (um 800 und
1200 Hz, ergibt einen „Aaah“-Vokal), Motiv in Pentatonik (A–C–D–E–D–C–A), viel Hall:

```python
notes = [(0.0, 1.2, "A4"), (1.1, 1.0, "C5"), (2.0, 1.3, "D5"), (3.2, 1.0, "E5"), ...]
```

`trim(x, seconds, fade)` kürzt die Hallfahne, damit der Klang zur Dauer des Gesangs (7 s) passt.

### Die Dateien

| Datei | Verwendung |
|---|---|
| `wind_loop`, `water_loop`, `flap_loop`, `engine_loop`, `outboard_loop` | Schleifen |
| `whoosh`, `crunch`, `bell`, `beep`, `go`, `finish`, `starter`, `engine_stop`, `tug_horn` | einmalig |
| `explosion`, `police_siren`, `siren_song` | Gefahren |
| `music_loop` | Soundtrack (6/8, d-Moll, 96 bpm: galoppierender Bass, Akkordeon, Tin Whistle, Bodhrán) |

## Übung

Erzeuge einen neuen Ton „Möwenschrei“ als `audio/gull.ogg`: Dann `Sfx.play("gull", -6.0)` an einer
Stelle deiner Wahl, z. B. in `main.gd` beim Start des Countdowns. Ohne die Datei bleibt es still, das
Spiel läuft weiter.
