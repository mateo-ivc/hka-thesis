#import "../meta.typ": acr-emph, fig-platzhalter-mittel, note, req, tab-d, tab-h
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Analyse und Entwurf
Wie wurde gPTP Implementiert? Ziemlich genau nach den Stateautomaten, die im Standard beschrieben sind.


== Anforderungen

=== Zeitliche Anforderungen
Annex B des Standards definiert eine reihe an Leistungsanforderungen, an denen sich eine konforme Implementierung messen lasssen muss. Die für diese Arbeit relevanten Grenzwerrte sind in der folgende Tabelle zusammengefasst:

#figure(
  table(
    columns: (1.5fr, 0.5fr, 1fr),
    align: (left, left, left),
    stroke: none,
    table.hline(),
    tab-h[Anforderung], tab-h[Beschreibung], tab-h[Grenzwert],
    table.hline(stroke: 0.5pt),
    tab-h[Residence Time @ieee8021as2025[B.2.2]], tab-h[], tab-h[$<= 10m s$],
    tab-h[pDelay Turnaround Time @ieee8021as2025[B.2.3]], tab-h[], tab-h[$<= 10m s$],
    tab-h[E2E-Synchronisationsgenauigkeit @ieee8021as2025[B.3]], tab-h[], tab-h[$<=1mu s$],
    tab-h[Granularität der LocalCLock @ieee8021as2025[B.1.2]], tab-h[], tab-h[$<=40n s$],
    tab-h[meanLinkDelayThresh @ieee8021as2025[11.2.2]], tab-h[], tab-h[$"   "800n s$],
    table.hline(),
  ),
  caption: [gPTP Leistungsanforderungen nach Annex B],
)

Die Residence Timer bezeichnet die maximale Zeit, die eine Sync-Nachricht innerhalb einer Time-Aware Bridge vom Eingang bis Ausgang benötigt. Die pDelay Turnaround Time beschreibt wie lange ein System zum Verabeiten der pDelay_Resp-Nachricht brauchen darf. Beide Werte begrenzen wie schnell eine Bridge die zugehörige Berechnung durchführen muss.

Die E2E-Synchronisationsgenauigkeit gilt laut @ieee8021as2025[B.3] kumulativ über die gesamte Kette - vorrausgesetzt die Kette ist nicht größer als sieben Hops - und erfordert, dass alle Geräte zu einem gewissen Grad Synchronisiert sind.

Die Granularität der LocalClock beschreibt die minimal Auflösung mit der die lokale Clock die Zeit erfassen muss, und ist damit Vorraussetzung für die anderen drei Anforderungen: Eine gröbere Granularität würde bereits zu Messungenauigkeiten bei der residence Time und pDelay Messung führen.

Der meanLinkDelayThresh unterscheidet sich in der Art von den übrigen Anforderungen: Es handelt sich nicht um eine Genauigkeits- oder Timing-Anforderung an die Implementierung, sondern um einen Schwellenwert, gegen den die gemessene mittlere Link Delay (meanLinkDelay) verglichen wird. Überschreitet die gemessene Link Delay diesen Wert, geht der Standard davon aus, dass im Link Equipment ohne gPTP-Unterstützung vorhanden ist. Für 100BASE-TX- und 1000BASE-T-Verbindungen (Kupfer) beträgt der Schwellenwert 800 ns;

=== Hardwareanfoderunge

Neben den normativen Zeitanforderungen ergeben sich aus dem gewählten Testaufbau weitere Anforderungen an die eingesetzte Hardware:

- Hardware-Timestamping: Zeitstempel für ein- und ausgehende gPTP-Nachrichten müssen auf MAC-Ebene erzeugt werden (Begründung folgt in Abschnitt "MAC Timestamping").
- Mindestens zwei Ports: Jede Time-Aware Bridge muss Nachrichten an einem Port empfangen und über einen weiteren weiterleiten können.
- Clock-Qualität: Offset und Jitter der Oszillatoren müssen die Einhaltung von E2E-Synchronisationsgenauigkeit über die gesamte Messdauer zulassen.


== Testaufbau
Für den nachfolgenden Testaufbau werden drei phyBOARD-Atlas-Boards als Bridge eingesetzt. Diese verfügen jeweils über zwei Ports, deren Zeitstempel beide im MAC erfasst werden (MAC-Timestamping). Die beiden Ports unterscheiden sich jedoch in ihrem PHY: Der 1GBit/s-Port nutzt einen PHY mit SFD-Erkennung und liefert damit die Voraussetzung für SFD-Timestamping @ti_dp83867e, während der 100/10MBit/s-Port über keine SFD-Erkennung verfügt und somit ausschließlich auf das gewöhnliche Interface-Signal angewiesen ist @microchip_ksz8081. Dadurch lässt sich der Einfluss der SFD-Erkennung auf die Zeitstempel-Genauigkeit innerhalb desselben Testaufbaus direkt vergleichen.
//(Muss ich hier erklären, wieso diese Hardware verwendet wird?)

