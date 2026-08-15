#import "../meta.typ": acr-emph, fig-platzhalter-mittel, gls, note, req, tab-d, tab-h
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Analyse und Entwurf <analyse-und-entwurf>
Aufbauend auf den in @Grundlagen vorgestellten Grundlagen leitet dieses Kapitel zunächst die für die vorliegende Arbeit relevanten Anforderungen an eine konforme #acr-emph("gPTP")-Implementierung ab. Anschließend wird der grundlegende Testaufbau vorgestellt, mit dem diese Implementierung in den folgenden Kapiteln validiert wird, gefolgt von der Messmethodik, die beschreibt, wie die Einhaltung der zuvor abgeleiteten Anforderungen messtechnisch nachgewiesen wird. Abschließend werden bekannte Ungenauigkeiten des Testaufbaus benannt, die bei der späteren Interpretation der Messergebnisse zu berücksichtigen sind.

== Anforderungen

Eine konforme #acr-emph("gPTP")-Implementierung muss mehr leisten, als nur die in Annex B des Standards genannten Zeitgrenzwerte einzuhalten. Dieser Abschnitt gliedert die für die Arbeit relevanten Anforderungen deshalb in vier Gruppen: die normativen Leistungsanforderungen aus Annex B selbst, die normative Obergrenze der `residence time`, die Robustheit der Synchronisierung unter Netzwerklast, sowie die sich aus dem Testaufbau ergebenden Hardwareanforderungen. @tab-anforderungen fasst die daraus abgeleiteten Einzelanforderungen am Ende des Abschnitts zusammen und vergibt die Bezeichner, auf die sich die Erfüllungsmatrix in @erfuellungsmatrix später bezieht.

=== Normative Leistungsanforderungen <normative-leistungsanforderungen>
Der Standard macht die Synchronisierung eines Ports von der Variable `asCapable` abhängig @ieee8021as2025[10.2.5.1]. Nur wenn sie `TRUE` ist, verarbeitet die Sync-Statemachine überhaupt eingehende Sync-Nachrichten @ieee8021as2025[11.2.2]. Ist sie `FALSE`, verwirft die Bridge jede Sync-Nachricht. Unter anderem hängt `asCapable` vom gemessenen meanLinkDelay ab @ieee8021as2025[11.2.2]. Überschreitet dieser $800n s$ (100BASE-TX/1000BASE-T), geht der Standard von Equipment ohne #acr("gPTP")-Unterstützung im Pfad aus und setzt `asCapable` auf `FALSE`.

Ist `asCapable` TRUE, hängt die tatsächlich erreichte Genauigkeit von zwei weiteren, unabhängigen Anforderungen ab. Die Granularität der LocalClock darf $40n s$ nicht überschreiten @ieee8021as2025[B.1.2] und die Messgenauigkeit der rateRatio muss innerhalb von $0,1$ #acr("ppm") liegen @ieee8021as2025[B.2.4]. Eine gröbere Granularität würde bereits die zugrundeliegenden Zeitstempel verfälschen, eine ungenauere rateRatio-Messung dagegen sowohl die Skalierung von Leitungsverzögerung und `residence time` im `correctionField` als auch die Syntonisierung des Empfängers.

Werden diese Anforderungen eingehalten, gilt die eigentliche Zielgröße dieser Arbeit. Die #acr-emph("E2E")-Synchronisationsgenauigkeit von $<=1mu s$ über bis zu sieben Hops @ieee8021as2025[B.3], allerdings ausdrücklich nur "during steady-state operation", was bedeutet, dass die Einschwingphase hier nicht beachtet wird @ieee8021as2025[B.3].

Neben den Genauigkeitsgrenzen begrenzt der Standard auch die Zeit, die eine Nachricht innerhalb einer PTP Relay Instance verbringen darf. Die `residence time` einer Bridge darf $10"ms"$ nicht überschreiten @ieee8021as2025[B.2.2].
Für die vorliegende Arbeit ist diese Anforderung besonders relevant, weil die untersuchte Implementierung die Weiterleitung rein in Software durchführt.

=== Frequenzgenauigkeit des bridge-internen Zeitabgleichs <anforderung-interner-abgleich>
IEEE 802.1AS modelliert je PTP-Instanz genau eine LocalClock, die allen Ports gemeinsam zur Verfügung steht. Der Standard kennt deshalb keinen Abgleich zwischen mehreren Uhren innerhalb eines Geräts. Die in dieser Arbeit eingesetzten Bridges verfügen je Port einen eigenen MAC (siehe @testaufbau). Daher muss der in @bridge-sync-impl beschriebene Servo die vom Standard vorausgesetzte Genauigkeit ebenso einhalten, da diese eine Vorbedingung dafür ist, dass Annex B auf diese Plattform überhaupt anwendbar ist.

