# Konstanten und Stellschrauben

Wo ändert man was, damit sich das Spiel anders anfühlt? Eine Sammlung der Werte, die das
**Spielgefühl** bestimmen, mit der erwarteten Wirkung.

## Segeln (`scripts/boat.gd`)

| Wert | Standard | Erhöhen bewirkt … |
|---|---|---|
| `DRIVE` | 0,085 | Boote werden schneller (Vortrieb) |
| `DRAG` | 0,2 | Boote werden langsamer (Widerstand); Höchstgeschwindigkeit `sqrt(drive/DRAG)` |
| `TURN_RATE` | 1,1 rad/s | Boot dreht schneller |
| `NO_GO` | 0,38 rad | größere Sperrzone gegen den Wind, Kreuzen wird schwerer |
| `LATERAL_DAMP` | 4,0 | weniger seitliches Rutschen (stärkeres Schwert) |
| `SHEET_SPEED` | 0,7 | Schot wird schneller geholt |
| `JIB_SHARE` | 0,32 | die Fock zählt mehr |
| Trimmbreite `0.4` (Groß) / `0.35` (Fock) in `_trim_sails` | kleiner = kritischere Trimmung | |
| Krängung `0.008`, Schwelle `0.42` | mehr/weniger Krängung | |

## Wendeschub und Kollisionen

| Wert | Standard | Wirkung |
|---|---|---|
| `TACK_BOOST` | 1,5 | Stärke des Wendeschubs |
| `TACK_BOOST_TIME` | 2,2 s | Dauer |
| `TACK_BOOST_MIN` | 1,3 m/s | Mindestfahrt |
| `TACK_COOLDOWN` | 5 s | Sperre bis zum nächsten Schub |
| `collide`: `0.3` und `1.5 + 2.0·s` | | Tempoverlust (30 %) und Strafzeit (1,5 bis 4 s) |
| `scrape`: `0.6` | | Bremswirkung bei Dauerkontakt |

## Wind (`scripts/wind_field.gd`, `Level`)

| Wert | Standard | Wirkung |
|---|---|---|
| `Level.wind_speed` | 6 m/s | Grundwind |
| `Level.wind_shift_deg` | 17° | Winddreher |
| `Level.gusts` | 0,9 | Böigkeit |
| `shadow_length`, `shadow_strength` | 50 m, 0,5 | Windschatten von Booten |
| `land_shadow_length`, `land_shadow_strength` | 170 m, 0,88 | Windschatten von Land |
| `_dir_noise.frequency` | 0,005 | kleiner = großräumigere Windunterschiede |

## Grund und Land (`scripts/sea_chart.gd`)

| Wert | Standard | |
|---|---|---|
| `DRAFT` | 1,0 m | Tiefgang |
| `HARD` | 0,55 m | festgefahren |
| `LAND` | −0,8 m | Ufergrenze |
| `RES` | 448 | Auflösung des Tiefenrasters |

## Motor (`boat.gd`)

`THROTTLE_MAX 4`, `ENGINE_THRUST 1,9`, `START_TIME 1,1 s`, `TANK 20 l`, `FUEL_BURN 0,2 l/s`,
`REFUEL_RATE 2,2 l/s`. Treibstoff pro Bahn: `Level.fuel_liters` (Standard 6 l).

## Rennen (`scripts/main.gd`, `course.gd`)

| Wert | Standard | |
|---|---|---|
| `STUCK_WAIT` | 4 s | bis der Schlepper gerufen wird |
| `countdown` | 4 s | Startzeit |
| `CourseMark.MARK_RADIUS` | 20 m | Rundungskreis |
| `SNAPSHOT_HZ` | 20 | Netzwerk-Taktung |

## Gefahren

| Wert | Datei | Standard |
|---|---|---|
| `MINE_HIT` | `restricted_area.gd` | 4,8 m |
| `GRACE` | `restricted_area.gd` | 1,6 s |
| `HOLD_TIMES` | `boat.gd` | Polizei 8 s, Sirenen 7 s |
| `IMMUNE_TIME` | `boat.gd` | 25 s |
| `song_range` | `SirenIsland` | 70 m (im Inspector) |
| `mine_count`, `radius` | `RestrictedArea` | 14, 60 m (im Inspector) |

## Berufsschifffahrt (`scripts/level/shipping_lane.gd`, `boat.gd`)

| Wert | Standard | |
|---|---|---|
| `speed_kn` | 7 kn | Schiffsgeschwindigkeit |
| `interval` | 140 s | Abstand zweier Schiffe in **einer** Richtung (beide Richtungen: alle 70 s ein Schiff) |
| `lane_offset` | 22 m | Fahrspur rechts von der Mittellinie |
| `ship_length`, `beam` | 80 m, 16 m | Rumpf (Kollisionsradius `beam/2 + 1,5`) |
| `WARN_DIST`, `WARN_PAUSE` | 95 m, 25 s | Warnung und Horn |
| `ship_hit`: `0.7`, `5.0 s` | `boat.gd` | Fahrtverlust und Strafzeit |

## Kamera (`scripts/split_camera.gd`)

`PITCH 68°`, `FOV 50`, `SPLIT_ON 125`, `SPLIT_OFF 95`, `SPLIT_DIST 58`, `MIN_DIST 48`.

## Eingabe (`scripts/player_input.gd`)

`DEADZONE 0,18`, Tastenbelegung `KEYMAPS`.

## Computergegner (`scripts/ai_input.gd`)

Parameter je Stärke im `match level:` von `_init`: `_think_every`, `_trim_error`,
`_heading_noise`, `_look`, `_maneuver_cost`, `_min_gap`, `_motor_use`, `_motor_reserve`.
Raster: `NAV_CELL 8 m`, `NAV_SAFE_DEPTH 1,6 m`.

## Lautstärken (`scripts/sfx.gd`)

`MUSIC_DB −8`, `SFX_DB −10`, `LOOP_DB −12`.

## Zusammenhänge, die man beim Ändern bedenken muss

* `NO_GO` und die Tabelle `POLAR` in `ai_input.gd` hängen zusammen: Ändert man die Physik, muss
  man `tests/polar_test.gd` ausführen und `POLAR` anpassen, sonst segelt die KI schlechte
  Kurse.
* `DRAFT`, `HARD`, `LAND` stehen auch im **Shader** der Karte (`CHART_SHADER`).
* `net_pack` und `net_unpack` müssen immer dieselbe Feldzahl haben (`NET_FIELDS`).