Des Weiteren werden zwei STM32H7-Boards eingesetzt, von denen eines als Grandmaster Clock und das andere als Endpoint fungiert. Beide verfügen ebenfalls über einen 10/100MBit/s-PHY ohne SFD-Erkennung. Durch diese Kombination lässt sich ein Testaufbau mit maximal vier Hops gestalten. Dies erzwingt allerdings das Abschalten des Best Master Clock Algorithm (BMCA), um den einzelnen Systemen ihre feste Rolle zuzuweisen.


Da in dieser Arbeit nur die Bridgefunktion validiert werden soll, ist es nicht nötig, die Grandmaster Clock zu einer externen Zeitquelle zu synchronisieren. Daher wird diese Clock im Free-Running-Mode betrieben.

pDelay und Sync-Nachrichten werden nach den Standard werten auf jeweils 1Hz für pDelay und 8Hz für Sync gesendet.

== Interne Bridge Synchronisierung

Ein Problem gibt es mit der aktuellen Hardware. Da die Hardware über einen eigenen MAC für jede Ethernet Schnittstelle verfügt, ist die relative Zeit von MAC zu MAC immer Unterschiedlich.
Im gPTP Stack wird allerdings immmer nur der Timer zum zugehörigen Port Synchronisiert. Dies führt dazu, dass der Master Port auf der Bridge nicht Synchronisiert ist und dadruch die Nachfolgenden Systeme nicht korrekt Synchronisieren kann.

Um dieses Problem zu lösen, wird ein extra Task in ZephyrRTOS erstellt, der sich um das Synchronisieren des Master-Ports zum Slave-Port auf der Bridge kümmert.

Damit eine korrekte Synchronisierung gewährleistet werden kann müssen allerdings einige Anforderungen erfüllt werden, die in Annex B des Standards beschrieben werden.:

1. Für korrekte und genaue Messungen der Zeitstempel braucht es eine Auflösung von Mindestens $25"MHz"$. Das bedeutet, zwischen jedem Tick den der Timer macht, dürfen maxmimal $40"ns"$ vergehen.

2. Zeitstempel durch Messrauschen verfälscht werden können, darf die Rate-Korrektur zwischen Master und Slave nicht direkt aus einzelnen Timestamp-Differenzen abgeleitet werden, da dies zu einer Instabilen Regelung führen würde. Um dies zu verhindern, wird ein PI-Regler eingesetzt, der die Messewerte über meherere Sync-Intervalle glättet und daraus ein robustes rateRatio berechnet.

Neben diesen beiden Anforderungen fordert @ieee8021as2025[B.2.4] außerderm den Nachweis, dass die interne Synchronisierung zwischen Master und Slave eine Genauigkeit von 0,1ppm erreicht. Um dies nachzuweisen, wir wie folgt vorgegangen:

1. Einschwingzeit abwarten, damit sich der PI-Regelr auf einen stabilen Zustand einschwingen kann.

2. rateRatio zwischen Master und Slave über einen definierten Zeitraums messen und loggen.

3. Aus den Messungen wird die Abweichung von der geforderten Genauigkeit geprüft, indem die Standardabweichung des Messreihe berechnet wird. Dazu wird zunächst der Mittelwert $mu$ des Messreihe bestimmt, anschließend die Wahrscheinlichkeit $p_i$ der einzelnen Werte, und die Ergebnisse abschließend in folgende Formel eingesetzt:

  $sigma = sqrt("VAR") = sqrt((sum_(i=1)^n) (x_i - mu)^2 dot p_i)$

Liegt die berechnete Standardabweichung $sigma$ innerhalb der geforderten 0,1ppm, gilt die Anforderung an die interne Synchronisierung als erfüllt.


== Messmethodik
Um die tatsächlich erreichte Synchronisierungsgenauigkeit des Testaufbaus zu überprüfen, reicht eine rein softwareseitige Betrachtung der berechneten Offsets nicht aus, da diese bereits durch den Synchronisierungsalgorithmus korrigiert werden. Stattdessen wird die Synchronisierung über einen unabhängigen Hardware-Trigger am jeweiligen Mikrocontroller nachgewiesen: Die zu vergleichenden Clocks legen jeweils ein PPS-Signal (Pulse-per-Second) auf einen GPIO-Pin, welches direkt aus dem internen Timer der jeweiligen Clock abgeleitet wird und damit unabhängig vom gPTP-Stack ist. Die zeitliche Differenz zwischen zwei PPS-Flanken entspricht dem tatsächlichen Offset zwischen den beiden Clocks und lässt sich extern messen.

