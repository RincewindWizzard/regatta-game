# doku Specification

## Purpose
Anforderungen der Capability `doku` des Segelspiels Regatta (aus archivierten Changes).

## Requirements

### Requirement: Doku
Das Projekt SHALL eine MkDocs-Dokumentation enthalten, die strikt (`--strict`) baut und auf GitHub Pages veröffentlicht wird.

#### Scenario: Push auf main
- **WHEN** auf `main` gepusht wird
- **THEN** wird die Seite veröffentlicht

### Requirement: Download-Seite mit aktuellen Binaries
Die Dokumentation SHALL eine Seite „Download“ enthalten, die für Windows, Linux und macOS getrennt nach „Stabil“ (neuester Versions-Tag) und „Snapshot“ (neuester Stand von `main`) die Binaries direkt zum Herunterladen anbietet und je Version (Commit oder Tag), Build-Datum, Dateigröße und SHA-256-Prüfsumme anzeigt. Die Seite SHALL automatisch mit jedem Build aktualisiert werden.

#### Scenario: Aktuelle Version
- **WHEN** ein Leser die Seite „Download“ öffnet
- **THEN** findet er Download-Links für Windows, Linux und macOS mit Version, Datum und Prüfsummen für den neuesten Snapshot und das neueste stabile Release

#### Scenario: Noch kein Build
- **WHEN** noch kein Snapshot oder noch kein stabiles Release existiert
- **THEN** weist die Seite im jeweiligen Bereich darauf hin, dass es noch keinen Download gibt

### Requirement: Installationsanleitung
Die Seite „Download“ SHALL eine Installationsanleitung für Windows, Linux und macOS enthalten: Voraussetzungen (Grafikkarte/Treiber mit Vulkan bzw. Metal), Herunterladen und Entpacken, Starten, die Windows-SmartScreen-Warnung, das Ausführrecht unter Linux, das Entfernen der Quarantäne und lokale Signieren unter macOS, Hinweise zum Controller und zum Netzwerkspiel (Port, Firewall), Prüfen der Prüfsumme, Fehlerbehebung und Deinstallation.

#### Scenario: Erstinstallation unter Windows
- **WHEN** ein Leser der Anleitung für Windows folgt
- **THEN** kann er das Spiel ohne weitere Vorkenntnisse entpacken, starten und die SmartScreen-Warnung einordnen

#### Scenario: Erstinstallation unter Linux
- **WHEN** ein Leser der Anleitung für Linux folgt
- **THEN** kann er die Datei entpacken, ausführbar machen, starten und bei Grafikproblemen den Kompatibilitätsmodus nutzen

#### Scenario: Erstinstallation unter macOS
- **WHEN** ein Leser der Anleitung für macOS folgt
- **THEN** kann er die App entpacken, die Quarantäne entfernen, sie lokal signieren und starten
