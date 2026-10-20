# Netzwerk (`net.gd`, `net_input.gd`)

## Das Modell: Host rechnet, Clients zeigen

```
   Client A                        HOST                          Client B
  ┌─────────┐   Eingaben (60 Hz)  ┌──────────────┐  Eingaben   ┌─────────┐
  │ Tasten  │ ──────────────────► │ Boote, Wind, │ ◄────────── │ Tasten  │
  │ Anzeige │ ◄────────────────── │ Bahn, KI,    │ ──────────► │ Anzeige │
  └─────────┘  Schnappschuss 20Hz │ Gefahren     │ Schnappschuss└─────────┘
                                  └──────────────┘
```

* Der **Host** führt die komplette Simulation aus (genau wie im lokalen Spiel). Er ist die
  einzige „Wahrheit“.
* **Clients** schicken nur ihre **Eingaben** (Lenken, Schot, Gas-Zähler) und bekommen 20×
  pro Sekunde einen **Schnappschuss** mit dem Zustand aller Boote, den sie weich anzeigen.
* Computerboote rechnet der Host.

**Vorteil:** Es gibt keine Abweichungen und kein Schummeln, weil nur eine Maschine rechnet.
**Nachteil:** Der Client sieht seine Eingaben erst nach der Umlaufzeit (kurzes Verzögern). Für
ein gemütliches Segelspiel ist das unkritisch.

## Godots High-Level-Multiplayer in zehn Zeilen

```gdscript
var peer := ENetMultiplayerPeer.new()
peer.create_server(24850, 8)                 # Host
multiplayer.multiplayer_peer = peer

var peer := ENetMultiplayerPeer.new()
peer.create_client("192.168.1.20", 24850)    # Client
multiplayer.multiplayer_peer = peer
```

`multiplayer.get_unique_id()` ist die Peer-ID (der Host ist immer `1`). Funktionen mit
`@rpc` kann man auf anderen Rechnern aufrufen:

```gdscript
@rpc("any_peer", "reliable")                  # darf von jedem kommen, wird garantiert zugestellt
func _register(player_name: String, count: int, version: String) -> void: ...

_register.rpc_id(1, my_name, local_players, VERSION)   # Aufruf: nur bei Peer 1 (dem Host)
```

| `@rpc`-Parameter | Bedeutung |
|---|---|
| `"authority"` / `"any_peer"` | Wer darf aufrufen? Nur der Host / jeder |
| `"reliable"` | kommt garantiert und in Reihenfolge an (Lobby, Meldungen) |
| `"unreliable_ordered"` | darf verloren gehen, aber Reihenfolge bleibt (Schnappschüsse, Eingaben) |
| `"call_local"` | läuft auch auf dem aufrufenden Rechner |

## `net.gd` (Autoload `Net`)

`extends Node`, 410 Zeilen. Es ist ein **Autoload**, deshalb ist `Net` in Menü, Lobby und
Rennen immer da.

### Konstanten und Zustand

```gdscript
const VERSION := "regatta-1"       # nur gleiche Version darf beitreten
const GAME_PORT := 24850           # UDP, vom Host im Router freizugeben
const DISCOVERY_PORT := 24851      # LAN-Suche (UDP-Broadcast)
const MAX_BOATS := 4
const SNAPSHOT_HZ := 20.0

var mode := Mode.OFFLINE           # OFFLINE, HOST, CLIENT
var players := {}                  # peer_id -> {"name", "count"}
var settings := {"level": "", "wind": 0, "gust": 0, "bots": 0, "ai": 1, "fuel": 0}
var in_race := false
var found_games := {}              # LAN-Suche: "ip:port" -> Infos
var game: Node                     # laufendes Rennen (main.gd)
```

### Signale

| Signal | Wann | Empfänger |
|---|---|---|
| `lobby_changed` | Mitsegler oder Einstellung geändert | `lobby.gd` |
| `games_changed` | LAN-Liste geändert | `lobby.gd` |
| `status(text)` | Statusmeldung | `lobby.gd`, `menu.gd` |

### Verbinden

`host(port)`, `join(address)` (Format `192.168.1.20` oder `server.de:24850`), `leave()`.
Beim Beitreten schickt der Client im `connected_to_server`-Signal sofort `_register` mit
Namen, Spielerzahl und `VERSION`. Der Host prüft:

```gdscript
if version != VERSION:                    _reject(id, "Andere Spielversion beim Host")
elif in_race:                             _reject(id, "Das Rennen läuft bereits …")
elif human_boats() + count > MAX_BOATS:   _reject(id, "Regatta ist voll (höchstens 4 Boote)")
else:  players[id] = {...};  _send_lobby()
```

`_reject` schickt den Grund und trennt nach 0,5 s (damit die Nachricht noch ankommt).

### Lobby-Synchronisation

`_send_lobby()` ruft `_lobby_state.rpc(players, settings)` bei **allen**: Das ganze
Lobby-Dictionary wird einfach neu verteilt. Bei so kleinen Datenmengen ist das einfacher und
robuster als Einzeländerungen. Der Host ändert Einstellungen mit
`Net.set_setting(key, value)`, was `settings` ändert und `_send_lobby()` auslöst.

### Einstellungen und Rennstart