Für die Erfassung wird ein Oszilloskop mit vier Kanälen eingesetzt. Einer dieser Kanäle ist in jeder Messung fest dem Grandmaster (GM) zugeordnet, da dessen Clock die Referenz ist, auf die sich alle übrigen Geräte synchronisieren. Die verbleibenden drei Kanäle werden je nach Messziel unterschiedlich belegt: Zur Validierung einer einzelnen Bridge werden GM, Slave-Port und Master-Port derselben Bridge gleichzeitig gemessen. Zur Messung der PHY-Latenz-Asymmetrie werden Messung für Messung Bridges zwischen Grandmaster und Endpoint zwischen geschalten. Da hier 4 Messpukte nicht ausreichen wird die Kette in mehreren Läufen mit unterschiedlichen Messpukten durchgemessen.

Die PPS-Flanken der belegten Kanäle werden dabei jeweils gleichzeitig über mehrere aufeinanderfolgende PPS-Perioden aufgenommen und als Rohdaten exportiert. Ein Auswertungsskript berechnet aus jedem erfassten Flankensatz sowohl den Offset jedes Kanals relativ zum GM als auch die Differenz zwischen benachbarten Kanälen (Hop-zu-Hop-Offset) - je nachdem, welche Größe für die jeweilige Messung relevant ist. Für jeden Offset ergibt sich damit eine Zeitreihe über die gesamte Messdauer, die als Diagramm über der Zeit dargestellt wird.

In diesem Diagramm ist ein charakteristischer Verlauf zu erwarten: Direkt nach dem Start bzw. Link-Up ist der Offset zwischen den Clocks zunächst groß, da noch keine Synchronisierung stattgefunden hat. Mit fortschreitender Regelung durch den Synchronisierungsalgorithmus sinkt der Offset über mehrere Sync-Intervalle hinweg, bis er in einen stabilen Zustand übergeht - dieser Einschwingvorgang macht die Regelung des Synchronisierungsalgorithmus sichtbar. Der Offset läuft dabei nicht exakt gegen null, sondern pendelt im eingeschwungenen Zustand innerhalb eines kleinen Reststreubands, dessen Größe durch die in Abschnitt "Zeitliche Anforderungen" festgelegten Genauigkeitsanforderungen begrenzt sein muss, damit der Testaufbau als konform gilt.


== Ungenauigkeiten
Der pDelay-Machanismus aus @pDelay-mechanism setzt voraus, dass die Singallaufzeit zwischen zwei Ports in beide Richtungen symmetrisch ist @ieee8021as2025[11.2]. Nur unter dieser Annahme lässt sich aus der Summe $t_4 - t_1$ und $t_3 - t_2$ ein einseitiger meanLinkDelay berechnen. Der vorliegende Testaufbau verletzt jedoch diese Annahme. Wie im Kaptiel Timestamping beschrieben verfügt der 1Gbit PHY über eine SFD-Erkennung. Die beiden 10/100Mbit PHYs besitzten diese Funktion jedoch nicht. Der zugehörige MAC muss den Zeitstempel daher an der MAC-PHY-Schnittstelle selbst erzeugen. Alles was in einem Ethernet-Frame vor der SFD steht liegt dadurch innerhalb des Zeitstempels. Zusätzlich ist diese interne Verarbeitungszeit zwischen Sende- und Empfangsrichtung nicht notwendigerweise gleich groß, wodurch die Symmetrieannahme des pDelay-Machanismus verletzt wird. Diese Asymmetrie erkärt, warum an Hops mit einem 10/100Mbit PHY ein deutlich höherer meanLinkDelay gemessen wird.\
Ein zweiter, indirekter Effekt betrifft die `neighborRateRatio`: Diese wird aus der Steigung aufeinanderfolgender pDelay-Messungen über die Zeit bestimmt berechnet und benötigt daher einen möglichst genauen Zeitstempel, um eine reale Frequenzabweichung im ppb-Bereich überhaupt auflösen zu können. Ist das Rauschen der Zeitstempel größer als dieses Auflösungsvermögen, verschwindet das eigentliche Messsignal im Rauschen - Die Berechnung liefert dann eine rateRatio von exakt 1.000000, nicht weil die beiden Clock tatsächlich identisch liefen, sondern weil die Messmethode zu grob ist um den realen Unterschied zu erkennen @bailleul2023etfa. Da der Testaufbau aus mehreren verknüpfungen ohne SFD-Erkennung besteht, wirkt sich diese Asymmetrie nicht nur an einem einzelnen Hop aus, sondern an jemdem Hop erneut.

// //https://www.irit.fr/~Katia.Jaffres/Fichiers/2021ETR.pdf
// Wo können unginauigkeiten aufkommen bezüglich des timestampens, pDelay & residence Time berechnungen und dem Synchronisieren?

// - Z.B. mit STM32 hat man einen zu hohen pDelay
// - Clock Qualität (temparatur)
// - 100 MBit/s eth phy vs 1GBit/s eth phy