Der Servofehler geht dabei an derselben Stelle in die Zeitübertragung ein wie ein Fehler der normativen rateRatio-Messung. Die `residenceTime` ($t_"res"$) wird nach @sync-mechanism als Differenz zwischen $t_s "und" t_r$ gebildet, wobei $t_r$ auf der Clock des Slave-Ports und $t_s$ auf der des Master-Ports entsteht. Jede Frequenzabweichung zwischen beiden Uhren skaliert diese Differenz und wirkt über das `correctionField` unmittelbar auf die gesamte Kette.

Für die zulässige Frequenzabweichung $epsilon$ des Servos gilt damit unmittelbar dieselbe Schranke wie für die normative rateRatio-Messung, also $epsilon < 0,1$ #acr("ppm") nach @ieee8021as2025[B.2.4]. Die Anforderung ist damit abgeleitet und nicht normativ, ihr Zahlenwert aber dem Standard entnommen.

=== Robustheit unter Netzwerklast <anforderung-netzwerklast>
Annex B selbst nennt keinen eigenen Grenzwert für Netzwerklast. Relevant ist die Anforderung dennoch, weil die #acr-emph("E2E")-Synchronisationsgenauigkeit aus @normative-leistungsanforderungen laut Standard nur unter der bereits genannten Bedingung gilt, dass jede Instanz ihre Sync-Nachricht in jedem Intervall empfängt. Genau diese Bedingung gefährdet Best-Effort-Nutzverkehr auf demselben physischen Port. Werden #acr("gPTP")-Nachrichten durch konkurrierenden Verkehr verzögert oder verworfen, ist die Vorbedingung von B.3 verletzt, unabhängig davon, wie exakt Granularität und rateRatio-Genauigkeit eingehalten werden.

Entscheidend ist dabei, an welcher Stelle der Verkehr um Ressourcen konkurriert. Ein Synchronisationsausfall unter Last entsteht in der Praxis selten durch einen falschen Zeitstempel, sondern dadurch, dass eine #acr("gPTP")-Nachricht auf dem Empfangspfad keinen Puffer mehr erhält und deshalb gar nicht erst beim Protokollstapel ankommt. Der Nachweis dieser Anforderung darf sich folglich nicht auf die beobachtete Genauigkeit beschränken, sondern muss zusätzlich zeigen, dass der #acr("gPTP")-Verkehr auch unter Last durchgängig mit Puffern versorgt bleibt.

=== Hardwareanforderungen

Neben den normativen Leistungsanforderungen ergeben sich aus dem gewählten Testaufbau weitere Anforderungen an die eingesetzte Hardware. Zeitstempel für ein- und ausgehende #acr("gPTP")-Nachrichten müssen dabei mindestens auf #acr("MAC")-Ebene erzeugt werden (siehe @hardware-timestamping), und jede Time-Aware Bridge muss Nachrichten an einem Port empfangen und über einen weiteren weiterleiten können, verfügt also über mindestens zwei Ports. Da im Testaufbau sowohl gigabit- als auch fast-ethernet-fähige Geräte in gemischten Ketten miteinander verbunden werden, muss außerdem jedes eingesetzte Gerät mindestens 100BASE-TX unterstützen, damit sich über alle Hops hinweg eine durchgängige Verbindung herstellen lässt.

=== Zusammenfassung der Anforderungen
@tab-anforderungen fasst die in diesem Abschnitt abgeleiteten Anforderungen zusammen. Die vergebenen Bezeichner A1 bis A8 dienen als durchgängige Referenz. Die Messmethodik in @messmethodik ordnet jeder Anforderung ein Nachweisverfahren zu, die Tests in @tests erbringen den jeweiligen Nachweis, und die Erfüllungsmatrix in @erfuellungsmatrix führt letztendlich beides zusammen.

