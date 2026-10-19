# Glossar

## Segeln

| Begriff | Bedeutung |
|---|---|
| **Luv / Lee** | Seite, aus der der Wind kommt / Seite, die vom Wind abgewandt ist |
| **Am Wind** | möglichst steil gegen den Wind (etwa 45°) |
| **Halber Wind** | Wind von der Seite (90°): am schnellsten |
| **Raumer Wind, Vorwind** | Wind schräg von hinten, genau von hinten |
| **Kreuzen** | im Zickzack gegen den Wind aufwärts segeln |
| **Wende** | Kurswechsel **durch** den Wind (Bug geht durch den Wind) |
| **Halse** | Kurswechsel mit dem Heck durch den Wind |
| **Im Wind stehen** („in irons“) | Bug zeigt in die Sperrzone, das Boot hat keinen Vortrieb |
| **Schot** | Leine, die das Segel dicht holt oder fiert (lockert) |
| **Fieren** | Schot lockern |
| **Killen / Flattern** | Segel schlägt, weil die Schot zu lose ist |
| **Trimmen** | Segel richtig einstellen |
| **Krängung** | Schräglage des Bootes |
| **Groß, Fock** | Großsegel am Mast, Vorsegel |
| **Baum** | Holm, der das Großsegel unten hält |
| **Pinne** | Hebel zum Ruder |
| **Schwert / Kiel** | verhindert das seitliche Abtreiben |
| **Abdrift** | seitliches Rutschen nach Lee |
| **Scheinbarer / wahrer Wind** | Wind, den das fahrende Boot spürt / Wind über Grund |
| **Böe, Dreher** | kurzzeitig stärkerer Wind / langsame Richtungsänderung |
| **Windschatten** | Bereich im Lee eines Hindernisses mit weniger Wind |
| **VMG** | Velocity Made Good: Geschwindigkeit **in Richtung Ziel** |
| **Layline** | Linie, ab der man die Tonne ohne weitere Wende erreicht |
| **Bb / Stb** | Backbord (links) / Steuerbord (rechts) |
| **Kn** | Knoten = Seemeilen pro Stunde; 1 kn = 0,514 m/s; 1 m/s = 1,944 kn |
| **sm** | Seemeile = 1852 m |

## Seekarte

| Begriff | Bedeutung |
|---|---|
| **Lotung** | Tiefenzahl auf der Karte |
| **Tiefenlinie** | Linie gleicher Tiefe (2, 5, 10, 20 m) |
| **Untiefe** | flache Stelle |
| **Kardinaltonne** | Tonne, die anzeigt, wo das tiefe Wasser liegt (N, O, S, W) |
| **Einzelgefahr** | Tonne direkt auf einer Gefahrenstelle |
| **Lateraltonne** | rot (Backbord) und grün (Steuerbord) begrenzen ein Fahrwasser |
| **IALA A** | Betonnungssystem in Europa |
| **Molenfeuer** | Licht am Kopf einer Mole |
| **Kennung** | Blinkcode eines Feuers, z. B. „Fl(3)WR.15s“ |
| **Regattagebiet** | durch eine magenta Linie begrenzter Bereich |

## Godot

| Begriff | Bedeutung |
|---|---|
| **Node** | Baustein im Szenenbaum |
| **Szene** | gespeicherter Teilbaum aus Nodes (`.tscn`) |
| **Skript** | `.gd`-Datei, die das Verhalten eines Nodes bestimmt |
| **`class_name`** | registriert eine Klasse global unter einem Namen |
| **`extends`** | gibt den Node-Typ an, von dem das Skript erbt |
| **Autoload** | Node, der immer da ist, über Szenenwechsel hinweg |
| **Signal** | Ereignis, auf das andere lauschen können |
| **`@export`** | macht eine Variable im Inspector editierbar und speichert sie in der Szene |
| **`@tool`** | Skript läuft auch im Editor |
| **Inspector** | Eigenschaftsfenster rechts im Editor |
| **Mesh, `MeshInstance3D`** | 3D-Form, bzw. ein Node, der sie zeigt |
| **`SurfaceTool`** | baut ein Mesh aus Dreiecken im Code |
| **`MultiMesh`** | viele Instanzen desselben Meshes mit einem Zeichenaufruf |
| **Shader** | Programm für die Grafikkarte |
| **Viewport, `SubViewport`** | eigene Bildfläche mit eigener Kamera |
| **`Tween`** | animiert eine Eigenschaft über die Zeit |
| **`delta`** | Zeit seit dem letzten Schritt in Sekunden |
| **`lerp`, `lerpf`** | linear zwischen zwei Werten mischen |
| **`smoothstep`** | weicher Übergang von 0 nach 1 zwischen zwei Grenzen |
| **`wrapf`** | Wert in einen Bereich „umklappen“ (für Winkel) |
| **RPC** | Remote Procedure Call: Funktionsaufruf auf einem anderen Rechner |
| **ENet** | UDP-Netzwerkbibliothek, in Godot enthalten |
| **Headless** | Godot ohne Fenster, für Tests |
| **A\*** | Wegsuchalgorithmus, in Godot als `AStarGrid2D` |
| **Duck Typing** | „hat die Methode, also benutzen wir sie“ statt Typprüfung |

## Projektbegriffe

| Begriff | Bedeutung |
|---|---|
| **Baustein** | Level-Node mit eigenem Skript (Tonne, Insel, …) |
| **Tiefenraster** | 448×448-Zahlenfeld, das die Karte und die Spiellogik trägt |
| **Slot** | ein Boot der Runde (Mensch, Computer, fremder Spieler) |
| **Puppet** | Boot oder Schlepper auf einem Client, das nur anzeigt |
| **Schnappschuss** | Zustandspaket vom Host an die Clients |
| **Hold** | Haltezustand (Polizei, Sirenen) |
| **Out** | ausgeschieden (Seemine) |
