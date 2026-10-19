# Fahrplan zum Nachbau

Dieser Fahrplan führt in **14 Etappen** von einem leeren Godot-Projekt zum fertigen Spiel.
Jede Etappe hat ein **Ziel**, **Code** (die ersten sechs vollständig und getestet), eine
Kontrolle („Was du sehen solltest“) und einen Verweis auf das Kapitel, das den echten
Skript-Code der Etappe im Detail erklärt.

!!! tip "So arbeitest du am besten"
    * Tippe den Code **selbst ab** statt zu kopieren – dabei lernst du am meisten.
    * Starte nach **jeder** Etappe das Spiel. Eine Etappe ist erst fertig, wenn du sie sehen
      oder messen kannst.
    * Die Etappen 1–6 sind eigenständige Mini-Versionen (andere Dateinamen als im
      Originalprojekt, aber dieselben Formeln). Ab Etappe 7 baust du die Originaldateien nach
      und kannst jeweils das [Skript-Kapitel](../skripte/index.md) neben den Quelltext legen.

!!! warning "Neue `class_name`-Dateien einlesen lassen"
    Godot merkt sich globale Klassennamen (`class_name Chart`) in einem Cache. Im **Editor**
    wird er automatisch aktualisiert. Startest du dagegen **auf der Kommandozeile**
    (`godot --headless …`) nach dem Anlegen neuer Skripte, muss einmal
    `godot --headless --path . --import` laufen, sonst kommt „Identifier not declared“.

| Etappe | Thema | Neue Dateien |
|---|---|---|
| 1 | Bühne: Kamera, Licht, Wasserfläche | `main.gd` |
| 2 | Die Seekarte als Tiefenraster | `chart.gd` |
| 3 | Ein Boot, das fährt | `boat.gd` |
| 4 | Wind und Segelphysik | `boat.gd` erweitert |
| 5 | Grund und Land | `boat.gd` erweitert |
| 6 | Bahn und Tonnen | `course.gd` |
| 7 | Level als Szene mit Bausteinen | `level.gd`, `level/*.gd` |
| 8 | Anzeige (HUD) und Kameras | `hud.gd`, `split_camera.gd` |
| 9 | Wind mit Böen, Drehern, Windschatten | `wind_field.gd`, `currents.gd` |
| 10 | Computergegner | `ai_input.gd`, `player_input.gd` |
| 11 | Motor, Tankstelle, Schlepper | `tug.gd`, `fuel_dock.gd` |
| 12 | Menü, Spielzustand, Rennablauf | `menu.gd`, `game_state.gd`, `main.gd` |
| 13 | Gefahren, Tiere, Effekte | `restricted_area.gd`, `sea_life.gd`, … |
| 14 | Netzwerk, Klang, Editor-Plugin, Politur | `net.gd`, `sfx.gd`, `plugin.gd` |

---

## Etappe 1: Bühne

**Ziel:** Ein Fenster mit einer hellblauen Fläche, von schräg oben gesehen.

