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
- Clock-Qualität: Offset und Jitter der Oszillatoren müssen die Einhaltung von E2E-Synchronisationsgenauigkeit über die gesamte Messdauer zulassen.


== Testaufbau
Für den Nachfolgenden Testaufbau werden drei Phyboard Atlas als Bridge verwendet. Diese verfügen jeweils über zwei Ports, wovon einer von einem 1Gbit/s PHY mit SFD-Erkennung gesteuert wird und der andere von einem 100/10Mbit/s PHY ohne SFD-Erkennung.
//(Muss ich hier erklären, wieso diese Hardware verwendet wird?)

Des weiteren sollen zwei STM32H7 verwendet werden, um zum einem als Grandmaster Clock und zum anderen als Endpoint. Dadurch lässt sich ein Testaufbau mit maximal 4 Hops gestalten. Dies erzwingt allerdings das abschalten des BMCA um den einzelnen System ihre feste Rolle zu geben.

Da in dieser Arbeit nur die Bridgefunktion validiert werden soll, ist es nicht nötig die Grandmaster Clock zu einer externen Zeitquelle zu synchronisieren. Daher wird diese Clock im freerunning-mode betrieben.

pDelay und Sync-Nachrichten werden nach den Standard werten auf jeweils 1Hz für pDelay und 8Hz für Sync gesendet.

== Timestamping
//https://www.ti.com/lit/wp/snla465/snla465.pdf?ts=1784483809731
//https://www.ti.com/lit/ds/symlink/dp83867e.pdf?ts=1784535520366&ref_url=https%253A%252F%252Fwww.ti.com%252Fproduct%252FDP83867E
// https://ww1.microchip.com/downloads/aemDocuments/documents/UNG/ProductDocuments/DataSheets/KSZ8081RNA-RND-10BASE-T-100-BASE-TX-PHY-with-RMII-Support-DS00002199F.pdf

Wie bereits im Grundlagen Kapitel besprochen, kann man Timestamps direkt über die Hardware, als auch einen Layer später über den MAC erfassen. \
Für diesen Versuch ist die verwendung von der MAC-Timestamping erzwingend, da beide PHYs der Bridge nicht über die Fähigkeit des direkten PHY Timestamping verfügen.\
Desweiteren besitzt der 1Gbit/s PHY über eine SFD erkennung, was bedeutet, dass der PHY einen SFD-Pulse an den MAC sendet, wenn immer ein Start-Of-Frame-Delimiter erkannt wird. Bei dem 10/100Mbit/s PHY ist dies leider nicht der Fall, weshalb es bei Messungen zu ungenaueren Timestamp oder erhöhtem Jitter kommen kann.



== Interne Bridge Synchronisierung

Ein Problem gibt es mit der aktuellen Hardware. Da die Hardware über einen eigenen MAC für jede Ethernet Schnittstelle verfügt, ist die relative Zeit von MAC zu MAC immer Unterschiedlich.
Im gPTP Stack wird allerdings immmer nur der Timer zum zugehörigen Port Synchronisiert. Dies führt dazu, dass der Master Port auf der Bridge nicht Synchronisiert ist und dadruch die Nachfolgenden Systeme nicht korrekt Synchronisieren kann.

Um dieses Problem zu lösen, wird ein extra Task in ZephyrRTOS erstellt, der sich um das Synchronisieren des Master-Ports zum Slave-Port auf der Bridge kümmert.

Damit eine korrekte Synchronisierung gewährleistet werden kann müssen allerdings einige Anforderungen erfüllt werden, die in Annex B des Standards beschrieben werden.:

1. Für korrekte und genaue Messungen der Zeitstempel braucht es eine Auflösung von Mindestens $25"MHz"$. Das bedeutet, zwischen jedem Tick den der Timer macht, dürfen maxmimal $40"ns"$ vergehen.

2. Zeitstempel durch Messrauschen verfälscht werden können, darf die Rate-Korrektur zwischen Master und Slave nicht direkt aus einzelnen Timestamp-Differenzen abgeleitet werden, da dies zu einer Instabilen Regelung führen würde. Um dies zu verhindern, wird ein PI-Regler eingesetzt, der die Messewerte über meherere Sync-Intervalle glättet und daraus ein robustes rateRatio berechnet.

Neben diesen beiden Anforderungen fordert Annex B.2.4 außerderm den Nachweis, dass die interne Synchronisierung zwischen Master und Slave eine Genauigkeit von 0,1ppm erreicht. Um dies nachzuweisen, wir wie folgt vorgegangen:

1. Einschwingzeit abwarten, damit sich der PI-Regelr auf einen stabilen Zustand einschwingen kann.

2. rateRatio zwischen Master und Slave über einen definierten Zeitraums messen und loggen.

3. Aus den Messungen wird die Abweichung von der geforderten Genauigkeit geprüft, indem die Standardabweichung des Messreihe berechnet wird. Dazu wird zunächst der Mittelwert $mu$ des Messreihe bestimmt, anschließend die Wahrscheinlichkeit $p_i$ der einzelnen Werte, und die Ergebnisse abschließend in folgende Formel eingesetzt:

  $sigma = sqrt("VAR") = sqrt((sum_(i=1)^n) (x_i - mu)^2 dot p_i)$

Liegt die berechnete Standardabweichung $sigma$ innerhalb der geforderten 0,1ppm, gilt die Anforderung an die interne Synchronisierung als erfüllt.


== Messmethodik
Um die tatsächlich errichte Synchronisierungsegenauigkeit des Testaufbaus zu überprüfen reicht eine rein software-setige Betrachtung der berechneten Offsets nicht aus, da diese bereits durch den Synchronisierungsalgorithmus korrigiert werden. Stattdessen wird die Synchronisierung über einen unabhängigen Hardware-Trigger am jeweiligen Mikrokontroller nachgewiese: Sowohl die Master- als auch die Slave-Clock legen ein PPS-Signal (Pulse-Per-Second) auf einen GPIO-Pin, welches direkt aus dem internen Timer der jeweiligen Clock abgeleitet wird und damit unabhängig von gPTP-Stack ist. Die zeitliche Differenz zwischen den beiden PPS-Flanken entspricht dem tatsächlichen Offset zwischen Master und Slave und lässt sich extern messen.

Für die Erfassung der PPS-Signale wird ein Oszilloskop verwendet: Die PPS-Flanken von Master und Slave werden gleichzeitig aufgenommen und als Rohdaten exportiert. Ein Auswertungsskript berechnet anschließend die zeitliche Differenz zwischen den Signalen und bestimmt daraus den PPS-Offset über die gesamte Messdauer.

Konkret werden folgendet Daten für die spätere Auswertung geloggt:
- Residence Time
- pDelay -> timestamps der einzelnen Nachrichten ($t_1$ bis $t_4$)
- PPS-Offset
- rateRatio
-


// == Ungenauigkeiten
// //https://www.irit.fr/~Katia.Jaffres/Fichiers/2021ETR.pdf
// Wo können unginauigkeiten aufkommen bezüglich des timestampens, pDelay & residence Time berechnungen und dem Synchronisieren?

// - Z.B. mit STM32 hat man einen zu hohen pDelay
// - Clock Qualität (temparatur)
// - 100 MBit/s eth phy vs 1GBit/s eth phy
