# Mehrspieler (LAN / Internet)

Bis zu **4 Boote**, an jedem Rechner 1 oder 2 Skipper. Alle brauchen **dieselbe
Spielversion**. Wie das im Code funktioniert, erklärt [Netzwerk](../skripte/netzwerk.md).

1. Im Menü auf **„Mehrspieler (LAN / Internet)“**, Namen eintragen und wählen, wie viele
   Skipper an diesem Rechner segeln.
2. Einer klickt **„Spiel eröffnen“** und ist damit Host.
3. Die anderen treten bei:
    * **Im selben Netzwerk** erscheint das Spiel unter „Offene Spiele im Netzwerk“. Einfach
      anklicken.
    * **Übers Internet** ist ein virtuelles Netzwerk am einfachsten, zum Beispiel
      [ZeroTier](https://www.zerotier.com) oder [Tailscale](https://tailscale.com). Alle
      treten demselben Netz bei, dann klappt es wie im LAN. Bei Tailscale trägt man die
      100.x.x.x-Adresse des Hosts unter „Direkt verbinden“ ein.
    * Alternativ gibt der Host im Router **UDP-Port 24850** frei und schickt seine öffentliche
      IP. Das geht nicht bei Anschlüssen ohne eigene IPv4-Adresse (DS-Lite).
4. Der Host wählt Bahn, Wetter, Treibstoff und Computergegner und klickt **„Rennen starten“**.

Nach dem Zieleinlauf startet der Host das nächste Rennen. Mit `Esc` geht es zurück in die
Lobby.

!!! note "Gleiche Bahnen"
    Der Host schickt nur den Pfad der Bahn (`res://levels/…`). Die Szene muss bei jedem
    Mitspieler vorhanden sein, sonst meldet das Spiel „Diese Bahn fehlt auf deinem Rechner“.