**Konzepte:** Node-Baum zur Laufzeit aufbauen, `Camera3D`, `PlaneMesh`, `look_at`
(→ [Godot-Grundlagen §1](grundlagen.md#1-nodes-und-szenen)).

Lege `scenes/main.tscn` mit einem `Node3D` als Wurzel an und hänge dieses Skript an:

```gdscript
extends Node3D


func _ready() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 90, 70)
	add_child(cam)
	cam.look_at(Vector3.ZERO)             # erst nach add_child aufrufen!

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -35, 0)
	add_child(sun)

	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2000, 2000)
	water.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.88, 0.96)
	water.material_override = mat
	add_child(water)
```

**Was du sehen solltest:** Eine einfarbige hellblaue Fläche, die perspektivisch nach hinten
verschwindet.

!!! note "Warum `look_at` erst nach `add_child`?"
    `look_at` braucht die globale Position der Kamera. Die gibt es erst, wenn der Node im
    Baum hängt. Dasselbe Muster siehst du in `split_camera.gd` (`_place`).

---

## Etappe 2: Die Seekarte als Tiefenraster

**Ziel:** Eine Karte mit Land, Flachwasser und tiefem Wasser, die man auch per Code
abfragen kann.

**Konzepte:** `static var`/`static func`, `PackedFloat32Array`, Rauschen (`FastNoiseLite`),
bilineare Interpolation, `Image` und `ImageTexture`
(→ [Seekarte und Tiefen](../skripte/seekarte.md)).

Das ist die wichtigste Idee des ganzen Spiels: **ein Zahlenraster, das zugleich Spiellogik
und Bild ist.** Lege `chart.gd` an:

```gdscript
class_name Chart
extends RefCounted
## Die Seekarte als Tiefenraster: Wie tief ist das Wasser an Position p?

const AREA_MIN := Vector2(-500, -500)    # linke obere Ecke der Karte (x, z) in Metern
const AREA_SIZE := 1000.0                # Kantenlänge in Metern
const RES := 200                         # Rasterzellen pro Kante (5 m je Zelle)
const LAND := -0.8                       # tiefer als das = festes Land

static var _depth := PackedFloat32Array()


## Raster mit Rauschen füllen: mal tief, mal flach, mal Land
static func build() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.004
	_depth.resize(RES * RES)
	var step := AREA_SIZE / RES
	for j in RES:
		for i in RES:
			var p := AREA_MIN + Vector2(i + 0.5, j + 0.5) * step
			_depth[j * RES + i] = 7.0 + noise.get_noise_2dv(p) * 14.0


## Wassertiefe an einer Weltposition, bilinear zwischen vier Rasterzellen
static func depth_at(p: Vector2) -> float:
	var f := (p - AREA_MIN) / AREA_SIZE * RES - Vector2(0.5, 0.5)
	if f.x < 0.0 or f.y < 0.0 or f.x >= RES - 1 or f.y >= RES - 1:
		return 20.0                                   # außerhalb: tiefes Wasser
	var i := int(f.x)
	var j := int(f.y)
	var fx := f.x - i
	var fy := f.y - j
	var a := lerpf(_depth[j * RES + i], _depth[j * RES + i + 1], fx)
	var b := lerpf(_depth[(j + 1) * RES + i], _depth[(j + 1) * RES + i + 1], fx)
	return lerpf(a, b, fy)


static func color_of(d: float) -> Color:
	if d < LAND:
		return Color(0.96, 0.87, 0.62)       # Land
	if d < 2.0:
		return Color(0.55, 0.76, 0.90)       # flach: kräftig blau
	if d < 5.0:
		return Color(0.74, 0.87, 0.95)
	if d < 10.0:
		return Color(0.88, 0.94, 0.98)
	return Color(0.99, 0.99, 0.97)           # tief: fast weiß wie auf Papierkarten


static func make_image() -> Image:
	var img := Image.create(RES, RES, false, Image.FORMAT_RGBA8)
	for j in RES:
		for i in RES:
			img.set_pixel(i, j, color_of(_depth[j * RES + i]))
	return img
```

Und zeige die Karte in `main.gd`:

```gdscript
extends Node3D


func _ready() -> void:
	Chart.build()
	var cam := Camera3D.new()
	cam.position = Vector3(0, 700, 520)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	add_child(DirectionalLight3D.new())

	# die Karte als Textur auf eine Fläche kleben
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(Chart.AREA_SIZE, Chart.AREA_SIZE)
	water.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED    # keine Beleuchtung: Papierkarte
	mat.albedo_texture = ImageTexture.create_from_image(Chart.make_image())
	water.material_override = mat
	add_child(water)
```

**Was du sehen solltest:** Eine Karte in Papier-Farben: Gelb ist Land, kräftiges Blau ist
flach, nach weiß hin wird es tiefer.

**Selbst probieren:** Rufe `print(Chart.depth_at(Vector2(0, 0)))` auf. Verändere
`noise.frequency` (größere Werte = kleinteiligere Karte) und `noise.seed`.

!!! note "Wie `depth_at` rechnet"
    Die Weltposition wird in Rasterkoordinaten umgerechnet (`f`), die vier umliegenden
    Zellen werden gelesen und zweimal linear gemischt (`lerpf`). Ergebnis: Die Tiefe ändert
    sich **stetig**, nicht in Stufen von 5 m. Das Originalprojekt macht es genauso
    (`sea_chart.gd`), nur mit 448×448 Zellen und einem Shader statt einer Textur.

---

## Etappe 3: Ein Boot, das fährt

**Ziel:** Ein rotes Boot, das man mit A/D lenkt, mit W/S beschleunigt, und eine Kamera, die
ihm folgt.

**Konzepte:** `_physics_process(delta)`, Eingabe mit `Input.is_physical_key_pressed`,
Winkel und Richtungsvektoren (→ [Das Boot](../skripte/boot.md),
[Koordinaten](grundlagen.md#10-koordinaten-und-winkel-in-diesem-projekt)).

```gdscript
class_name Boat
extends Node3D
## Etappe 3: Ein Boot, das man mit A/D lenkt und mit W/S beschleunigt.

var heading := 0.0       # Bug nach +z (Süden) bei 0
var speed := 0.0


func pos2d() -> Vector2:
	return Vector2(position.x, position.z)


func _ready() -> void:
	var hull := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3, 1.2, 9)
	hull.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.18, 0.15)
	hull.material_override = mat
	hull.position.y = 0.6
	add_child(hull)


func _physics_process(delta: float) -> void:
	var steer := 0.0
	if Input.is_physical_key_pressed(KEY_A):
		steer -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		steer += 1.0
	var gas := 0.0
	if Input.is_physical_key_pressed(KEY_W):
		gas += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		gas -= 1.0
	heading -= steer * 1.1 * delta                # rechts = im Uhrzeigersinn von oben
	speed = clampf(speed + gas * 2.0 * delta, 0.0, 6.0)
	var fwd := Vector2(sin(heading), cos(heading))
	position += Vector3(fwd.x, 0.0, fwd.y) * speed * delta
	rotation.y = heading
```

`main.gd` hängt das Boot ein und führt die Kamera nach:

```gdscript
extends Node3D

var boat: Boat
var cam: Camera3D


func _ready() -> void:
	Chart.build()
	cam = Camera3D.new()
	add_child(cam)
	add_child(DirectionalLight3D.new())
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(Chart.AREA_SIZE, Chart.AREA_SIZE)
	water.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = ImageTexture.create_from_image(Chart.make_image())
	water.material_override = mat
	add_child(water)
	boat = Boat.new()
	add_child(boat)


func _process(_delta: float) -> void:
	# Kamera schwebt 60 m hoch hinter dem Boot (Neigung 68°, wie im Spiel)
	var tgt := Vector3(boat.position.x, 0.0, boat.position.z)
	cam.position = tgt + Vector3(0.0, sin(deg_to_rad(68.0)) * 60.0, cos(deg_to_rad(68.0)) * 60.0)
	cam.look_at(tgt, Vector3.UP)
```

**Was du sehen solltest:** Du fährst mit der Kamera durch die Landschaft. Noch kann man
über Land fahren – das kommt in Etappe 5.

!!! note "Der Richtungsvektor"
    `Vector2(sin(heading), cos(heading))` ist die Blickrichtung. Bei `heading = 0` ergibt das
    `(0, 1)`: nach +z, also Süden. Diese Konvention (nicht `cos`, `sin`!) gilt im ganzen
    Projekt, siehe `boat.gd`.

---

## Etappe 4: Wind und Segelphysik

**Ziel:** Das Boot fährt nur durch den Wind. Ohne Wind kein Vortrieb, gegen den Wind geht es
nicht, die Schot muss passen.

**Konzepte:** Vektorrechnung (scheinbarer Wind), Polarkurve, `smoothstep`, `exp` als
Glockenkurve. Die Formeln sind ausführlich in
[Das Boot](../skripte/boot.md#segelphysik-schritt-fur-schritt) erklärt.

Ersetze `boat.gd`:

```gdscript
class_name Boat
extends Node3D
## Etappe 4: Segelphysik. Wind, Schot und Polarkurve bestimmen den Vortrieb.

const DRIVE := 0.085          # Vortriebsfaktor
const DRAG := 0.2             # quadratischer Wasserwiderstand
const LATERAL_DAMP := 4.0     # das Schwert hält das Boot in der Spur
const TURN_RATE := 1.1        # rad/s
const NO_GO := 0.38           # unter diesem Windwinkel (rad, ~22°) kein Vortrieb
const SHEET_SPEED := 0.7

var heading := 0.0
var vel := Vector2.ZERO       # Geschwindigkeit in m/s (x, z)
var sheet := 0.35             # 0 = Schot ganz dicht, 1 = ganz offen
var wind_from := 0.0          # Richtung, AUS der der Wind kommt (0 = Nord)
var wind_speed := 6.0
# Anzeige
var awa := 0.0                # scheinbarer Windwinkel
var luffing := false          # Segel flattert
var boom_abs := 0.0
var boom_opt := 0.0


func pos2d() -> Vector2:
	return Vector2(position.x, position.z)


func speed() -> float:
	return vel.length()


func _ready() -> void:
	var hull := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3, 1.2, 9)
	hull.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.18, 0.15)
	hull.material_override = mat
	hull.position.y = 0.6
	add_child(hull)


func _physics_process(delta: float) -> void:
	# --- Eingabe ---
	var steer := 0.0
	var trim := 0.0
	if Input.is_physical_key_pressed(KEY_A):
		steer -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		steer += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		trim -= 1.0                        # dichtholen
	if Input.is_physical_key_pressed(KEY_S):
		trim += 1.0                        # fieren
	sheet = clampf(sheet + trim * SHEET_SPEED * delta, 0.0, 1.0)
	# Steuern wirkt stärker bei Fahrt (Ruderwirkung)
	var fwd := Vector2(sin(heading), cos(heading))
	var steer_eff := clampf(0.25 + absf(vel.dot(fwd)) / 3.0, 0.25, 1.0)
	heading = wrapf(heading - steer * TURN_RATE * steer_eff * delta, -PI, PI)

	# --- scheinbarer Wind: wahrer Wind minus Fahrtwind ---
	fwd = Vector2(sin(heading), cos(heading))
	var port := Vector2(cos(heading), -sin(heading))       # Backbord = links
	var true_wind := Vector2(-sin(wind_from), cos(wind_from)) * wind_speed   # weht IN diese Richtung
	var app := true_wind - vel
	var from := -app                                       # Richtung, aus der er scheinbar kommt
	awa = atan2(from.dot(port), from.dot(fwd))             # + = Wind von Backbord
	var abs_awa := absf(awa)

	# --- Segel: Die Schot begrenzt, wie weit der Baum aufgehen darf ---
	var boom_max := lerpf(0.06, 1.5, sheet)
	var limit := maxf(abs_awa - 0.08, 0.0)                 # der Wind drückt den Baum nach Lee
	boom_opt = clampf(abs_awa * 0.5 - 0.1, 0.06, 1.45)     # ideale Baumstellung
	luffing = boom_max >= limit                            # Schot lose genug -> Segel killt
	boom_abs = minf(boom_max, limit)
	var trim_eff := exp(-pow((boom_abs - boom_opt) / 0.4, 2.0)) * (0.35 if luffing else 1.0)

	# --- Polarkurve: wie gut läuft das Boot in diesem Winkel zum Wind? ---
	var polar := smoothstep(NO_GO, 0.95, abs_awa) * (1.0 - 0.25 * smoothstep(2.0, PI, abs_awa))

	# --- Kräfte ---
	var drive := DRIVE * app.length_squared() * polar * trim_eff
	var spd_fwd := vel.dot(fwd)
	var spd_lat := vel.dot(port)
	spd_fwd += (drive - DRAG * spd_fwd * absf(spd_fwd)) * delta
	spd_lat *= exp(-LATERAL_DAMP * delta)
	vel = fwd * spd_fwd + port * spd_lat

	position += Vector3(vel.x, 0.0, vel.y) * delta
	rotation.y = heading
```

**Was du sehen solltest:** Mit Wind aus Norden (`wind_from = 0`) beschleunigt das Boot nur,
wenn es nicht nach Norden zeigt. Hält man `W` (Schot dicht) und `S` (fieren), merkt man, wie
sich die Geschwindigkeit ändert.

**Kontrolle per Test:** Ein Boot mit Kurs Ost (halber Wind) und optimal nachgeführter Schot
erreicht im getesteten Nachbau **4,97 m/s (9,7 kn)** bei 6 m/s Wind:

```gdscript
extends SceneTree
var b: Boat
var t := 0.0
func _initialize() -> void:
    b = Boat.new()
    b.heading = PI / 2          # Kurs Ost
    root.add_child(b)
func _physics_process(d: float) -> bool:
    t += d
    b.sheet = clampf((b.boom_opt - 0.06) / 1.44, 0.0, 1.0)   # Schot immer optimal
    return t > 30.0              # nach 30 s beenden
```

Starte es mit `godot --headless --path . --script res://t.gd`. So testet auch das
Originalprojekt (`tests/polar_test.gd`).

---

## Etappe 5: Grund und Land

**Ziel:** Flaches Wasser bremst, Land hält das Boot auf.

**Konzepte:** Die Karte aus Etappe 2 wird zur Spiellogik. Das ist der Kern der
Spielidee: *wo die Karte flacher ist als der Tiefgang, läuft man auf Grund*.

Das sind nur Ergänzungen in `boat.gd` (hier die vollständige Datei):

```gdscript
class_name Boat
extends Node3D
## Etappe 5: wie Etappe 4, dazu Grundberührung und Land.

const DRIVE := 0.085          # Vortriebsfaktor
const DRAG := 0.2             # quadratischer Wasserwiderstand
const LATERAL_DAMP := 4.0     # das Schwert hält das Boot in der Spur
const TURN_RATE := 1.1        # rad/s
const NO_GO := 0.38           # unter diesem Windwinkel (rad, ~22°) kein Vortrieb
const SHEET_SPEED := 0.7
const DRAFT := 1.0            # Tiefgang: flacher als das = Grundberührung
const HARD := 0.55            # noch flacher = festgefahren

var heading := 0.0
var vel := Vector2.ZERO       # Geschwindigkeit in m/s (x, z)
var sheet := 0.35             # 0 = Schot ganz dicht, 1 = ganz offen
var wind_from := 0.0          # Richtung, AUS der der Wind kommt (0 = Nord)
var wind_speed := 6.0
# Anzeige
var awa := 0.0                # scheinbarer Windwinkel
var luffing := false          # Segel flattert
var boom_abs := 0.0
var boom_opt := 0.0
var depth := 20.0
var aground := false
var message := ""


func pos2d() -> Vector2:
	return Vector2(position.x, position.z)


func speed() -> float:
	return vel.length()


func _ready() -> void:
	var hull := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(3, 1.2, 9)
	hull.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.18, 0.15)
	hull.material_override = mat
	hull.position.y = 0.6
	add_child(hull)


func _physics_process(delta: float) -> void:
	# --- Eingabe ---
	var steer := 0.0
	var trim := 0.0
	if Input.is_physical_key_pressed(KEY_A):
		steer -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		steer += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		trim -= 1.0                        # dichtholen
	if Input.is_physical_key_pressed(KEY_S):
		trim += 1.0                        # fieren
	sheet = clampf(sheet + trim * SHEET_SPEED * delta, 0.0, 1.0)
	# Steuern wirkt stärker bei Fahrt (Ruderwirkung)
	var fwd := Vector2(sin(heading), cos(heading))
	var steer_eff := clampf(0.25 + absf(vel.dot(fwd)) / 3.0, 0.25, 1.0)
	heading = wrapf(heading - steer * TURN_RATE * steer_eff * delta, -PI, PI)

	# --- scheinbarer Wind: wahrer Wind minus Fahrtwind ---
	fwd = Vector2(sin(heading), cos(heading))
	var port := Vector2(cos(heading), -sin(heading))       # Backbord = links
	var true_wind := Vector2(-sin(wind_from), cos(wind_from)) * wind_speed   # weht IN diese Richtung
	var app := true_wind - vel
	var from := -app                                       # Richtung, aus der er scheinbar kommt
	awa = atan2(from.dot(port), from.dot(fwd))             # + = Wind von Backbord
	var abs_awa := absf(awa)

	# --- Segel: Die Schot begrenzt, wie weit der Baum aufgehen darf ---
	var boom_max := lerpf(0.06, 1.5, sheet)
	var limit := maxf(abs_awa - 0.08, 0.0)                 # der Wind drückt den Baum nach Lee
	boom_opt = clampf(abs_awa * 0.5 - 0.1, 0.06, 1.45)     # ideale Baumstellung
	luffing = boom_max >= limit                            # Schot lose genug -> Segel killt
	boom_abs = minf(boom_max, limit)
	var trim_eff := exp(-pow((boom_abs - boom_opt) / 0.4, 2.0)) * (0.35 if luffing else 1.0)

	# --- Polarkurve: wie gut läuft das Boot in diesem Winkel zum Wind? ---
	var polar := smoothstep(NO_GO, 0.95, abs_awa) * (1.0 - 0.25 * smoothstep(2.0, PI, abs_awa))

	# --- Kräfte ---
	var drive := DRIVE * app.length_squared() * polar * trim_eff
	var spd_fwd := vel.dot(fwd)
	var spd_lat := vel.dot(port)
	spd_fwd += (drive - DRAG * spd_fwd * absf(spd_fwd)) * delta
	spd_lat *= exp(-LATERAL_DAMP * delta)

	# --- Grund: im Flachen stark gebremst, im ganz Flachen fast festgefahren ---
	depth = Chart.depth_at(pos2d())
	var was_aground := aground
	aground = depth < DRAFT
	if aground:
		var stuck := depth < HARD
		var k := exp(-(8.0 if stuck else 2.0) * delta)
		var cap := 0.15 if stuck else 0.8
		spd_fwd = clampf(spd_fwd * k, -cap, cap)
		spd_lat *= k
		if not was_aground:
			message = "Grundberührung!"
	vel = fwd * spd_fwd + port * spd_lat

	# --- Bewegen; gegen Land bleibt das Boot stehen ---
	var new_p := pos2d() + vel * delta
	if Chart.depth_at(new_p) < Chart.LAND:
		vel = Vector2.ZERO
	else:
		position.x = new_p.x
		position.z = new_p.y
	rotation.y = heading
```

**Was du sehen solltest:** Fährst du ins Flache, wird das Boot langsam. Gegen Land bleibt es
stehen. Der Boden-Zustand `aground` steht später im HUD und löst den Schlepper aus (Etappe 11).

---

## Etappe 6: Bahn und Tonnen

**Ziel:** Zwei gelbe Tonnen werden nacheinander gerundet; im Ziel kommt eine Meldung.

**Konzepte:** Signale (`signal`, `emit`, `connect`), Lambda-Funktionen, `Array[Vector2]`
(→ [Rennablauf](../skripte/rennen.md)).

```gdscript
class_name Course
extends Node
## Etappe 6: Bahnlogik. Start -> Marken der Reihe nach -> Ziel.

signal target_reached(boat: Boat, index: int)
signal boat_finished(boat: Boat)

const MARK_RADIUS := 20.0

var marks: Array[Vector2] = []        # Rundungsreihenfolge


## welches Ziel als Nächstes? Index in marks; marks.size() = Ziel
func update_progress(boat: Boat) -> void:
	if boat.finished:
		return
	var target := marks[boat.next_target]
	if boat.pos2d().distance_to(target) < MARK_RADIUS:
		target_reached.emit(boat, boat.next_target)
		boat.next_target += 1
		if boat.next_target >= marks.size():
			boat.finished = true
			boat_finished.emit(boat)
```

`boat.gd` bekommt zwei neue Variablen (`next_target`, `finished`), `main.gd` die Tonnen:

```gdscript
extends Node3D

var boat: Boat
var course: Course
var cam: Camera3D


func _ready() -> void:
	Chart.build()
	cam = Camera3D.new()
	add_child(cam)
	add_child(DirectionalLight3D.new())
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(Chart.AREA_SIZE, Chart.AREA_SIZE)
	water.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = ImageTexture.create_from_image(Chart.make_image())
	water.material_override = mat
	add_child(water)

	# zwei Tonnen als gelbe Kugeln
	course = Course.new()
	add_child(course)
	course.marks = [Vector2(0, -200), Vector2(150, -60)]
	for p in course.marks:
		var buoy := MeshInstance3D.new()
		buoy.mesh = SphereMesh.new()
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.98, 0.82, 0.1)
		buoy.material_override = bm
		buoy.position = Vector3(p.x, 1.0, p.y)
		buoy.scale = Vector3.ONE * 3.0
		add_child(buoy)
	course.target_reached.connect(func(_b: Boat, i: int): print("Marke ", i + 1, " gerundet"))
	course.boat_finished.connect(func(_b: Boat): print("Im Ziel!"))

	boat = Boat.new()
	boat.position = Vector3(0, 0, 0)
	add_child(boat)


func _physics_process(_delta: float) -> void:
	course.update_progress(boat)


func _process(_delta: float) -> void:
	var tgt := Vector3(boat.position.x, 0.0, boat.position.z)
	cam.position = tgt + Vector3(0.0, sin(deg_to_rad(68.0)) * 60.0, cos(deg_to_rad(68.0)) * 60.0)
	cam.look_at(tgt, Vector3.UP)
```

**Was du sehen solltest:** Fährst du in 20 m Abstand an die erste Tonne, erscheint
„Marke 1 gerundet“ in der Ausgabe, danach „Marke 2“, dann „Im Ziel!“.

!!! note "Was das Original zusätzlich kann"
    `course.gd` kennt auch eine **Startlinie** (Überfahren in Pfeilrichtung) und ein **Ziel**
    (dieselbe Linie in Gegenrichtung) und berechnet einen Rang (`progress`). Mehr unter
    [Rennablauf](../skripte/rennen.md#course-gd).

---

## Etappe 7: Level als Szene mit Bausteinen

**Ziel:** Die Karte und die Tonnen nicht mehr fest im Code, sondern als bearbeitbare Szene.

**Was zu tun ist:**

1. Lege `scripts/level/level.gd` mit `class_name Level` an (`@tool`). Es besitzt die
   Export-Variablen Name, Wind, Treibstoff und Seegrund-Parameter und die Methode
   `compute_depth(res)`, die das Tiefenraster **aus den Kindern** berechnet (Rauschen als
   Untergrund, dann Küsten, dann jede Insel/Untiefe mit ihrem `depth_profile`).
2. Lege die Bausteine an: `StartLine`, `CourseMark`, `ShoalArea`, `SeaMark` (je ein `@tool`
   `Node3D`-Skript mit `_rebuild()`, das sich per `SurfaceTool` selbst zeichnet).
3. Lege `levels/01_mittelgrund.tscn` an: Wurzel `Node3D` mit Skript `level.gd`, Kinder
   per „Node hinzufügen“ → Skript zuweisen (oder mit dem Editor-Plugin aus Etappe 14).
4. `Chart.build()` aus Etappe 2 wird durch `level.compute_depth()` ersetzt,
   die Tonnen durch `level.marks()`.

**Lies dazu:** [Level und Bausteine](../skripte/level.md) erklärt jede Datei in
`scripts/level/`, mit Aufbau, Methoden und Beispielen. Für das Zeichnen der Symbole
(gestrichelte Kreise, Beschriftungen) siehe [Seekarte und Tiefen](../skripte/seekarte.md#hilfsfunktionen-zum-zeichnen).

**Was du sehen solltest:** Im Editor erscheinen beim Verschieben einer Tonne sofort die
Linien und Beschriftungen an der neuen Stelle (`@tool` + Setter).

---

## Etappe 8: Anzeige (HUD) und Kameras

**Ziel:** Geschwindigkeit, Schot-Balken, nächste Tonne, Windrose und Minikarte; bei zwei
Booten ein geteilter Bildschirm.

**Was zu tun ist:**

* `hud.gd` (`class_name RaceHud`, `extends Control`) zeichnet alles in `_draw()` mit
  `draw_rect`, `draw_string`, `draw_arc`. In `_process` ruft es `queue_redraw()` auf.
* `split_camera.gd` (`SplitCameraManager`) besitzt **zwei `SubViewport`s mit je einer
  `Camera3D`** in zwei `SubViewportContainer`s. Sind die Boote nah, ist die rechte Hälfte
  unsichtbar und die linke füllt den Bildschirm.

**Beispiel** für eine HUD-Zeile (aus `hud.gd`, vereinfacht):

```gdscript
func _draw() -> void:
    var vs := get_viewport_rect().size
    draw_rect(Rect2(10, vs.y - 100, 300, 90), Color(0.99, 0.98, 0.94, 0.94))   # Papier
    draw_string(font, Vector2(24, vs.y - 60), "%.1f kn" % (boat.speed() * 1.944),
        HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.08, 0.08, 0.1))
```

**Lies dazu:** [Kamera und Anzeige](../skripte/kamera-hud.md).

---

## Etappe 9: Wind mit Böen, Drehern und Windschatten

**Ziel:** Der Wind ist nicht mehr konstant: Er dreht langsam, hat Böen und Flauten,
Boote und Inseln werfen Windschatten.

**Was zu tun ist:** `wind_field.gd` (`WindField`, `extends Node`) mit `get_wind(p, exclude)`,
`gust_at(p)`, `dir_at(p)`, `shadow_factor(p, blow_dir, exclude)`. `boat.gd` ersetzt die
Konstante `wind_from/wind_speed` durch `wind.get_wind(pos2d(), self)`. `currents.gd` bündelt
Strömungen: `Currents.at(p)` wird zum Vektor addiert (`ground = vel + current`).

**Lies dazu:** [Wind und Strömung](../skripte/wind.md).

---

## Etappe 10: Computergegner

**Ziel:** Boote, die selbst segeln.

**Was zu tun ist:** Teile die Eingabe von `Boat` ab: `player_input.gd` (`PlayerInput`) liefert
`steer`, `sheet_rate`, `gas_up_pressed`, `gas_down_pressed`, `start_pressed`. Das Boot liest nur
diese Felder (`boat.input.steer`). `ai_input.gd` erbt davon und berechnet dieselben Werte aus
Wind, Bahn und Karte. Das ist der Trick: **Mensch, Computer und Netzwerk-Gegner sind
austauschbare Eingabegeräte.**

**Lies dazu:** [Eingabe](../skripte/eingabe.md) und [Computergegner](../skripte/ki.md).

---

## Etappe 11: Motor, Tankstelle, Schlepper

**Ziel:** Gas geben (Anlasser, Verbrauch), tanken am Steg, und ein Schlepper, der
festgefahrene Boote abholt.

**Was zu tun ist:** In `boat.gd` die Motorzustände (`enum Motor { AUS, ANLASSER, LAEUFT }`),
`throttle`, `fuel` und `refuel(delta)`. `fuel_dock.gd` ist ein Baustein mit `berth()`. `tug.gd`
ist eine kleine Zustandsmaschine (`APPROACH → HOOK → TOW → RELEASE → LEAVE`).
`main.gd` ruft Schlepper bei `stuck_time > 4 s` und lässt tanken, wenn ein Boot in
`FuelDock.ZONE` liegt.

**Lies dazu:** [Das Boot](../skripte/boot.md#motor-und-tanken), [Schlepper](../skripte/schlepper.md).

---

## Etappe 12: Menü, Spielzustand, Rennablauf

**Ziel:** Ein Startmenü, in dem man Bahn und Wetter wählt, und ein Rennablauf mit Countdown,
Zieleinlauf und Neustart.

**Was zu tun ist:** `game_state.gd` (`GameState`, `RefCounted` mit `static var`s und
`const`-Listen) speichert die Auswahl. `menu.gd` baut die Oberfläche in `_ready()` aus
Code, `main.gd` liest `GameState` und baut das Rennen auf. Der Zustand läuft durch
`waiting → countdown → racing → finished`.

**Lies dazu:** [Menü und Lobby](../skripte/menue.md) und [Rennablauf](../skripte/rennen.md).

---

## Etappe 13: Gefahren, Tiere, Effekte

**Ziel:** Minenfelder, Polizeikontrollen, Sirenen-Insel, Tiere, Wracks, Explosionen.

**Was zu tun ist:** Neue Bausteine (`restricted_area.gd`, `siren_island.gd`, `sea_life.gd`),
gemeinsame Zeichenhilfen (`hazard_visuals.gd`), Effekte (`fx.gd`). Die Spiellogik hängt an
einer einzigen Schnittstelle, `update_boat(boat, delta)`, die `main.gd` für alle Boote ruft.
Das Boot bekommt `explode()`, `start_hold(kind)` und `collide()`.

**Lies dazu:** [Gefahren, Tiere, Effekte](../skripte/gefahren.md).

---

## Etappe 14: Netzwerk, Klang, Editor-Plugin, Politur

* **Netzwerk:** `net.gd` als Autoload, `lobby.gd`, `net_input.gd`; Boote bekommen
  `net_pack()`/`net_unpack()` ([Netzwerk](../skripte/netzwerk.md)).
* **Klang:** `sfx.gd` und `tools/make_audio.py` ([Klang](../skripte/klang.md)).
* **Editor-Plugin:** `addons/regatta_editor/plugin.gd` mit Seegrund-Pinsel und
  „+ Baustein“ ([Level-Editor-Plugin](../skripte/editor.md)).
* **Politur:** Modelle (`model_style.gd`), Segel-Overlay, `F11`-Vollbild, Tests
  ([Werkzeuge und Tests](../skripte/werkzeuge.md)).

---

## Wie lange dauert das?

Wer Programmiererfahrung mitbringt, schafft die Etappen 1–6 an einem Nachmittag. Die
Etappen 7–12 sind der Hauptteil (Level, HUD, KI, Menü). Netzwerk und Politur sind
optional, das Spiel funktioniert auch ohne.

## Wenn etwas nicht klappt

| Symptom | Ursache und Abhilfe |
|---|---|
| „Identifier "Chart" not declared“ | Klassencache veraltet: Editor neu laden oder `godot --headless --path . --import` |
| „Cannot infer the type of "x" variable“ | Wert ist `Variant`: Typ ausschreiben, `var x: float = d["k"]` |
| Boot bewegt sich nicht | `_physics_process` läuft nur, wenn der Node im Baum hängt und das Skript am richtigen Node ist |
| Alles dreht sich falsch herum | Winkelkonvention prüfen: `heading=0` = nach +z, `sin` für x, `cos` für z |
| Karte ist spiegelverkehrt | Texturzeilen = z, Spalten = x; Reihenfolge `j * RES + i` (z zuerst) |
| `@tool`-Skript spinnt im Editor | Setter laufen schon beim Laden: `is_inside_tree()` prüfen |
