#import "../meta.typ": acr-cap, acr-emph, cap-long-only, fig-platzhalter-mittel, note, req, tab-d, tab-h
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Analyse und Entwurf
Wie wurde #acr("gPTP") Implementiert? Ziemlich genau nach den Stateautomaten, die im Standard beschrieben sind.


== Anforderungen

=== Zeitliche Anforderungen
Annex B des Standards definiert eine reihe an Leistungsanforderungen, an denen sich eine konforme Implementierung messen lasssen muss. Die für diese Arbeit relevanten Grenzwerrte sind in der folgende Tabelle zusammengefasst:

#figure(
  table(
    columns: (2fr, 1fr),
    align: (left, left, left),
    stroke: none,
    table.hline(),
    tab-h[Anforderung], tab-h[Grenzwert],
    table.hline(stroke: 0.5pt),
    tab-h[Residence Time @ieee8021as2025[B.2.2]], tab-h[$<= 10m s$],
    tab-h[pDelay Turnaround Time @ieee8021as2025[B.2.3]], tab-h[$<= 10m s$],
    tab-h[#acr-cap("E2E")-Synchronisationsgenauigkeit @ieee8021as2025[B.3]], tab-h[$<=1mu s$],
    tab-h[Granularität der LocalCLock @ieee8021as2025[B.1.2]], tab-h[$<=40n s$],
    tab-h[meanLinkDelayThresh @ieee8021as2025[11.2.2]], tab-h[$"   "800n s$],
    table.hline(),
  ),
  caption: [gPTP Leistungsanforderungen#cap-long-only[ @ieee8021as2025[Annex B]]],
)<tab-zeitanforderungen>

Die Residence Time bezeichnet die maximale Zeit, die eine Sync-Nachricht innerhalb einer Time-Aware Bridge vom Eingang bis Ausgang benötigt. Die pDelay Turnaround Time beschreibt wie lange ein System zum Verabeiten der pDelay_Resp-Nachricht brauchen darf. Beide Werte begrenzen wie schnell eine Bridge die zugehörige Berechnung durchführen muss.

Die #acr-emph("E2E")-Synchronisationsgenauigkeit gilt laut @ieee8021as2025[B.3] kumulativ über die gesamte Kette. Vorrausgesetzt die Kette ist nicht größer als sieben Hops und erfordert, dass alle Geräte zu einem gewissen Grad Synchronisiert sind.

Die Granularität der LocalClock beschreibt die minimal Auflösung mit der die lokale Clock die Zeit erfassen muss, und ist damit Vorraussetzung für die anderen drei Anforderungen. Eine gröbere Granularität würde bereits zu Messungenauigkeiten bei der `residence Time` und `pDelay` Messung führen.

Der meanLinkDelayThresh unterscheidet sich in der Art von den übrigen Anforderungen. Es handelt sich nicht um eine Genauigkeits- oder Timing-Anforderung an die Implementierung, sondern um einen Schwellenwert, gegen den der gemessene mittlere Link Delay (meanLinkDelay) verglichen wird. Überschreitet der gemessene Link Delay diesen Wert, geht der Standard davon aus, dass im Link Equipment ohne #acr("gPTP")-Unterstützung vorhanden ist. Für 100BASE-TX- und 1000BASE-T-Verbindungen (Kupfer) beträgt der Schwellenwert 800 ns;

=== Hardwareanfoderunge

Neben den normativen Zeitanforderungen ergeben sich aus dem gewählten Testaufbau weitere Anforderungen an die eingesetzte Hardware:

- Hardware-Timestamping: Zeitstempel für ein- und ausgehende #acr("gPTP")-Nachrichten müssen auf #acr("MAC")-Ebene erzeugt werden (Begründung folgt in Abschnitt "MAC Timestamping").
- Mindestens zwei Ports: Jede Time-Aware Bridge muss Nachrichten an einem Port empfangen und über einen weiteren weiterleiten können.
- Clock-Qualität: Offset und Jitter der Oszillatoren müssen die Einhaltung von #acr("E2E")-Synchronisationsgenauigkeit über die gesamte Messdauer zulassen.


== Testaufbau
Für den nachfolgenden Testaufbau werden drei phyBOARD-Atlas-Boards@phytec_imxrt1170_devkit als Bridge eingesetzt. Diese verfügen jeweils über zwei Ports, deren Zeitstempel beide im #acr("MAC") erfasst werden (siehe 2.3.2). Die beiden Ports unterscheiden sich jedoch in ihrem #acr("PHY"). Der 1GBit/s-Port nutzt einen #acr("PHY") mit #acr("SFD")-Erkennung und liefert damit die Voraussetzung für #acr("SFD")-Timestamping@ti_dp83867e, während der 100/10MBit/s-Port über keine #acr("SFD")-Erkennung verfügt und somit ausschließlich auf das gewöhnliche Interface-Signal angewiesen ist @microchip_ksz8081. Dadurch lässt sich der Einfluss der #acr("SFD")-Erkennung auf die Zeitstempel-Genauigkeit innerhalb desselben Testaufbaus direkt vergleichen.
//(Muss ich hier erklären, wieso diese Hardware verwendet wird?)

Des Weiteren werden zwei STM32H7-Boards@st_nucleo_h755zi_q eingesetzt, von denen eines als Grandmaster Clock und das andere als Endpoint fungiert. Beide verfügen ebenfalls über einen 10/100MBit/s-#acr("PHY") ohne #acr("SFD")-Erkennung. Durch diese Kombination lässt sich ein Testaufbau mit maximal vier Hops gestalten. Dies erzwingt allerdings das Abschalten des #acr("BTCA"), um den einzelnen Systemen ihre feste Rolle zuzuweisen.


Da in dieser Arbeit nur die Bridgefunktion validiert werden soll, ist es nicht nötig, die Grandmaster Clock zu einer externen Zeitquelle zu synchronisieren. Daher wird diese Clock im Free-Running-Mode betrieben.

pDelay und Sync-Nachrichten werden nach den Standard werten auf jeweils 1Hz für pDelay und 8Hz für Sync gesendet.

== Interne Bridge Synchronisierung

Ein Problem gibt es mit der aktuellen Hardware. Da die Hardware über einen eigenen #acr("MAC") für jede Ethernet Schnittstelle verfügt, ist die relative Zeit von #acr("MAC") zu #acr("MAC") immer Unterschiedlich.
Im #acr("gPTP") Stack wird allerdings immmer nur die Clock zum zugehörigen Port Synchronisiert. Dies führt dazu, dass der Master Port auf der Bridge nicht Synchronisiert ist und dadruch die Nachfolgenden Systeme nicht korrekt Synchronisieren kann.

Um dieses Problem zu lösen, wird ein extra Task in Zephyr erstellt, der sich um das Synchronisieren des Master-Ports zum Slave-Port auf der Bridge kümmert.

Damit eine korrekte Synchronisierung gewährleistet werden kann müssen allerdings einige Anforderungen erfüllt werden, die in Annex B des Standards beschrieben werden.:

1. Für korrekte und genaue Messungen der Zeitstempel braucht es eine Clock-Frequenz von mindestens $25"MHz"$, was einer Auflösung von $40"ns"$ entspricht. Das bedeutet, zwischen jedem Tick, den die Clock macht, maximal $40"ns"$ vergehen dürfen.

2. Zeitstempel durch Messrauschen verfälscht werden können, darf die Rate-Korrektur zwischen Master und Slave nicht direkt aus einzelnen Timestamp-Differenzen abgeleitet werden, da dies zu einer Instabilen Regelung führen würde. Um dies zu verhindern, wird ein #acr-emph("PI")-Regler eingesetzt, der die Messewerte über meherere Sync-Intervalle glättet und daraus ein robustes rateRatio berechnet.

Neben diesen beiden Anforderungen fordert @ieee8021as2025[B.2.4] außerderm den Nachweis, dass die interne Synchronisierung zwischen Master und Slave eine Genauigkeit von 0,1 #acr-emph("ppm") erreicht. Da rateRatio eine Frequenzgröße ist, wird dieser Nachweis über die Allan-Abweichung der gemessenen rateRatio-Werte erbracht @allan1966statistics @riley2008frequencystability[13]. In dieser Arbeit wird dazu wie folgt vorgegangen:

1. Einschwingzeit abwarten, damit sich der #acr("PI")-Regelr auf einen stabilen Zustand einschwingen kann.

2. rateRatio zwischen Master und Slave über einen definierten Zeitraums messen und loggen.

3. Aus den Messungen wird die Abweichung von der geforderten Genauigkeit geprüft, indem die Allan-Abweichung $sigma_y (tau)$ der rateRatio-Messreihe berechnet wird. Da rateRatio bereits eine über das Messintervall $tau$ gemittelte Frequenzschätzung ist, wird dazu die Varianz der Differenzen aufeinanderfolgender Werte gebildet, statt die Streuung um den Gesamtmittelwert zu betrachten wie bei der klassischen Standardabweichung: Für die bei Quarzoszillatoren typischen Rauschprozesse (z. B. Flicker- oder Random-Walk-Frequenzrauschen) konvergiert die klassische Varianz nicht zuverlässig und wird durch langsamen Drift verfälscht, während die Allan-Varianz dagegen robust ist @allan1966statistics – dasselbe Konzept (ADEV), das @ieee8021as2025[B.1.3.2] für die Rauschcharakterisierung der LocalClock referenziert @riley2008frequencystability[14]:

$
  sigma_y (tau) = sqrt(1/(2(M-1)) sum_(i=1)^(M-1) (y_(i+1) - y_i)^2)
$

Dabei ist $y_i = "rateRatio"_i - 1$ die fraktionale Frequenzabweichung des $i$-ten Messintervalls und $M$ die Anzahl der gemessenen Intervalle. Liegt die berechnete Allan-Abweichung $sigma_y (tau)$ innerhalb der geforderten 0,1 #acr("ppm"), gilt die Anforderung an die interne Synchronisierung als erfüllt.


== Messmethodik

=== Messaufbau und Datenerfassung
Um die tatsächlich erreichte Synchronisierungsgenauigkeit des Testaufbaus zu überprüfen, reicht eine rein softwareseitige Betrachtung der berechneten Offsets nicht aus, da diese bereits durch den Synchronisierungsalgorithmus korrigiert werden. Zudem würden systematische Messfehler innerhalb eines Controllers auf diese Weise nicht auffallen, da dieselben Fehler sowohl die #acr("gPTP")-Synchronisation selbst als auch eine rein softwareseitige Messung ihrer Genauigkeit gleichermaßen verfälschen würden. Stattdessen wird die Synchronisierung über einen unabhängigen Hardware-Trigger am jeweiligen Mikrocontroller nachgewiesen: Die zu vergleichenden Clocks legen jeweils ein #acr("PPS")-Signal auf einen #acr-emph("GPIO")-Pin. Ein Impuls, der immer genau beim Rollover zur nächsten Sekunde ausgelöst wird. Da dieser Impuls direkt aus dem internen Timer der Clock abgeleitet wird, ist er unabhängig vom #acr("gPTP")-Stack. Die zeitliche Differenz zweier #acr("PPS")-Flanken entspricht dem tatsächlichen Offset zwischen den beiden Clocks und lässt sich extern messen@nguyen2020fuzzypi.

Für die Erfassung wird ein Oszilloskop mit vier Kanälen eingesetzt. Einer dieser Kanäle ist in jeder Messung fest dem #acr("GM") zugeordnet, da deren Clock die Referenz ist, auf die sich alle übrigen Geräte synchronisieren. Die verbleibenden drei Kanäle werden je nach Messziel unterschiedlich belegt.

Da das Oszilloskop selbst zur Messkette gehört, muss dessen zeitliche Auflösung deutlich feiner sein als die kleinste zu prüfende Anforderung. Andernfalls würde die Quantisierung des Messgeräts das Messergebnis verfälschen, statt es nur abzubilden. Das eingesetzte Oszilloskop muss folglich eine Zeitbasis im niedrigen Nanosekundenbereich auflösen, damit die $40n s$-Anforderung überhaupt nachweisbar ist. Zum Einsatz kommt ein Keysight MSOX3104T@keysight_msox3104t mit $1"GHz"$ Bandbreite und einer Abtastrate von $5"GSa/s"$, was einem zeitlichen Abstand von $200p s$ zwischen zwei Samples entspricht und damit deutlich unterhalb der geforderten $40n s$ liegt.

Die #acr("PPS")-Flanken der belegten Kanäle werden dabei jeweils gleichzeitig über eine länge von 1000 #acr("PPS")-Perioden aufgenommen und als Rohdaten exportiert. Ein Auswertungsskript berechnet aus jedem erfassten Flankensatz sowohl den Offset jedes Kanals relativ zum #acr("GM") als auch die Differenz zwischen benachbarten Kanälen (Hop-zu-Hop-Offset). Welche der beiden Größen im Vordergrund steht, hängt vom jeweiligen Messziel ab. Der #acr("GM")-relative Offset weist die kumulative #acr-emph("E2E")-Synchronisationsgenauigkeit der gesamten Kette nach, während der Hop-zu-Hop-Offset den Beitrag einer einzelnen Bridge isoliert und damit erlaubt, Effekte wie die #acr-emph("PHY")-Asymmetrie aus @Ungenauigkeiten einer konkreten Bridge zuzuordnen. Für jeden Offset ergibt sich damit eine Zeitreihe über die gesamte Messdauer, die als Diagramm über der Zeit dargestellt wird.

In diesem Diagrammen ist unabhängig vom Messziel ein charakteristischer Verlauf zu erwarten. Direkt nach dem Start bzw. Link-Up ist der Offset zwischen den Clocks zunächst groß, da noch keine Synchronisierung stattgefunden hat. Mit fortschreitender Regelung durch den Synchronisierungsalgorithmus sinkt der Offset über mehrere Sync-Intervalle hinweg, bis er in einen stabilen Zustand übergeht. Dieser Einschwingvorgang macht die Regelung des Synchronisierungsalgorithmus sichtbar. Der Offset läuft dabei nicht exakt gegen null, sondern pendelt im eingeschwungenen Zustand innerhalb eines kleinen Reststreubands. Für den #acr("GM")-relativen Offset ist dessen maximal zulässige Breite direkt durch die #acr-emph("E2E")-Synchronisationsgenauigkeit aus @tab-zeitanforderungen vorgegeben.


=== Validierung einer einzelnen Bridge
Zur Validierung einer einzelnen Bridge werden die #acr("PPS")-Signale des #acr("GM")s, Slave-Port und Master-Port der Bridge, als auch dem Endpoint gleichzeitig gemessen. Dadurch lässt sich der relative Offset zwischen #acr("GM") und den einzelnen Ports, als auch der isolierte Hop-Offset einer Bridge messen. Im Vordergrund steht dabei entsprechend der Hop-zu-Hop-Offset, unabhängig davon, an welcher Stelle der Kette die Bridge später eingesetzt wird.

#fig-platzhalter-mittel(
  caption: [Beispielhafte Offset-Zeitreihe bei der Validierung einer einzelnen Bridge],
  label: <fig-messziel-einzelbridge>,
)[
  Offset-Zeitreihen von #acr("GM"), Slave-Port und Master-Port derselben Bridge in einem gemeinsamen Plot. Alle drei Kurven zeigen zu Beginn einen großen Offset, der über mehrere Sync-Intervalle in das Reststreuband einschwingt; $t_"set"$ sowie das Toleranzband aus @tab-zeitanforderungen sind als horizontale Linien eingezeichnet. Die Differenz zwischen Slave- und Master-Port-Kurve im eingeschwungenen Zustand entspricht dem Hop-zu-Hop-Offset dieser Bridge.
]