#figure(
  table(
    columns: (0.4fr, 2.6fr, 1.3fr),
    align: (left, left, left),
    stroke: none,
    table.hline(),
    tab-h[ID], tab-h[Anforderung], tab-h[Herkunft],
    table.hline(stroke: 0.5pt),

    tab-d[A1 #label("a1")],
    tab-d[`asCapable` = `TRUE`, d. h. meanLinkDelay $<=800n s$ auf jedem Link],
    tab-d[normativ @ieee8021as2025[10.2.5.1]],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[A2 #label("a2")],
    tab-d[Granularität der LocalClock $<=40n s$],
    tab-d[normativ @ieee8021as2025[B.1.2]],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[A3 #label("a3")],
    tab-d[Messgenauigkeit der `neighborRateRatio` $<=0,1$ #acr("ppm") je Port],
    tab-d[normativ @ieee8021as2025[B.2.4]],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[A4 #label("a4")],
    tab-d[#acr-emph("E2E")-Synchronisationsgenauigkeit $<=1mu s$ über bis zu sieben Hops im eingeschwungenen Zustand],
    tab-d[normativ @ieee8021as2025[B.3]],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[A5 #label("a5")],
    tab-d[`residence time` je PTP Relay Instance $<=10"ms"$],
    tab-d[normativ @ieee8021as2025[11.1.3]],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[A6 #label("a6")],
    tab-d[Synchronisation bleibt unter Best-Effort-Netzwerklast auf demselben Port erhalten, ohne dass #acr("gPTP")-Nachrichten mangels Puffer verworfen werden],
    tab-d[abgeleitet (@anforderung-netzwerklast)],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[A7 #label("a7")],
    tab-d[#acr("MAC")-Timestamping, $>=2$ Ports je Bridge, mindestens 100BASE-TX],
    tab-d[Testaufbau],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[A8 #label("a8")],
    tab-d[Frequenzabweichung des bridge-internen Zeitabgleichs $<=0,1$ #acr("ppm")],
    tab-d[abgeleitet (@anforderung-interner-abgleich)],
    table.hline(),
  ),
  caption: [Übersicht der abgeleiteten Anforderungen],
) <tab-anforderungen>

== Grundlegender Testaufbau <testaufbau>
Für die nachfolgenden Tests werden drei phyBOARD-Atlas-Boards@phytec_imxrt1170_devkit als Bridge eingesetzt. Jedes Board verfügt über zwei Ethernet-Ports mit unterschiedlichem #acr("PHY"). Der 1GBit/s-Port nutzt einen #acr("PHY") mit #acr("SFD")-Erkennung @ti_dp83867e, der 100/10MBit/s-Port hingegen einen #acr("PHY") ohne #acr("SFD")-Erkennung @microchip_ksz8081. Auf jeder Bridge liegt der #acr("gPTP")-Slave-Port dabei fest auf dem #acr("SFD")-fähigen 1GBit/s-Port (`enet1g`), der Master-Port entsprechend auf dem 100/10MBit/s-Port (`enet`) ohne #acr("SFD")-Erkennung. Da Letzterer die Verbindung zum jeweils nächsten Hop bildet, ist jede Inter-Bridge-Strecke in der Kette damit unabhängig von der auf der Gegenseite verfügbaren Gigabit-Bandbreite auf $100"Mbit/s"$ begrenzt. Des Weiteren werden zwei STM32H7-Boards@st_nucleo_h755zi_q eingesetzt, von denen eines als Grandmaster Clock und das andere als Endpoint fungieren soll. Beide verfügen ebenfalls über einen 10/100MBit/s-#acr("PHY") ohne #acr("SFD")-Erkennung. Durch diese Kombination lässt sich ein Testaufbau mit maximal vier Hops gestalten, was jedoch das Abschalten des #acr("BTCA") erzwingt, um den einzelnen Systemen ihre feste Rolle zuzuweisen.

Als _Hop_ wird in dieser Arbeit durchgehend eine einzelne Verbindung zwischen zwei benachbarten PTP-Instanzen bezeichnet, entsprechend der Zählweise, die dem in @normative-leistungsanforderungen genannten Grenzwert von sieben Hops zugrunde liegt. Eine Kette aus $n$ Bridges zwischen Grandmaster und Endpoint besitzt damit $n+1$ Hops: Der Aufbau Grandmaster $<->$ Bridge 1 $<->$ Endpoint umfasst zwei Hops, der maximale Aufbau dieser Arbeit mit drei Bridges entsprechend vier Hops. Die vom Standard vorgesehene maximale Kettenlänge von sieben Hops entspricht folglich sechs kaskadierten Bridges.

Die beiden Ports des phyBOARD-Atlas weisen bei den in @mac-layer und @cbs behandelten #acr("CBS")-Mechanismen Unterschiede auf. Während die #acr("MAC")-Peripherie des 1GBit/s-Ports (`enet1g`) einen Credit Based Shaper unterstützt @zephyr_eth_nxp_enet_source, fehlt dem 100/10MBit/s-Port beider Geräte eine entsprechende Hardware-Warteschlange. Dies bedeutet, dass zwar alle Schnittstellen beider Geräte die Zeitsynchronisierung unterstützen, jedoch nur der enet1g-Port des phyBOARD-Atlas über geeignete Hardware für #acr("TSN")-Support im weiteren Sinne verfügt.

Zusätzlich verfügt jede Ethernet-Schnittstelle über einen eigenen #acr("MAC") und somit auch über eine eigene #acr("PTP")-Clock. Daher ist die relative Zeit von Port zu Port immer unterschiedlich. Im #acr("gPTP")-Stack wird allerdings immer nur die Clock zum zugehörigen Port synchronisiert. Dies führt dazu, dass der Master-Port auf der Bridge nicht synchronisiert ist und dadurch die nachfolgenden Systeme nicht korrekt synchronisieren kann. Um dieses Problem zu lösen, wird ein dedizierter Task in Zephyr erstellt, der sich um das Synchronisieren des Master-Ports zum Slave-Port auf der Bridge kümmert. Die Implementierung dieses Tasks beschreibt @bridge-sync-impl.

Da in dieser Arbeit ausschließlich die Bridgefunktion validiert werden soll, muss die als Grandmaster Clock eingesetzte Hardware selbst keine Anbindung an eine externe Referenzzeit besitzen und wird stattdessen im Free-Running-Mode betrieben. Alle übrigen Geräte synchronisieren sich wie in @tsn-intro beschrieben ausschließlich auf diese lokale Zeitbasis. Die dafür nötigen #acr("gPTP")-Nachrichten werden dabei nach den Standardwerten mit 1Hz für pDelay und 8Hz für Sync versendet.

== Messmethodik <messmethodik>
Die zuvor abgeleiteten Anforderungen sind nur dann aussagekräftig, wenn sich ihre Einhaltung auch nachweisen lässt. Dieser Abschnitt beschreibt deshalb, mit welchen Verfahren die einzelnen Anforderungen am Testaufbau überprüft werden.

Den Kern bildet eine #acr("PPS")-basierte Messung, mit der sich der tatsächliche Zeitversatz zwischen den Clocks unabhängig vom #acr("gPTP")-Stack selbst messen lässt. Zunächst werden dazu der Messaufbau und die Datenerfassung vorgestellt. Da sich nicht alle Anforderungen über den #acr("PPS")-Offset abbilden lassen, werden anschließend die ergänzenden Nachweisverfahren für die rateRatio-Genauigkeit und für die Pufferversorgung des #acr("gPTP")-Pfads unter Last beschrieben. Abschließend wird festgelegt, wie die aufgenommenen Offset-Zeitreihen statistisch ausgewertet werden und ab wann eine Anforderung als erfüllt gilt.

=== Messaufbau und Datenerfassung <messaufbau-datenerfassung>
Um die tatsächlich erreichte Synchronisierungsgenauigkeit des Testaufbaus zu überprüfen, reicht eine rein softwareseitige Betrachtung der berechneten Offsets nicht aus, da diese bereits durch den Synchronisierungsalgorithmus korrigiert werden. Zudem würden systematische Messfehler innerhalb eines Controllers auf diese Weise nicht auffallen, da dieselben Fehler sowohl die #acr("gPTP")-Synchronisation selbst als auch eine rein softwareseitige Messung ihrer Genauigkeit gleichermaßen verfälschen würden. Stattdessen wird die Synchronisierung über einen unabhängigen Hardware-Trigger am jeweiligen Mikrocontroller nachgewiesen. Die zu vergleichenden Clocks legen jeweils ein #acr("PPS")-Signal auf einen #acr-emph("GPIO")-Pin, also einen Impuls, der immer genau beim Rollover zur nächsten Sekunde ausgelöst wird. Da dieser Impuls direkt aus dem internen Timer der Clock abgeleitet wird, ist er unabhängig vom #acr("gPTP")-Stack. Die zeitliche Differenz zweier #acr("PPS")-Flanken entspricht dem tatsächlichen Offset zwischen den beiden Clocks und lässt sich extern messen@nguyen2020fuzzypi.

Für die Erfassung wird ein Oszilloskop mit vier Kanälen eingesetzt. Einer dieser Kanäle ist in jeder Messung fest dem #acr("GM") zugeordnet, da deren Clock die Referenz ist, auf die sich alle übrigen Geräte synchronisieren. Die verbleibenden drei Kanäle werden je nach Messziel unterschiedlich belegt.

Da das Oszilloskop selbst zur Messkette gehört, muss dessen zeitliche Auflösung deutlich feiner sein als die kleinste zu prüfende Anforderung. Andernfalls würde die Quantisierung des Messgeräts das Messergebnis verfälschen, statt es nur abzubilden. Das eingesetzte Oszilloskop muss folglich eine Zeitbasis im niedrigen Nanosekundenbereich auflösen, damit die $40n s$-Anforderung überhaupt nachweisbar ist. Zum Einsatz kommt ein Keysight MSOX3104T@keysight_msox3104t mit $1"GHz"$ Bandbreite und einer Abtastrate von $5"GSa/s"$, was einem zeitlichen Abstand von $200p s$ zwischen zwei Samples entspricht und damit deutlich unterhalb der geforderten $40n s$ liegt.

Die #acr("PPS")-Flanken der belegten Kanäle werden dabei jeweils gleichzeitig über eine Länge von 1000 #acr("PPS")-Perioden aufgenommen und als Rohdaten exportiert. Ein Auswertungsskript berechnet aus jedem erfassten Flankensatz sowohl den Offset jedes Kanals relativ zum #acr("GM") als auch die Differenz zwischen benachbarten Kanälen (Hop-zu-Hop-Offset). Welche der beiden Größen im Vordergrund steht, hängt vom jeweiligen Messziel ab. Der #acr("GM")-relative Offset weist die kumulative #acr-emph("E2E")-Synchronisationsgenauigkeit der gesamten Kette nach, während der Hop-zu-Hop-Offset den Beitrag einer einzelnen Bridge isoliert und damit erlaubt, Effekte wie die #acr-emph("PHY")-Asymmetrie aus @Ungenauigkeiten einer konkreten Bridge zuzuordnen. Für jeden Offset ergibt sich damit eine Zeitreihe über die gesamte Messdauer, die als Diagramm über der Zeit dargestellt wird.

In diesen Diagrammen ist unabhängig vom Messziel ein charakteristischer Verlauf zu erwarten. Direkt nach dem Start bzw. Link-Up ist der Offset zwischen den Clocks zunächst groß, da noch keine Synchronisierung stattgefunden hat. Mit fortschreitender Regelung durch den Synchronisierungsalgorithmus sinkt der Offset über mehrere Sync-Intervalle hinweg, bis er in einen stabilen Zustand übergeht. Dieser Einschwingvorgang macht die Regelung des Synchronisierungsalgorithmus sichtbar. Der Offset läuft dabei nicht exakt gegen null, sondern pendelt im eingeschwungenen Zustand innerhalb eines kleinen Reststreubands. Für den #acr("GM")-relativen Offset ist dessen maximal zulässige Breite direkt durch die #acr-emph("E2E")-Synchronisationsgenauigkeit aus @normative-leistungsanforderungen vorgegeben.

Neben der PPS-Messung existiert für Anforderungen, die sich nicht allein über den PPS-Offset nachweisen lassen, eine zweite Datenerfassung. Über die UART-Shell von Zephyr werden Logs aufgezeichnet, welche mehr Details über das System preisgeben. Das Logging läuft dabei über die gesamte Laufzeit mit und liefert Daten, die für den jeweiligen Nachweis eine genauere oder unabhängige Aussage erlauben. Welche Daten das im Einzelnen sind und wie sie ausgewertet werden, wird in den jeweiligen Abschnitten @nachweis-rateratio und @nachweis-pufferversorgung beschrieben.

=== Kanalbelegung je Messziel <kanalbelegung>
Welche Messpunkte auf die drei frei belegbaren Kanäle gelegt werden, richtet sich nach der Länge der zu vermessenden Kette.

Bei einer einzelnen Bridge genügt ein Lauf für beide Größen: Belegt man die Kanäle mit #acr("GM"), Slave-Port und Master-Port derselben Bridge sowie dem Endpoint, liefert derselbe Flankensatz sowohl den #acr("GM")-relativen Offset jedes Messpunkts als auch den isolierten Hop-zu-Hop-Offset dieser Bridge. Letzterer steht dabei im Vordergrund, unabhängig davon, an welcher Stelle der Kette die Bridge später eingesetzt wird.

Sobald mehr als eine Bridge im System ist, reichen vier Kanäle nicht mehr aus, um die gesamte Kette gleichzeitig zu erfassen. Da die #acr-emph("E2E")-Synchronisationsgenauigkeit laut Standard aber kumulativ über die Kette gilt und der Testaufbau mit maximal vier Hops innerhalb der zulässigen sieben bleibt, wird die Kette in mehreren Läufen mit wechselnder Kanalbelegung durchgemessen. Die Kanäle für #acr("GM") und Endpoint bleiben dabei über alle Läufe fest belegt, sodass sich die Läufe über diese gemeinsame Referenz zusammenführen lassen. Im Vordergrund steht hier entsprechend der #acr("GM")-relative Offset.

=== Nachweis der rateRatio-Genauigkeit <nachweis-rateratio>
Die #acr("PPS")-Messung weist die #acr-emph("E2E")-Synchronisationsgenauigkeit nach, eignet sich aber nicht für den Nachweis der beiden Frequenzanforderungen #req("A3") und #req("A8"). Beide sind Frequenzgrößen und werden deshalb über die #gls("allan")[Allan-Abweichung] der jeweils geloggten Messreihe erbracht @allan1966statistics @riley2008frequencystability[5.2.2].

Nachzuweisen sind dabei zwei getrennte Größen, die im selben Lauf erfasst werden. Für #req("A3") ist es die vom #acr("gPTP")-Stack je Port aus dem pDelay-Mechanismus geschätzte `neighborRateRatio`, für #req("A8") die vom bridge-internen Servo aufgeprägte Ratenkorrektur. Beide sind fraktionale Frequenzabweichungen und damit gegen denselben Grenzwert prüfbar, unterscheiden sich inhaltlich aber grundlegend: Die erste ist eine Messung, die zweite eine Stellgröße.

In dieser Arbeit wird dazu wie folgt vorgegangen:

1. Einschwingzeit abwarten, damit sich die jeweilige Regelung auf einen stabilen Zustand einschwingen kann.

2. Beide Größen über einen definierten Zeitraum messen und loggen.

3. Aus den Messungen wird die Abweichung von der geforderten Genauigkeit geprüft, indem die Allan-Abweichung $sigma_y (tau)$ der rateRatio-Messreihe berechnet wird. Da rateRatio bereits eine über das Messintervall $tau$ gemittelte Frequenzschätzung ist, wird dazu die Varianz der Differenzen aufeinanderfolgender Werte gebildet, statt die Streuung um den Gesamtmittelwert zu betrachten wie bei der klassischen Standardabweichung. Für die bei Quarzoszillatoren typischen Rauschprozesse (z. B. Flicker- oder Random-Walk-Frequenzrauschen) konvergiert die klassische Varianz nicht zuverlässig und wird durch langsamen Drift verfälscht, während die Allan-Varianz dagegen robust ist @allan1966statistics, dasselbe Konzept (ADEV), das @ieee8021as2025[B.1.3.2] für die Rauschcharakterisierung der LocalClock referenziert @riley2008frequencystability[5.2.2]:

$
  sigma_y (tau) = sqrt(1/(2(M-1)) sum_(i=1)^(M-1) (y_(i+1) - y_i)^2)
$

Dabei ist $y_i$ die fraktionale Frequenzabweichung des $i$-ten Messintervalls und $M$ die Anzahl der gemessenen Intervalle. Für #req("A3") ist $y_i = "neighborRateRatio"_i - 1$, für #req("A8") die vom Servo gestellte Ratenkorrektur.

Das Mittelungsintervall $tau_0$ wird nicht angenommen, sondern aus den Zeitstempeln des Logs selbst bestimmt, da es sich aus der Aktualisierungsrate der jeweiligen Größe ergibt und nicht frei wählbar ist. Für den Servo folgt es aus den #acr("PPS")-Flanken, für die `neighborRateRatio` aus dem pDelay-Intervall. Beide liegen bei $tau_0 approx 1"s"$.

Die Einschwingzeit wird je Messreihe einzeln bestimmt und nicht pauschal vorgegeben. Das ist notwendig, weil die Reihen unterschiedlich schnell einschwingen. Ein gemeinsamer Startwert wäre für eine Auwertung zu spät und für die anderen zufrüh. Dies hätte zufolge, dass die Einschwingwerte mit in die Auswertung aufgenommen werden, was $sigma_y$ um Größenordnungen verfälscht. Als eingeschwungen gilt eine Reihe ab dem Sample nach der letzten Überschreitung eines Toleranzbands, das aus der Streuung des eingeschwungenen Zustands am Ende des Laufs geschätzt wird.

Liegt die berechnete Allan-Abweichung $sigma_y (tau_0)$ innerhalb der geforderten 0,1 #acr("ppm"), gilt die jeweilige Anforderung als erfüllt.

=== Nachweis der Pufferversorgung unter Last <nachweis-pufferversorgung>
Die #acr("PPS")-Messung zeigt, ob die Synchronisation unter Last erhalten bleibt, nicht aber, woran es liegt, wenn sie es nicht tut. Für den zweiten Teil von #req("A6"), dass #acr("gPTP")-Nachrichten auch unter Last durchgängig einen Empfangspuffer erhalten, wird deshalb ergänzend ein treiberinterner Zähler ausgewertet, der fehlgeschlagene Pufferallokationen auf dem #acr("gPTP")-Empfangspfad zählt (`alloc_fail_ptp`). Dieser wird während des Lasttests sekündlich mitgeloggt.

Anders als beim Nachweis über $t_"set"$ gibt es hier kein Einschwingverhalten und kein Toleranzband. Ausschlaggebend ist `alloc_fail_ptp`. Bleibt dieser treiberinterne, gPTP-spezifische Zähler über die gesamte Laufzeit bei null, gilt die Anforderung als erfüllt. Ein Anstieg der übrigen, globalen MAC-Zähler (#gls("statsRxFifoOverflowErr")[statsRxFifoOverflowErr], #gls("statsRxDropInvalidSFD")[statsRxDropInvalidSFD], #gls("statsRxCrcErr")[statsRxCrcErr], #gls("statsRxAlignErr")[statsRxAlignErr]) ist dagegen kein eigenständiger Verstoß. Sie unterscheiden nicht nach Verkehrsklasse und dürfen unter Last durch verworfenen Best-Effort-Verkehr durchaus ansteigen, solange davon ausschließlich der unkritische Verkehr betroffen ist und weder `alloc_fail_ptp` noch die PPS-basierte Synchronisationsgenauigkeit sich dadurch verschlechtern.

=== Statistische Auswertung <statistische-auswertung>
Aus den Offset-Zeitreihen der PPS-basierten Validierungsszenarien werden für das Kapitel Evaluation zwei Aspekte abgeleitet. Der eigentliche Nachweis, dass die #acr-emph("E2E")-Synchronisationsgenauigkeit aus @normative-leistungsanforderungen eingehalten wird, sowie eine Beschreibung des eingeschwungenen Zustands, auf die dort bei der Diskussion der in @Ungenauigkeiten benannten Fehlerquellen zurückgegriffen wird. Die rateRatio-Genauigkeit und die Pufferversorgung des #acr("gPTP")-Pfads werden dagegen über die in @nachweis-rateratio und @nachweis-pufferversorgung beschriebenen, ergänzenden Verfahren nachgewiesen.

*Läufe und Auswertungsintervalle*\
Ein einzelner Oszilloskop-Lauf ist auf 1000 #acr("PPS")-Perioden begrenzt (siehe "Messaufbau und Datenerfassung"), also rund 16,6 Minuten. Einzelbridge-Validierung, Kettenvalidierung und Netzwerklast-Test bleiben innerhalb dieses Fensters und liefern damit je eine durchgehende Zeitreihe pro Lauf. Die mehrstündige Langzeitmessung überschreitet dieses Fenster dagegen zwangsläufig und wird stattdessen durch mehrere über die Messdauer verteilte Läufe abgedeckt. Innerhalb eines Laufs kann es zudem mehrere Test-Cases geben, etwa die drei Laststufen in @netzwerklast-test. Die folgende Auswertung bezieht sich deshalb nicht auf den Lauf als Ganzes, sondern auf das jeweilige Auswertungsintervall. Bei einem Lauf mit nur einem Test-Case ist das der gesamte gültige Bereich nach $t_"set"$, bei mehreren Laststufen je Laststufe, bei der Langzeitmessung je Lauf.

*Nachweis*\
Die Anforderung aus @normative-leistungsanforderungen gilt als erfüllt, sobald eine Einschwingzeit $t_"set"$ existiert. Der früheste Zeitpunkt, ab dem der Offset das dadurch vorgegebene $1mu s$-Toleranzband nicht mehr verlässt und darin bis zum Ende des Laufs verbleibt. Eine einzelne, kurzzeitige Unterschreitung des Toleranzbands zählt nicht als Einschwingen, da sie nur zufällig getroffen sein kann. Bei der aus mehreren Läufen zusammengesetzten Langzeitmessung wird $t_"set"$ aus dem ersten Lauf bestimmt. Jeder folgende Lauf muss zusätzlich vollständig innerhalb des Toleranzbands liegen. Verlässt der Offset das Band in einem späteren Lauf erneut, obwohl $t_"set"$ bereits erreicht war, gilt die Anforderung als nicht erfüllt.

*Vergleichende Darstellung*\
Innerhalb eines Auswertungsintervalls werden die Messpunkte als Boxplots nebeneinander dargestellt. Die Wahl von Median und Interquartilsabstand anstelle von Mittelwert und Standardabweichung ist dabei bewusst. Beide Kennzahlen sind robust gegenüber einzelnen Ausreißern @fahrmeir2024statistik, wie sie hier durch vereinzelte Paketverluste oder fehlende #acr("PPS")-Flanken zu erwarten sind, und beschreiben die Lage des eingeschwungenen Bands deshalb zuverlässiger als momentbasierte Kennzahlen. Median, Interquartilsabstand und Ausreißer sind für jeden Messpunkt auf einen Blick vergleichbar, ohne die einzelnen Offset-Zeitreihen übereinanderlegen zu müssen. Ein kurzzeitiger Paketverlust fällt so als einzelner Ausreißer auf. Bei Läufen mit mehreren Auswertungsintervallen lässt sich dieselbe Darstellung zusätzlich nutzen, um einen Messpunkt über die Intervalle hinweg zu vergleichen und so einen systematischen Trend von Median oder Streuung sichtbar zu machen.

Jedes Auswertungsintervall muss dabei lang genug sein, um nach $t_"set"$ noch mehrere hundert #acr("PPS")-Perioden für die Statistik zu liefern, damit Median, Interquartilsabstand und die übrigen Boxplot-Kennzahlen nicht mehr nennenswert vom Stichprobenumfang abhängen.

// === Fehlerbudget-Betrachtung <nachweis-fehlerbudget>
// Über den reinen Erfüllt/Nicht-erfüllt-Nachweis aus @normative-leistungsanforderungen hinaus wird der gemessene Offset zusätzlich in seine einzelnen Fehlerbeiträge zerlegt. Dazu wird das $1mu s$-Toleranzband aus B.3 als Fehlerbudget aufgefasst. Der Standard selbst leitet diese Grenze bereits über eine Zerlegung in einzelne Fehlerbeiträge her @ieee8021as2025[B]. Gegenüber diesem Budget lassen sich einzelne, unabhängig voneinander messbare Fehlerquellen, etwa die LocalClock-Granularität, der Servo-Restfehler der bridge-internen Synchronisierung oder die Auflösung der Messkette selbst, jeweils als Anteil in Nanosekunden und in Prozent ausdrücken. Da die Beiträge unterschiedlichen, teils unbekannten Verteilungen folgen und nicht als unabhängig vorausgesetzt werden können, werden sie nicht statistisch, sondern linear zu einer oberen Schranke aufsummiert. Ein Vorgehen, das Bailleul et al. für die Worst-Case-Synchronisationsgenauigkeit von #acr("IEEE") 802.1AS in ähnlicher Form anwenden @bailleul2023etfa. Bleibt die Summe der quantifizierten Einzelbeiträge deutlich unterhalb des Budgets und konsistent mit dem tatsächlich gemessenen Gesamtoffset, stützt dies die Konsistenz der übrigen Nachweise.

== Ungenauigkeiten<Ungenauigkeiten>
Der pDelay-Mechanismus aus @pDelay-mechanism setzt voraus, dass die Signallaufzeit zwischen zwei Ports in beide Richtungen symmetrisch ist @ieee8021as2025[11.2]. Nur unter dieser Annahme lässt sich aus der Summe $t_4 - t_1$ und $t_3 - t_2$ ein einseitiger meanLinkDelay berechnen. Der vorliegende Testaufbau verletzt jedoch diese Annahme. Wie in @testaufbau beschrieben, verfügt der 1Gbit #acr("PHY") über eine #acr("SFD")-Erkennung. Die beiden 10/100Mbit #acrpl("PHY") besitzen diese Funktion jedoch nicht. Alles, was in einem Ethernet-Frame vor dem #acr("SFD") steht, liegt dadurch innerhalb des Zeitstempels. Zusätzlich ist diese interne Verarbeitungszeit zwischen Sende- und Empfangsrichtung nicht notwendigerweise gleich groß, wodurch die Symmetrieannahme des pDelay-Mechanismus zusätzlich verletzt wird. Diese Asymmetrie erklärt, warum an Hops mit einem 10/100Mbit #acr("PHY") ein deutlich höherer meanLinkDelay gemessen wird.
