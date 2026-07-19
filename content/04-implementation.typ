#import "../meta.typ": acr-emph, asm-listing, c-listing, fig-platzhalter-mittel, note
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Implementierung

== Interne Timer Synchronisierung
"Umsetzung der Timer Synchronisierung"

Konzept steht (2 Interrupts, Offset → rateRatio, PI-Regler) — noch fehlt:
Regelkreis-Frequenz (wie oft wird synchronisiert?)
PI-Parameter (Kp/Ki) und wie sie bestimmt wurden
Rückbezug zur Anforderung residenceTimer < 10 aus Kap. 3 — wie wirkt sich die Genauigkeit dieser internen Sync auf die residence time aus?
Ablaufdiagramm wäre hier sehr hilfreich (2 Interrupts + interne PPS-Erzeugung ist ohne Grafik schwer nachvollziehbar)


Dadurch lässt sich die rateRatio berechnen (offset in beiden Timestamps) und durch einen einfachen PI-Regler Synchronisieren.
== Probleme im gPTP-Subsystem
Bugs hier auflisten und zeigen wie sie behoben wurden
== Boardspezifische Konfigurationen
- PTP-Clock musste richtig konfiguriert werden
- PTP-Timer können nicht dynamisch (devicetree) gesetzt werden
- Interrupts mussten richtig konfiguriert werden

