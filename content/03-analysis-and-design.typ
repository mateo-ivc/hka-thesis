#import "../meta.typ": acr-emph, fig-platzhalter-mittel, note, req, tab-d, tab-h
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Analyse und Entwurf
Wie wurde gPTP Implementiert? Ziemlich genau nach den Stateautomaten, die im Standard beschrieben sind.


== Anforderungen
Folgende Anforderungen muss die Implementierung erfüllen.
- residenceTimer < 10ms
- pDelay turnarround time < 10 ms
- pDelay < 800ns (nochmal im Standard nachschauen)
- E2E Synchronization -> < 1$mu$s (gilt kumulativ)


Hardware Anforderungen:
- Leistungskriterien -> max offset und Jitter (Clock)
- Hardware Timestamping


== Testaufbau
- Konkrete Hardware (3× NXP RT1176 als Bridges, 2× STM32H7)
- Topologie: Verkettung der Mikrokontrolelr -> Kleines Diagramm zeigen
- freerunning Grandmaster clock -> Wieso freerunning,
- In welcher frequenz werden Sync und pDelay Nachirchten gesendet?
- Wieso kein BMCA -> Um maximale anzahl an Hops zu gewährleisten.

*Tests*:
//https://www2.informatik.uni-stuttgart.de/bibliothek/ftp/ncstrl.ustuttgart_fi/TR-2021-02/TR-2021-02.pdf
- Testaufbau wo die Clock mehrere Stunden läuft -> Um eine Langzeitstabilität analysieren zukönnen.
- Simulierte Systemlast -> Um zu zeigen, dass die Synchronisierung auch unter Last funktioniert.

- Simulierte Netzwerklast -> Um zu zeigen, dass die Synchronisierung auch unter Netzwerklast funktioniert.

- Auseinanderlaufen von Clocks zeigen durch Zeitsynchronisierung (keine Syntonisierung)


== MAC Timestamping
//https://www.ti.com/lit/wp/snla465/snla465.pdf?ts=1784483809731
Kernfrage beantwortet: Wieso MAC Timestamping verwendet wird.
- MAC-Timestamping funktioniert out of the box
PHY Timestamping ist komplexer zu konfigurieren
- MAC Timestamping hat vorerst keine nennenswerten Nachteile -> ingress/egress Latency ist gering genug. Und kann softwareseitig rausgerechnet werden.

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
- Residence Timer -> logs
- pDelay -> logs
- PPS Offset -> logs

Wie kann man das Statistisch analysieren

Was kann man daraus erkennen?
- Jitter und Wander-Offset
- ob die Anfoderungen erfüllt werden

== Ungenauigkeiten
//https://www.irit.fr/~Katia.Jaffres/Fichiers/2021ETR.pdf
Wo können unginauigkeiten aufkommen bezüglich des timestampens, pDelay & residence Time berechnungen und dem Synchronisieren?

- Z.B. mit STM32 hat man einen zu hohen pDelay
- Clock Qualität (temparatur)
- 100 MBit/s eth phy vs 1GBit/s eth phy