=== Validierung mit mehreren Bridges
Die #acr-emph("E2E")-Synchronisationsgenauigkeit gilt, wie in Abschnitt "Zeitliche Anforderungen" beschrieben, nur kumulativ über eine Kette von maximal sieben Hops. Der in dieser Arbeit verwendete Testaufbau bleibt mit maximal vier Hops (siehe Abschnitt "Testaufbau") innerhalb dieser Grenze, die Einzelbridge-Validierung weist aber nur den isolierten Beitrag einer einzelnen Bridge nach. Um dies auch für die tatsächlich eingesetzte Kettenlänge nachzuweisen, werden zusätzlich Messungen mit schrittweise mehr hintereinandergeschalteten Bridges durchgeführt.

Sobald mehr als eine Bridge im System ist, reichen die vier Messpunkte des Oszilloskops nicht mehr aus, um die gesamte Kette gleichzeitig zu erfassen. Daher wird die Kette in mehreren Läufen mit unterschiedlicher Kanalbelegung durchgemessen. Dabei bleiben die Kanäle für den #acr("GM") und den Endpoint immer gleich belegt, um zusätzlich die #acr("E2E")-Synchronisation nachzuweisen. Im Vordergrund steht dabei entsprechend der #acr("GM")-relative Offset.


#fig-platzhalter-mittel(
  caption: [Beispielhafte Offset-Zeitreihe bei der Validierung der gesamten Kette],
  label: <fig-messziel-kette>,
)[
  #acr("GM")-relative Offset-Zeitreihen mehrerer, über die Läufe hinweg verketteter Messpunkte (z. B. #acr("GM"), Bridge 1, Bridge 2, Endpoint) in einem gemeinsamen Plot. Jede Kurve schwingt einzeln in ihr Reststreuband ein; das Toleranzband der #acr-emph("E2E")-Synchronisationsgenauigkeit aus @tab-zeitanforderungen ist als horizontale Linie eingezeichnet. Der wachsende Abstand der Kurven zueinander zeigt, wie sich der Offset von Hop zu Hop entlang der Kette aufsummiert.
]

