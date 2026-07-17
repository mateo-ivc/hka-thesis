#import "../meta.typ": acr-emph, asm-listing, c-listing, fig-platzhalter-mittel, note
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Implementierung

== Umsetzung der Timer Synchronisierung
Timer werden über einen eigenen Task Synchronisiert.\
Zwei Interrupts:
- wenn pps signal gesendet wird -> Hardware Timestamp speichern.
- wenn das pps signal wieder eingelesen wird. -> Hardware timestamp speichern

Dadurch lässt sich die rateRatio berechnen (offset in beiden Timestamps) und durch einen einfachen PI-Regler Synchronisieren.
== Probleme im gPTP-Subsystem
Bugs hier auflisten und zeigen wie sie behoben wurden
== Boardspezifische Konfigurationen
- PTP-Clock musste richtig konfiguriert werden
- PTP-Timer können nicht dynamisch (devicetree) gesetzt werden
- Interrupts mussten richtig konfiguriert werden
