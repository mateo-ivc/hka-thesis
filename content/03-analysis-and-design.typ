#import "../meta.typ": acr-emph, fig-platzhalter-mittel, note, req, tab-d, tab-h
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Analyse und Entwurf
Wie wurde gPTP Implementiert? Ziemlich genau nach den Stateautomaten, die im Standard beschrieben sind.


== Analyse der Anforderungen
Folgende Anforderungen muss die Implementierung erfüllen.
- residenceTimer < 10ms
- pDelay turnarround time < 10 ms
- E2E Synchronization -> < 1$mu$s


Hardware Anforderungen:
- Leistungskriterien -> max offset und Jitter
- Hardware Timestamping

== Testaufbau
- Konkrete Hardware (3× NXP RT1176 als Bridges, 2× STM32H7)
- Topologie: Verkettung der Mikrokontrolelr -> Kleines Diagramm zeigen

== MAC Timestamping
Kernfrage beantwortet: Wieso MAC Timestamping?
- MAC-Timestamping funktioniert out of the box
PHY Timestamping muss konfiguriert werden
- MAC Timestamping hat vorerst keine nennenswerten Nachteile -> ingress/egress Latency ist gering genug.

== Warum zwei Timer ?
Problem mit der aktuellen Hardware:
Es werden 2 free running Clocks verwendet. D.h. beide Ports haben eine unterschiedliche Zeitbasis.

Da im gPTP-Stack nur der Timer vom Slave Port Synchronisiert wird, kann der Master Port die nachfolgende Systeme nicht Synchronisieren. \
Daher muss eine eigene Lösug her, die den zweiten Timer zum ersten Synchronisiert.

Implementierung in 4.


== Messmethodik
Wie überprüft man die Synchronisierung?
Z.b. über Hardware Trigger am Mikrocontroller, die das PPS Signal der Master und Slave Clock auf ein GPIO Pin legen.

Ingress/Egress Timestamps

Wie werden die Daten analysiert?
Oszi aufnahmen -> Rohdaten werden aufgenommen, in ein Skript geworfen und können anschließend analysiert werden.

Welche Daten werden analysiert?
- Residence Timer,
- pDelay
- PPS Offset

Was kann man daraus erkennen?
- Jitter und Wander-Offset
- ob die Anfoderungen erfüllt werden