=== Statistische Auswertung
Aus jeder Zeitreihe werden für das Kapitel Evaluation die folgenden Kennzahlen abgeleitet. Sie bilden die gemeinsame Grundlage, gegen die dort alle Messreihen ausgewertet werden:

- *Einschwingzeit $t_"set"$:* der früheste Zeitpunkt, ab dem der Offset das durch die jeweilige Anforderung vorgegebene Toleranzband nicht mehr verlässt und darin bis zum Ende der Messung verbleibt. Eine einzelne, kurzzeitige Unterschreitung des Toleranzbands zählt nicht als Einschwingen, da sie nur zufällig getroffen sein kann. Erst ab $t_"set"$ gilt die Synchronisierung als eingeschwungen. Alle folgenden Kennzahlen werden ausschließlich auf den Proben nach $t_"set"$ berechnet, damit der Einschwingvorgang selbst deren Mittelwert und Streuung nicht verfälscht.
//todo: ist die einschwingzeit ein relevante messung ?
- *Mittelwert $mu$ und Standardabweichung $sigma$:* berechnet nach:
  $
    sigma = sqrt((sum_(i=1)^n) (x_i - mu)^2 dot p_i)
  $ <standardabweichung-calc>
  (vgl. Abschnitt "Interne Bridge Synchronisierung"). $mu$ zeigt einen verbleibenden systematischen Versatz an, etwa durch die in @Ungenauigkeiten diskutierte #acr-emph("PHY")-Asymmetrie, während $sigma$ das Rauschen bzw. den Jitter der Synchronisierung im eingeschwungenen Zustand quantifiziert. Beide Werte dienen dabei nicht selbst als Konformitätskriterium, sondern helfen, ein auffälliges Messergebnis einer der in @Ungenauigkeiten benannten Fehlerquellen zuzuordnen.