```gdscript
func start_race() -> void:
    var cfg := {
        "slots": build_slots(),            # welche Boote, mit Namen, Farben, KI-Stärke
        "level": settings["level"],
        "wind": settings["wind"], "gust": settings["gust"], "fuel": ...,
        "gust_seed": randi(), "dir_seed": randi(),     # alle sehen dieselben Böen!
    }
    _start_race.rpc(cfg)                                 # an alle, auch an den Host selbst

@rpc("authority", "call_local", "reliable")
func _start_race(cfg: Dictionary) -> void:
    GameState.apply_net_config(cfg, multiplayer.get_unique_id(), "host" if mode == Mode.HOST else "client")
    in_race = true
    get_tree().change_scene_to_file(GAME_SCENE)
```

Die Konfiguration landet in `GameState`, und `main.gd` baut daraus das Rennen: derselbe Code
wie lokal, nur mit `net != ""`. Im Zustand `waiting` wartet der Host, bis alle Clients
`notify_loaded()` gemeldet haben (`all_loaded()`, maximal 20 s).

### LAN-Suche

```
 Host:   alle 1 s  JSON per UDP-Broadcast (255.255.255.255:24851)
         {"game":"regatta-1","name":"Hosti","boats":1,"max":4,"level":...,"port":24850,"open":true}
 Client: bindet Port 24851, liest Pakete, trägt sie in found_games ein,
         vergisst Hosts, die 3,5 s nichts gesendet haben
```

Nur Pakete mit passendem `"game": VERSION` zählen. Ist der Port 24851 belegt (zweites Spiel
auf demselben Rechner), bleibt die Suche aus, ohne Fehler.

### Eingaben und Schnappschüsse

| Richtung | Funktion | Modus | Inhalt |
|---|---|---|---|
| Client → Host | `send_inputs(data)` → `_inputs` | `unreliable_ordered` | je lokales Boot: `[Slot, steer, sheet_rate, tack_count, jibe_count, start_count]` |
| Host → Client | `send_snapshot(data)` → `_snapshot` | `unreliable_ordered` | `PackedFloat32Array` mit Zustand, Zeit, Wind, Booten, Schleppern |
| Host → Client | `send_event(kind, args)` → `_event` | `reliable` | `"sfx"` und `"msg"` (Meldungen) |

**Warum zwei Zähler (`tack`, `jibe`) für Gas?** In der Client-Eingabe heißen sie historisch
`tack`/`jibe`, werden aber als Gas-hoch/runter-Zähler genutzt (siehe `NetInput`).

### Der Schnappschuss

`main.gd._make_snapshot()` packt:

```
 [Zustand, Countdown, Rennzeit, Start-Blitz, Windzeit, Sieger, Bootzahl, Schlepperzahl]
 + je Boot 30 Zahlen (Boat.net_pack)
 + je Schlepper 6 Zahlen (Tug.net_pack)
```

`apply_snapshot` liest sie in **derselben Reihenfolge** wieder aus. Alles ist `float32`,
auch Bool-Werte (`0.0`/`1.0`). Das ist kompakt (ca. 130 Zahlen ≈ 520 Byte bei 4 Booten) und einfach.

### Dinge, die nicht übertragen werden müssen

Die **Berufsschiffe** (`ShippingLane`) haben keinen eigenen Zustand: Ihre Position ist eine
**reine Funktion der Rennzeit** (`ships_at(t)`). Der Host schickt ohnehin die Rennzeit im
Schnappschuss, und `main.gd` gibt sie über `ShippingLane.clock` an die Schiffe weiter, sodass
alle Rechner dieselben Schiffe sehen. Dasselbe Muster gilt für die Minen (fester Seed) und die
Böen (Seeds im Startpaket): **Was deterministisch berechenbar ist, braucht keine
Netzwerkdaten.** Nur die Kollision wird allein auf dem Host entschieden.

### Glätten auf dem Client

Der Client bekommt nur 20 Bilder pro Sekunde, zeichnet aber 60+. Ein Boot (`puppet`) rechnet
zwischen den Schnappschüssen **weiter** (`_net_pos += (vel + current) * delta`) und zieht seine
Anzeigeposition **exponentiell** nach: `lerp(p, _net_pos, 1 − exp(−10·dt))`. Ergebnis:
flüssige Bewegung ohne Ruckeln.

### Disconnect und Fehler

* Client verliert den Host: `_on_server_lost` → Meldung, zurück in die Lobby.
* Host verliert Client: `_on_peer_disconnected` → Spieler entfernt, `game.on_peer_left(id)`
  setzt dessen Boot auf Leereingabe und meldet „Verbindung verloren“.

## `net_input.gd` { #net-input-gd }

Siehe [Eingabe](eingabe.md#net-input-gd). Es empfängt auf dem Host die Zähler und macht daraus
die gewohnten `PlayerInput`-Felder.

## Testen

```bash
godot --headless --path . --script res://tests/net_test.gd -- host      # Terminal 1
godot --headless --path . --script res://tests/net_test.gd -- client    # Terminal 2
```

Beide Prozesse starten ein Rennen, der Client „drückt“ A+W und beide geben nach einigen
Sekunden die Bootszustände aus, die **übereinstimmen** sollten.

## Internet-Betrieb

Direkt per IP funktioniert nur, wenn der Host UDP-Port 24850 freigibt. Einfacher ist ein
virtuelles Netzwerk (ZeroTier, Tailscale): Dann verhält es sich wie ein LAN. Siehe
[Mehrspieler](../spielen/mehrspieler.md).

!!! warning "Versionen"
    Wer Felder in `net_pack` ändert, muss `VERSION` in `net.gd` erhöhen, sonst bekommen alte
    Clients falsche Zahlen. Die Versionsprüfung beim Beitritt schützt davor.
