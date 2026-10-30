# Spec Delta

## ADDED Requirements

### Requirement: Download-Seite mit aktuellen Binaries
Die Dokumentation SHALL eine Seite „Download“ enthalten, die die Linux- und Windows-Builds des aktuellen Stands direkt zum Herunterladen anbietet und Version (Commit), Build-Datum, Dateigröße und SHA-256-Prüfsumme anzeigt. Die Seite SHALL automatisch mit jedem Build aktualisiert werden.

#### Scenario: Aktuelle Version
- **WHEN** ein Leser die Seite „Download“ öffnet
- **THEN** findet er Download-Links für Windows und Linux, die Version, das Datum und die Prüfsummen des neuesten Builds

#### Scenario: Noch kein Build
- **WHEN** noch kein Build veröffentlicht wurde
- **THEN** weist die Seite darauf hin, dass es noch keinen Download gibt

### Requirement: Installationsanleitung
Die Seite „Download“ SHALL eine Installationsanleitung für Windows und Linux enthalten: Voraussetzungen (Grafikkarte/Treiber mit Vulkan), Herunterladen und Entpacken, Starten, die Windows-SmartScreen-Warnung, das Ausführrecht unter Linux, Hinweise zum Controller und zum Netzwerkspiel (Port, Firewall), Prüfen der Prüfsumme, Fehlerbehebung und Deinstallation.

#### Scenario: Erstinstallation unter Windows
- **WHEN** ein Leser der Anleitung für Windows folgt
- **THEN** kann er das Spiel ohne weitere Vorkenntnisse entpacken, starten und die SmartScreen-Warnung einordnen

#### Scenario: Erstinstallation unter Linux
- **WHEN** ein Leser der Anleitung für Linux folgt
- **THEN** kann er die Datei entpacken, ausführbar machen, starten und bei Grafikproblemen den Kompatibilitätsmodus nutzen
