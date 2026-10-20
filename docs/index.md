# Regatta – Dokumentation

**Regatta** ist ein Segel-Rennspiel auf der Seekarte für bis zu vier Skipper an einem Bildschirm,
im LAN oder übers Internet. Es ist mit der **Godot Engine 4** und **GDScript** gebaut – ohne
externe Plugins, ohne fertige Assets außer zwei 3D-Modellen und selbst erzeugten Klängen.

![Rennen auf der Flussregatta](bilder/rennen.png)

Diese Dokumentation hat zwei Ziele:

1. **Spielen:** Wie steuert man, wie segelt man schnell, was bedeuten Seekarte, Tonnen,
   Minenfelder und Sirenen?
2. **Nachbauen:** Wie ist das Spiel aufgebaut, was macht **jedes einzelne Skript**, und wie
   greifen die Teile ineinander? Das Ziel ist, dass jemand, der noch nie mit Godot gearbeitet
   hat, dieses Projekt **allein ohne KI-Hilfe nachbauen** kann.

## Wo fange ich an?

| Ich möchte … | Dann lese ich … |
|---|---|
| das Spiel einfach spielen | [Spielanleitung](spielen/anleitung.md) |
| wissen, welche Bahnen es gibt | [Die Bahnen](spielen/bahnen.md) |
| Godot-Neuling sein und das Projekt verstehen | [Godot-Grundlagen](nachbauen/grundlagen.md), danach [Architektur im Überblick](nachbauen/architektur.md) |
| das Spiel Schritt für Schritt selbst bauen | [Fahrplan zum Nachbau](nachbauen/fahrplan.md) |
| wissen, was ein bestimmtes Skript tut | [Alle Skripte im Überblick](skripte/index.md) |
| eine eigene Bahn bauen | [Eigene Bahnen bauen](referenz/bahnen-bauen.md) |
| einen Begriff nachschlagen (Luv, Lee, `@export` …) | [Glossar](referenz/glossar.md) |

## Das Spiel in einem Absatz

Man steuert eine Segeljolle von oben auf einer Seekarte, die aussieht wie eine gedruckte
Papierkarte: Tiefenlinien, Lotungen, Seezeichen nach IALA A. Die **Karte ist zugleich die
Spiellogik**: Wo die Karte flacher ist als der Tiefgang, läuft man auf Grund. Der Wind weht
mit Böen und Drehern, Strömungen versetzen das Boot, Inseln und andere Boote werfen
Windschatten. Gesegelt wird mit nur zwei Reglern, der Pinne (lenken) und der Schot (Segel
dichter oder offener). Zusätzlich gibt es einen Außenborder mit begrenztem Tank, Tankstellen,
einen Schlepper für Festgefahrene, Computergegner in drei Stärken, Minenfelder, Polizeikontrollen,
eine Sirenen-Insel und dekorative Tiere.

## Technische Eckdaten

| | |
|---|---|
| Engine | Godot 4.7.2 (ältere 4.x ab 4.3 laufen meist auch) |
| Sprache | GDScript, rund 10 000 Zeilen in etwa 45 Skripten |
| Render-Modus | Forward Plus, Seekarte per Shader, Modelle mit Tusche-Kontur |
| Physik | eigene 2D-Segelphysik in der Wasserebene, **keine** Godot-Physik-Engine |
| Netzwerk | ENet über Godots High-Level-Multiplayer, Host-autoritativ |
| Audio | per Python-Skript synthetisierte OGG-Dateien |
| Level | normale Godot-Szenen mit eigenen Node-Typen und Editor-Plugin |

!!! tip "Warum keine Physik-Engine?"
    Ein Segelboot lässt sich in der Wasserebene mit wenigen Formeln glaubwürdig simulieren.
    Das ist leichter zu verstehen, zu testen (siehe [Werkzeuge und Tests](skripte/werkzeuge.md))
    und im Netzwerk zu synchronisieren als Starrkörper. Das Kapitel [Das Boot](skripte/boot.md)
    erklärt jede Formel.

## Konventionen in dieser Dokumentation

* Dateipfade stehen in `Schreibmaschinenschrift`, z. B. `scripts/boat.gd`.
* Ein Pfeil wie **→ [Das Boot](skripte/boot.md)** ist ein Querverweis.
* Kästen mit **Merke** fassen Konzepte zusammen, die man später wieder braucht.
* Code-Ausschnitte sind aus dem echten Projekt (gekürzt) oder als **Beispiel** gekennzeichnet.
* Koordinaten: Das Spiel läuft in der Wasserebene mit `x` und `z`. **Norden ist −z**, Osten
  ist +x. Ein Boot mit `heading = 0` zeigt nach +z (Süden). Details im Kapitel
  [Godot-Grundlagen](nachbauen/grundlagen.md#10-koordinaten-und-winkel-in-diesem-projekt).