- *Histogramm:* die Verteilung der Offset-Proben nach $t_"set"$, dargestellt als Histogramm. Es dient zum einen der Plausibilisierung von $sigma$, da dessen übliche Interpretation eine näherungsweise normalverteilte Störung voraussetzt, zum anderen dem Erkennen systematischer Effekte: Eine schiefe oder mehrgipflige Verteilung deutet auf eine zusätzliche, nicht rein stochastische Fehlerquelle hin, etwa eine Asymmetrie im Signalpfad@nguyen2020fuzzypi.

Die Messdauer je Lauf muss zwei Bedingungen gleichzeitig erfüllen: Sie muss lang genug sein, um den vollständigen Einschwingvorgang zu erfassen, und nach $t_"set"$ genügend Proben liefern, damit $mu$, $sigma$ sowie das Histogramm nicht mehr nennenswert vom Stichprobenumfang abhängen. In der Praxis wird dies mit den ohnehin für die Langzeitstabilität vorgesehenen, mehrstündigen Aufzeichnungen (siehe Kapitel Tests) abgedeckt; für Läufe, die gezielt einzelne Bridges oder Kanalkombinationen validieren, wird die Messdauer so gewählt, dass nach dem Einschwingen mehrere hundert #acr("PPS")-Perioden für die Statistik zur Verfügung stehen.
//todo: Messdauer z.B. mehrere Stunden, dabei werden intervallmäßig aufnahmen von 1000 Segemnte (16.6 Min)erstellt. Oszi erlaubt nicht mehr. -> 2 Messungen Pro Stunde, Am anfang der stunde und in der Mitte.

== Ungenauigkeiten<Ungenauigkeiten>
Der pDelay-Machanismus aus @pDelay-mechanism setzt voraus, dass die Singallaufzeit zwischen zwei Ports in beide Richtungen symmetrisch ist @ieee8021as2025[11.2]. Nur unter dieser Annahme lässt sich aus der Summe $t_4 - t_1$ und $t_3 - t_2$ ein einseitiger meanLinkDelay berechnen. Der vorliegende Testaufbau verletzt jedoch diese Annahme. Wie im Kaptiel Timestamping beschrieben verfügt der 1Gbit #acr("PHY") über eine #acr("SFD")-Erkennung. Die beiden 10/100Mbit #acrpl("PHY") besitzten diese Funktion jedoch nicht. Alles was in einem Ethernet-Frame vor dem #acr("SFD") steht liegt dadurch innerhalb des Zeitstempels. Zusätzlich ist diese interne Verarbeitungszeit zwischen Sende- und Empfangsrichtung nicht notwendigerweise gleich groß, wodurch die Symmetrieannahme des pDelay-Machanismus zusätzlich verletzt wird. Diese Asymmetrie erkärt, warum an Hops mit einem 10/100Mbit #acr("PHY") ein deutlich höherer meanLinkDelay gemessen wird.
