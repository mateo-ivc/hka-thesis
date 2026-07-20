#import "../meta.typ": acr-emph, fig-platzhalter-mittel, note, req, tab-d, tab-h
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Analyse und Entwurf
Wie wurde gPTP Implementiert? Ziemlich genau nach den Stateautomaten, die im Standard beschrieben sind.


== Anforderungen

=== Zeitliche Anforderungen
Annex B des Standards definiert eine reihe an Leistungsanforderungen, an denen sich eine konforme Implementierung messen lasssen muss. Die für diese Arbeit relevanten Grenzwerrte sind in der folgende Tabelle zusammengefasst:

#figure(
  table(
    columns: (1.5fr, 1fr, 1fr),
    align: (left, left, left),
    stroke: none,
    table.hline(),
    tab-h[Anforderung], tab-h[Beschreibung], tab-h[Grenzwert],
    table.hline(stroke: 0.5pt),
    tab-h[Residence Time], tab-h[], tab-h[$<= 10m s$],
    tab-h[pDelay Turnaround Time ], tab-h[], tab-h[$<= 10m s$],
    tab-h[E2E-Synchronisationsgenauigkeit], tab-h[], tab-h[$<=1mu s$],
    tab-h[Granularität der LocalCLock], tab-h[], tab-h[$<=40m s$],
    tab-h[meanLinkDelayThresh], tab-h[], tab-h[$"   "800n s$],
    table.hline(),
  ),
  caption: [gPTP Leistungsanforderungen nach Annex B],
)

Die Residence Timer bezeichnet die maximale Zeit, die eine Sync-Nachircht innerhalb einer Time-Aware Bridge vom Eingang bis Ausgang benötigt. Die pDelay Turnaround Time beschreibt wie lange ein System zum Verabeiten der pDelay_Resp-Nachricht brauchen darf. Beide Werte begrenzen wie schnell eine Bridge die zugehörige Berechnung durchführen muss.

Die E2E-Synchronisationsgenauigkeit gilt laut Annex B.3 kumulativ über die gesamte Kette - vorrausgesetzt die Kette ist nicht größer als sieben Hops - und erfordert, dass alle Geräte zu einem gewissen Grad Synchronisiert sind.

Die Granularität der LocalClock beschreibt die minimal Auflösung mit der die lokale Clock die Zeit erfassen muss, und ist damit Vorraussetzung für die anderen drei Anforderungen: Eine gröbere Granularität würde bereits zu Messungenauigkeiten bei der residence Time und pDelay Messung führen.

Der meanLinkDelayThresh unterscheidet sich in der Art von den übrigen Anforderungen: Es handelt sich nicht um eine Genauigkeits- oder Timing-Anforderung an die Implementierung, sondern um einen Schwellenwert, gegen den die gemessene mittlere Link Delay (meanLinkDelay) verglichen wird. Überschreitet die gemessene Link Delay diesen Wert, geht der Standard davon aus, dass im Link Equipment ohne gPTP-Unterstützung vorhanden ist. Für 100BASE-TX- und 1000BASE-T-Verbindungen (Kupfer) beträgt der Schwellenwert 800 ns;

=== Hardwareanfoderunge

Neben den normativen Zeitanforderungen ergeben sich aus dem gewählten Testaufbau weitere Anforderungen an die eingesetzte Hardware:

- Hardware-Timestamping: Zeitstempel für ein- und ausgehende gPTP-Nachrichten müssen auf MAC-Ebene erzeugt werden (Begründung folgt in Abschnitt "MAC Timestamping").
- Mindestens zwei Ports: Jede Time-Aware Bridge muss Nachrichten an einem Port empfangen und über einen weiteren weiterleiten können.
- Clock-Qualität: Offset und Jitter der Oszillatoren müssen die Einhaltung von NFR-3 über die gesamte Messdauer zulassen.


== Testaufbau
- Konkrete Hardware (3× NXP RT1176 als Bridges, 2× STM32H7)
- Topologie: Verkettung der Mikrokontrolelr -> Kleines Diagramm zeigen
- freerunning Grandmaster clock -> Wieso freerunning,
- In welcher frequenz werden Sync und pDelay Nachirchten gesendet?
- Wieso kein BMCA -> Um maximale anzahl an Hops zu gewährleisten.
chronisierung (keine Syntonisierung)


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

*Wichtig:* Annex B.2.4
1. Zeistemepelauflösung = 25MHz (40ns)
2. PI Regler um Messrauschen der Timestamps auszugleichen

0,1ppm nachweisen:
1. Enschwingzeit abwarten
2. rateRatio loggen
3. Abweichung prüfen -> Standardabweichung berechnen
  - Mittelwert berechnen
  - Wahrscheinlichkeit einzelner Werte berechnen
  - Werte in Formel einsetzen $sigma = sqrt("VAR") = sqrt((sum_(i=1)^n) (x_i - mu)^2 dot p_i)$


Implementierung in Kapitel 4.


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
