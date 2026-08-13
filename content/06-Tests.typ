#import "../meta.typ": acr-emph, fig-platzhalter-mittel, note, tab-d, tab-h
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Tests
== Basisvalidierung <basisvalidierung>
Um eine umfangreiche Validierung der Bridge durchführen zu können, müssen zunächst die Grundlagen validiert werden, auf denen die nachfolgenden Tests aufbauen.

Ziel des Tests ist es nachzuweisen, dass eine einzelne Bridge zwischen Grandmaster und Endpoint unter Idealbedingungen sowohl die #acr-emph("E2E")-Synchronisationsgenauigkeit (@normative-leistungsanforderungen) als auch die rateRatio-Genauigkeit der bridge-internen Synchronisierung (@nachweis-rateratio) einhält. Darüber hinaus wird derselbe Lauf genutzt, um die `residence time` der Bridge zu vermessen und daraus zu beziffern, welchen Anteil am zulässigen Gesamtfehler die bridge-interne Synchronisierung tatsächlich beansprucht.

=== Testaufbau
Der Aufbau folgt der Kette Grandmaster $<->$ Bridge 1 $<->$ Endpoint mit der Kanalbelegung #acr("GM"), Slave-Port und Master-Port der Bridge sowie dem Endpoint. Zeitgleich zur PPS-Aufnahme läuft eine Logging-Aufzeichnung des bridge-internen Servos (`ptp_bridge_servo`, siehe @bridge-sync-impl).

=== Ergebnisse

#figure(
  image("../assets/Tests/pps_boxplot_basisvalidierung.png", width: 100%),
  caption: [Basisvalidierung - PPS-Offset als Boxplot],
) <fig-basisvalidierung-boxplot>

Alle drei Messpunkte erreichen ihren eingeschwungenen Zustand $t_"set"$ recht früh im Lauf. Der Slave-Port der Bridge bei Segment $9$, Master-Port der Bridge bei Segment $31$ und der Endpoint bei Segment $69$. Danach verbleiben diese durchgehend innerhalb des $1mu s$-Toleranzbands. Die Anforderung ist damit an allen drei Messpunkten erfüllt. Vor dem jeweiligen $t_"set"$ treten vereinzelte PPS-Ausfälle auf (z. B. sechs aufeinanderfolgende fehlende Segmente am Slave-Port zu Beginn), die sich mit dem Einrasten der Synchronisierung erklären und nicht mehr in den Nachweis eingehen.

Die Boxplots in @fig-basisvalidierung-boxplot beziehen sich auf das jeweils gültige Fenster ab $t_"set"$. Median und Interquartilsabstand (die mittleren 50 % der Proben) liegen am Slave-Port bei $141"ns"$ bzw. $47"ns"$, am Master-Port bei $177"ns"$ bzw. $55"ns"$ und am Endpoint bei $-114"ns"$ bzw. $65"ns"$. An allen drei Messpunkten liegen sowohl der Median als auch die gesamte Box damit deutlich innerhalb des $1mu s$-Toleranzbands.

Neben der PPS-basierten Synchronisationsgenauigkeit wird im selben Lauf auch die rateRatio-Genauigkeit des bridge-internen Synchronisierung nachgewiesen:

#figure(
  image("../assets/Tests/rate_ratio_allan_basisvalidierung.png", width: 100%),
  caption: [ppb-Verlauf des internen Servos, Basisvalidierung Einzelbridge],
) <fig-basisvalidierung-rate-ratio>

Im aufgezeichneten Lauf tritt genau ein `HARD_STEP` der Slave-Clock der Bridge auf ($t approx 5"s"$, siehe @fig-basisvalidierung-rate-ratio). Danach schwingt der #acr("PI")-Regler bis $t approx 125"s"$ auf einen stabilen Wert um $84000$#acr("ppb") ein. Ab diesem Zeitpunkt verbleiben $908$ Proben für die Allan-Abweichung nach @nachweis-rateratio. Aus den gesammelten Daten lässt sich für $tau = 1"s"$ (siehe @nachweis-rateratio) $sigma_y (tau) =$23,3214$$#acr("ppb") bestimmen. Dieser Wert liegt deutlich innerhalb der geforderten $0,1$ #acr("ppm") ($100$#acr("ppb")), womit die Anforderung als erfüllt gilt.

Als unabhängige Plausibilisierung wird das geloggte `phase_error` (Slave- $minus$ Master-Zeitstempel) gegen den zeitgleich per PPS gemessenen Hop-Offset zwischen Master- und Slave-Port desselben Laufs verglichen. Über $762$ überlappende Segmente weichen beide Größen im Mittel um nur $32.7"ns"$ voneinander ab, bei einer Streuung von $62,6"ns"$. Beide Messverfahren stützen sich damit gegenseitig.

Über die reine Einhaltung der Grenzwerte hinaus erlaubt derselbe Lauf, den Beitrag der bridge-internen Synchronisierung zum Gesamtfehler zu beziffern. Maßgeblich dafür ist die `residence time`: Sie wird nach @sync-mechanism als Differenz $t_s - t_r$ gebildet, und ihre beiden Zeitstempel entstehen auf verschiedenen Clocks. $t_r$ auf der Clock des Slave-Ports und $t_s$ auf der des Master-Ports. Jede Abweichung zwischen diesen beiden Clocks geht damit unmittelbar in das `correctionField` und über die gesamte Kette weiter.

#figure(
  image("../assets/Tests/bridge1_residenceTime.png", width: 100%),
  caption: [Residence time und Phasenfehler der Bridge, Basisvalidierung Einzelbridge],
) <fig-basisvalidierung-residence>

Die Bridge benötigt im Durchschnitt $5,19"ms"$, um eine Sync-Nachricht weiterzuleiten. Bei einem Sync-Intervall von $125"ms"$ entspricht dies rund $4%$ des Intervalls. Für die Synchronisationsgenauigkeit ist die
se vergleichsweise lange Verweilzeit zunächst unkritisch, da jede Sync-Nachricht ihren eigenen, individuell gemessenen Wert im `correctionField` mitführt und der Empfänger ihn vollständig herausrechnet. Entschei
dend ist deshalb nicht die Höhe der `residence time`, sondern die Genauigkeit ihrer Messung, und genau diese wird durch die beiden Fehlerarten des internen Servos begrenzt.

Ein Phasenfehler zwischen den beiden Clocks geht additiv in die `residence time` ($t_("res")$) ein, ein Frequenzfehler $epsilon$ dagegen skaliert mit ihr. Aus der gemessenen Verweilzeit lässt sich damit eine Schranke für den zulässigen Frequenzfehler herleiten. Damit der Frequenzanteil höchstens $1%$ des $1mu s$-Budgets aus @normative-leistungsanforderungen beansprucht, muss der  Frequenzfehler $epsilon < 1,93$ #acr("ppm") gelten. Die im selben Lauf bestimmte Allan-Abweichung von $28,3$ #acr("ppb") unterschreitet diese Schranke und trägt lediglich $0,15"ns"$ bei. Der Phasenfehler dominiert damit deutlich. Er liegt im Auswertungsfenster im Median bei $1"ns"$ und erreicht eine maximal Offset von $113"ns"$ bei einer Streuung von $35"ns"$. Beide Beiträge zusammen belegen im ungünstigsten Fall $113,1"ns"$ und damit $11,3%$ des zulässigen #acr-emph("E2E")-Budgets. Die bridge-interne Synchronisierung trägt damit nur einen geringen Anteil zu der in @fig-basisvalidierung-boxplot gezeigten Genauigkeit bei.

=== Einordnung und Ausblick
Beide Anforderungen sind für die Einzelbridge erfüllt: die #acr-emph("E2E")-Synchronisationsgenauigkeit an allen drei Messpunkten und die rateRatio-Genauigkeit der bridge-internen Synchronisation. Die Fehlerbetrachtung ergänzt dieses Ergebnis um eine quantitative Einordnung, denn der gesamte Beitrag der bridge-internen Synchronisierung bleibt mit rund $11%$ des zulässigen Budgets deutlich unterhalb der Grenze und wird dabei vom Phasen-, nicht vom Frequenzfehler bestimmt. Damit ist die Grundlage gelegt, auf der die nachfolgenden Tests aufbauen.


== Validierung über mehrere Hops <mehrhop-validierung>
Die Basisvalidierung hat gezeigt, dass eine einzelne Bridge die geforderten Genauigkeiten einhält. Die geforderte #acr-emph("E2E")-Synchronisationsgenauigkeit von $<=1mu s$ bezieht sich allerdings auf eine Kette von bis zu sieben Hops. Jede zusätzliche Bridge kann dabei eigene Fehlerbeiträge mit sich bringen. Insbesondere die Ungenauigkeit ihrer `residence time`-Messung, die Restabweichung der bridge-internen Synchronisierung (@bridge-sync-impl) sowie die in @Ungenauigkeiten beschriebene #acr-emph("PHY")-Asymmetrie. Ob sich diese Beiträge über mehrere Hops hinweg unkritisch verhalten oder sich systematisch aufsummieren, lässt sich an einer Einzelbridge nicht beantworten.

Ziel dieses Tests ist es daher nachzuweisen, dass die #acr("E2E")-Synchronisationsgenauigkeit auch bei der maximal aufbaubaren Kettenlänge eingehalten wird, und darüber hinaus sichtbar zu machen, wie sich der Offset mit jedem zusätzlichen Hop entwickelt.

=== Testaufbau
Um den Beitrag jeder einzelnen Bridge isolieren zu können, wird die Kette Bridge für Bridge erweitert. Ausgehend von der bereits in @basisvalidierung vermessenen Konfiguration wird pro Ausbaustufe eine weitere Bridge zwischen die letzte Bridge und den Endpoint geschaltet, bis alle drei zur Verfügung stehenden Bridges Teil der Kette sind. @tab-mehrhop-stufen fasst die daraus resultierenden Ausbaustufen zusammen.

#figure(
  table(
    columns: (1fr, 3fr, 0.5fr),
    align: (left, left, left),
    stroke: none,
    table.hline(),
    tab-h[Stufe], tab-h[Kette], tab-h[Hops],
    table.hline(stroke: 0.5pt),
    tab-d[2], tab-d[#acr("GM") $<->$ Bridge 1 $<->$ Bridge 2 $<->$ Endpoint], tab-d[3],
    table.hline(stroke: 0.2pt + luma(80)),
    tab-d[3], tab-d[#acr("GM") $<->$ Bridge 1 $<->$ Bridge 2 $<->$ Bridge 3 $<->$ Endpoint], tab-d[4],
    table.hline(),
  ),
  caption: [Abstufung der Kettenvalidierung],
) <tab-mehrhop-stufen>

#note[Konkrete Kanalbelegung je Stufe ergänzen. Probe 2 und 3 immer an die letzte Bridge. Probe 1 bleibt immer GM (Referenz) und Probe 4 Endpoint.]

Alle Läufe finden unter denselben Idealbedingungen wie in @basisvalidierung statt. Damit bleibt die Kettenlänge die einzige Variable.

=== Ergebnisse

Analog zur Basisvalidierung wird je Ausbaustufe zunächst der zeitliche Offsetverlauf und anschließend die Verteilung im eingeschwungenen Zustand betrachtet. Die 1. Stufe mit nur einer Bridge wurde bereits in @basisvalidierung ausgewertet. Die folgenden beiden Abschnitte ergänzen Stufe 2 und Stufe 3. Kanal 2 und 3 des Oszilloskops liegen dabei jeweils an Slave- und Master-Port der letzten Bridge in der Kette an, Kanal 4 durchgehend am Endpoint. \ \ \ \ \ \ \ \

*Stufe 2 (GM $<->$ Bridge 1 $<->$ Bridge 2 $<->$ Endpoint)*

#figure(
  image("../assets/Tests/bridge2_pps_offset.png", width: 100%),
  caption: [Stufe 2 - PPS-Offset zum Grandmaster über der Zeit],
) <fig-mehrhop-stufe2-verlauf>

Wie schon in der Basisvalidierung durchlaufen alle drei Messpunkte zu Beginn eine Einschwingphase. Die Messpunkte erreichen dabei ihren eingeschwungenen Zustand $t_"set"$ nicht gleichzeitig, spätestens jedoch bei Segment $45$ sind alle drei eingeschwungen. Danach verbleiben Slave- und Master-Port von Bridge 2 durchgehend in einem engen Band um den #acr("GM"), der Endpoint in einem dazu versetzten Band um rund $-290"ns"$.

#figure(
  image("../assets/Tests/Bridge2_boxplot.png", width: 100%),
  caption: [Stufe 2 - PPS-Offset als Boxplot, eingeschwungener Zustand],
) <fig-mehrhop-stufe2-boxplot>

Im ausgewerteten Fenster ab $t_"set"$ liegen Median und Interquartilsabstand am Slave-Port von Bridge 2 bei $-5,8"ns"$ bzw. $58,3"ns"$ ($n=876$), am Master-Port bei $25,4"ns"$ bzw. $64,1"ns"$ ($n=840$) und am Endpoint bei $-288,0"ns"$ bzw. $70,7"ns"$ ($n=909$). Damit bleibt die #acr-emph("E2E")-Genauigkeit über drei Hops deutlich innerhalb des $1mu s$-Toleranzbands.
\ \ \ \ \ \ \ \ \ \ \ \
*Stufe 3 (GM $<->$ Bridge 1 $<->$ Bridge 2 $<->$ Bridge 3 $<->$ Endpoint)*

#figure(
  image("../assets/Tests/bridge3_pps_offset.png", width: 100%),
  caption: [Stufe 3 - PPS-Offset zum Grandmaster über der Zeit],
) <fig-mehrhop-stufe3-verlauf>

Die Einschwingphase fällt mit einem zusätzlichen Hop änlich zur Stufe 2 aus. Auch hier erreichen die drei Messpunkte $t_"set"$ nicht gleichzeitig. Der Slave-Port von Bridge 3 bereits bei Segment $6$, der Master-Port erst bei Segment $45$, spätestens jedoch bei Segment $60$ sind alle eingeschwungen. Danach verbleiben alle drei Messpunkte durchgehend in einem stabilen, gegenüber Stufe 2 leicht nach unten verschobenen Band, ohne erkennbare Lücken oder wiederkehrende Ausreißer über den restlichen Lauf.

#figure(
  image("../assets/Tests/bridge3_boxplot.png", width: 100%),
  caption: [Stufe 3 - PPS-Offset als Boxplot, eingeschwungener Zustand],
) <fig-mehrhop-stufe3-boxplot>

Im eingeschwungenen Fenster liegen Median und Interquartilsabstand am Slave-Port von Bridge 3 bei $-153"ns"$ bzw. $75"ns"$, am Master-Port bei $-113"ns"$ bzw. $81"ns"$ und am Endpoint bei $-428"ns"$ bzw. $82"ns"$. Auch nach vier Hops bleibt die #acr-emph("E2E")-Genauigkeit damit klar innerhalb der geforderten $1mu s$.

=== Einordnung und Ausblick

Über alle drei Ausbaustufen hinweg bleibt die #acr-emph("E2E")-Synchronisationsgenauigkeit zum Grandmaster am Endpoint durchgehend innerhalb des geforderten $1mu s$-Toleranzbands. $-114"ns"$ bei einem Hop (@basisvalidierung), $-288"ns"$ bei zwei Hops und $-428"ns"$ bei drei Hops. Der Zuwachs pro zusätzlichem Hop beträgt damit rund $173"ns"$ (Stufe 1 $->$ 2) und rund $141"ns"$ (Stufe 2 $->$ 3). Der Fehler wächst also weder unkontrolliert noch überlinear, sondern eher leicht sublinear, bei gleichzeitig nur moderat wachsender Streuung (Endpoint-IQR $65"ns"$, $70"ns"$, $82"ns"$). Für die drei tatsächlich aufgebauten Stufen ist die Bridge-Funktionalität im Sinne von Annex B.3 damit nachgewiesen. Eine abschließende Aussage über eine vollständige Kette von $7$ Hops lässt sich hier allerdings nicht treffen. Man erkennt einen deutlichen Abwärtstrend des Offsets, der bei drei Hops bereits rund $400"ns"$ Abweichung vom Grandmaster ergibt. Kommen  dazu noch weiteren vier Hops hinzu, lässt sich auf dieser Datenbasis nicht ausschließen, dass die geforderte $1mu s$-Grenze überschritten wird.

Die vorliegenden Läufe fanden durchgehend unter denselben Idealbedingungen wie die Basisvalidierung statt. Der nachfolgende Abschnitt prüft, ob dieselbe #acr-emph("E2E")-Anforderung auch über eine deutlich längere Messdauer hinweg eingehalten wird.

== Langzeitmessung <langzeitmessung>
Die bisherigen Läufe sind durch die Aufzeichnungslänge des Oszilloskops auf jeweils 1000 #acr("PPS")-Perioden begrenzt, also rund 16,6 Minuten. Damit lässt sich zwar die Synchronisationsgenauigkeit selbst, nicht aber ihre Stabilität über deutlich längere Zeiträume hinweg beurteilen. Ziel dieses Tests ist es deshalb, die vollständige Kette aus @mehrhop-validierung über mehrere Stunden hinweg zu beobachten und zu prüfen, ob die #acr-emph("E2E")-Synchronisationsgenauigkeit nach @normative-leistungsanforderungen auch über diesen Zeitraum durchgehend eingehalten wird.

=== Testaufbau
Der Aufbau entspricht Stufe 3 aus @mehrhop-validierung (#acr("GM") $<->$ Bridge 1 $<->$ Bridge 2 $<->$ Bridge 3 $<->$ Endpoint). Da dem Oszilloskop nach @kanalbelegung nur vier Kanäle zur Verfügung stehen, bleiben Kanal 1 (#acr("GM"), Referenz) und Kanal 4 (Endpoint) für die gesamte Messdauer fest belegt, während die Kanäle 2 und 3 reihum an Slave- und Master-Port der jeweiligen Bridge angeschlossen werden. Jeder Einzellauf ist wie bisher auf 1000 #acr("PPS")-Perioden begrenzt. Nach jedem Durchlauf gibt es eine etwa 16 Minütige Pause, bevor die nächste Aufzeichnung losgeht. Die Langzeitmessung setzt sich deshalb aus zwölf Läufen zusammen und erstrecken sich insgesamt auf eine Zeit on ca. 6,5 Stunden.

=== Ergebnisse

#figure(
  image("../assets/Tests/PPS-Offset-langzeit.png", width: 100%),
  caption: [PPS-Offset zum Grandmaster über rund 6,5 Stunden],
) <fig-langzeit-verlauf>

@fig-langzeit-verlauf zeigt den Offset aller Messpunkte über die gesamte Messdauer. Der Endpoint (violett) ist in jedem der zwölf Läufe vertreten und verbleibt durchgehend in einem stabilen Band von etwa $-600$ bis $-150"ns"$, ohne dass zwischen dem ersten Lauf bei $t approx 0"h"$ und dem letzten bei $t approx 6,4"h"$ ein erkennbarer Trend sichtbar wird. Auch an den rotierenden Messpunkten der drei Bridges zeigt sich innerhalb der ihnen jeweils zugeordneten vier Läufe keine fortschreitende Verschiebung. Die Synchronisation blieb somit über die gesamten 6 Stunden erhalten. Zudem macht sich kein Drift bemerkbar, der sich erst über Stunden sichtbar macht.

#figure(
  image("../assets/Tests/boxplot_langzeit.png", width: 100%),
  caption: [PPS-Offset als Boxplot über die gesamte Langzeitmessung],
) <fig-langzeit-boxplot>

@fig-langzeit-boxplot fasst dieselben Daten je Messpunkt über die gesamte Langzeitmessung als Boxplot zusammen. Median und Interquartilsabstand liegen am Slave- bzw. Master-Port von Bridge 1 bei $122,8"ns"$/$39,7"ns"$ und $155,6"ns"$/$45,6"ns"$, an Bridge 2 bei $-24,9"ns"$/$55,2"ns"$ und $7,2"ns"$/$63,4"ns"$, an Bridge 3 bei $-153,4"ns"$/$76,9"ns"$ und $-119,9"ns"$/$83,2"ns"$, und am Endpoint bei $-420,1"ns"$/$94,4"ns"$. Wie schon in @mehrhop-validierung wächst die Streuung mit jedem zusätzlichen Hop leicht an, bleibt aber selbst am Endpoint mit einem IQR von rund $94"ns"$ klein gegenüber dem $1mu s$-Toleranzband. Vereinzelte Ausreißer (rote Kreise) treten an allen Messpunkten auf, verlassen das Toleranzband jedoch nie und zählen damit nach "Statistische Auswertung" nicht als Verletzung der Anforderung.

=== Einordnung und Ausblick
Die über die gesamte Langzeitmessung gebildeten Kennzahlen liegen nahe an den für Stufe 3 der Kettenvalidierung in @mehrhop-validierung ermittelten Werten (dort Bridge 3: $-153"ns"$/$75"ns"$ und $-113"ns"$/$81"ns"$, Endpoint: $-428"ns"$/$82"ns"$; hier $-153,4"ns"$/$76,9"ns"$, $-119,9"ns"$/$83,2"ns"$ und $-420,1"ns"$/$94,4"ns"$). Die Langzeitmessung bestätigt damit im Wesentlichen das Bild aus dem rund 17-minütigen Einzellauf, ohne dass über Stunden hinweg ein zusätzlicher, erst bei längerer Laufzeit sichtbarer Fehleranteil hinzukommt. Die #acr-emph("E2E")-Synchronisationsgenauigkeit nach @normative-leistungsanforderungen ist damit auch über den in Annex B nicht weiter spezifizierten längeren Zeitraum hinweg durchgehend erfüllt.

@fig-langzeit-boxplot bestätigt darüber hinaus, über eine deutlich breitere Datenbasis als in @mehrhop-validierung, den dort bereits beobachteten Trend. Mit jeder weiteren Bridge in der Kette verschiebt sich der Offset zum Grandmaster sichtbar weiter von der Referenz weg. Von rund $140"ns"$ an Bridge 1 über einen nahezu ausgeglichenen Bereich an Bridge 2 bis zu $-420,1"ns"$ am Endpoint nach vier Hops. Zusätzlich zu diesem Abwärtstrend wächst mit jeder weiteren Bridge auch der Jitter. Der IQR steigt monoton von $39,7$-$45,6"ns"$ an Bridge 1 über $55,2$-$63,4"ns"$ an Bridge 2 und $76,9$-$83,2"ns"$ an Bridge 3 bis auf $94,4"ns"$ am Endpoint. Jede zusätzliche Bridge in der Kette trägt damit messbar sowohl zum wachsenden Offset als auch zur wachsenden Jitter bei.

Die vorliegenden Läufe fanden ebenfalls unter denselben Idealbedingungen wie die Basisvalidierung statt. Der nachfolgende Abschnitt prüft, ob dieselbe #acr-emph("E2E")-Anforderung auch unter Netzwerklast eingehalten wird.

== Simulierte Netzwerklast <netzwerklast-test>
Das eigentliche Versprechen einer Time-Aware Bridge im Sinne von #acr("TSN") besteht nicht nur darin, unter Idealbedingungen synchron zu bleiben, sondern insbesondere auch dann, wenn dieselbe physische Verbindung gleichzeitig von Best-Effort-Nutzverkehr belegt wird. Die bisherigen Messungen wurden hingegen ausschließlich in einem ansonsten unbelasteten Netz durchgeführt. Der nachfolgende Test prüft deshalb die in @anforderung-netzwerklast begründete Vorbedingung unter definiert erzeugter Hintergrundlast.

Der folgende Test verfolgt zwei Ziele. Zum einen soll er zeigen, ob die #acr-emph("gPTP")-Synchronisation der Bridge auch dann innerhalb der nach @normative-leistungsanforderungen geforderten Grenzen bleibt, wenn ihr Port gleichzeitig mit einer möglichst hohen Datenmenge belastet wird. Zum anderen soll er nachweisen, dass dies keine Eigenschaft des unveränderten Netzwerkstacks ist, sondern erst durch die in @impl-lastschutz beschriebenen Maßnahmen erreicht wird. Der Test wird deshalb als Vorher-Nachher-Vergleich mit identischem Lastprofil und identischem Messaufbau durchgeführt.

=== Testaufbau
Anstelle der vollständigen Kette (Grandmaster $<->$ Bridge 1 $<->$ Bridge 2 $<->$ Bridge 3 $<->$ Endpunkt) ist der Test auf die ersten beiden Hops reduziert (Grandmaster $<->$ Bridge 1 $<->$ Endpoint). So lässt sich die Wirkung der Last isoliert an Bridge 1 beobachten, während der Endpoint gleichzeitig den Nachweis der kumulativen #acr-emph("E2E")-Synchronisationsgenauigkeit nach @normative-leistungsanforderungen über beide Hops liefert.

Als Lastgenerator kommt `zperf` zum Einsatz, ein in Zephyr eingebautes, shellgesteuertes Werkzeug zur Messung des Netzwerkdurchsatzes @zephyr_zperf. Der Grandmaster sendet dabei per #acr-emph("UDP") eine konstante Datenrate an einen auf Bridge 1 laufenden `zperf`-Server - über denselben physischen Port, über den auch die #acr("gPTP")-Nachrichten laufen. #acr-emph("UDP") wurde hier bewusst gegenüber #acr("TCP") bevorzugt, da dessen Congestion Control die tatsächlich angebotene Last variabel und damit für die Messung schwerer kontrollierbar macht. `zperf` erlaubt es stattdessen, eine feste Ziel-Bitrate vorzugeben und den tatsächlich erreichten Durchsatz sowie den Paketverlust getrennt auf Sender- und Empfängerseite auszuwerten.

Zeitgleich läuft eine #acr-emph("PPS")-Messung am GM, Bridge (Slave und Master-Port) und Endpoint. Zusätzlich protokolliert Bridge 1 sekündlich die am belasteten Port tatsächlich empfangene Datenrate sowie den Anteil verworfener Frames, getrennt nach Nutzlast und #acr("gPTP")-Verkehr, sodass sich der Synchronisationsverlauf direkt der jeweils anliegenden Last gegenüberstellen lässt.

=== Untersuchte Konfigurationen
Verglichen werden zwei Softwarestände derselben Bridge, die sich ausschließlich in den Maßnahmen aus @tab-lastschutz-massnahmen unterscheiden:

*Konfiguration A (Ausgangszustand)* verwendet den unveränderten ENET-Treiber mit den Änderungen aus @bridge-sync-impl und @anpassungen-in-zephyr. #acr("gPTP")-Nachrichten sind nicht als eigene Verkehrsklasse gekennzeichnet, teilen sich den Best-Effort-Sende-Ring mit der Nutzlast und werden aus demselben globalen Empfangs-Pufferpool bedient.

*Konfiguration B* aktiviert sämtliche Maßnahmen aus @tab-lastschutz-massnahmen: VLAN-Kennzeichnung der #acr("gPTP")-Nachrichten, den  #acr("CBS"), die verschränkte Bedienung beider Empfangs-Ringe, die eigene Empfangs-Verkehrsklasse sowie den reservierten Empfangs-Pufferpool. Alle übrigen Einstellungen sind in beiden Konfigurationen identisch.

=== Ergebnisse in Konfiguration A
Konfiguration A wurde über $1000"s"$ mit $1"KB"$ großen Paketen und einem stufenförmigen Lastprofil durchgeführt. Beginnend bei $5"Mbit/s"$ wurde die angebotene Rate alle $300"s"$ um weitere $5"Mbit/s"$ bis auf $15"Mbit/s"$ angehoben. Nach $900"s"$ endete die Last. @tab-netzwerklast-durchsatz fasst die je Laststufe protokollierten Durchsatz- und Verlustkennzahlen zusammen. @fig-pps-netzwerklast-ohne-cbs zeigt denselben Lauf als zeitlichen Verlauf.

#figure(
  table(
    columns: (1.4fr, 1fr, 1fr, 1fr),
    align: (left, left, left, left),
    stroke: none,
    table.hline(),
    tab-h[Metrik], tab-h[Stufe 1], tab-h[Stufe 2], tab-h[Stufe 3],
    table.hline(stroke: 0.2pt + luma(80)),
    tab-d[Angebotene Rate], tab-d[5,00 Mbit/s], tab-d[10,00 Mbit/s], tab-d[15,00 Mbit/s],
    table.hline(stroke: 0.2pt + luma(80)),
    tab-d[Laufzeit],
    tab-d[5,00 min (300 s)],
    tab-d[5,00 min (300 s)],
    tab-d[5,00 min (300 s)],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[Übertragene Pakete], tab-d[187.501], tab-d[375.001], tab-d[500.001],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[Empfangene Pakete], tab-d[187.500], tab-d[374.956], tab-d[399.253],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[Verlorene Pakete], tab-d[0], tab-d[44], tab-d[100.747],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[Paketverlust], tab-d[0,00 %], tab-d[0,01 %], tab-d[20,15 %],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[Effektiver Durchsatz], tab-d[5,00 Mbit/s], tab-d[10,00 Mbit/s], tab-d[10,64 Mbit/s],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[Jitter], tab-d[204 µs], tab-d[755 µs], tab-d[1,00 ms],
    table.hline(),
  ),
  caption: [`zperf`-UDP-Lasttest in Konfiguration A],
) <tab-netzwerklast-durchsatz>

#figure(
  image("../assets/Tests/pps_offset_netzwerklast_ohne_cbs.png", width: 100%),
  caption: [PPS-Offset und Netzwerklast ohne Priorisierung],
) <fig-pps-netzwerklast-ohne-cbs>

@fig-pps-netzwerklast-ohne-cbs stellt beide Größen über einer gemeinsamen Zeitachse dar. Über die ersten beiden Laststufen verhält sich das System unauffällig: Die Bridge verarbeitet den eingehenden Verkehr nahezu vollständig, der Drop-Anteil liegt durchgehend bei null, und die drei Messpunkte verbleiben in einem engen, gemeinsamen Band - Slave- und Master-Port von Bridge 1 zwischen etwa $50$ und $250"ns"$, der Endpoint spiegelbildlich zwischen $-50$ und $-250"ns"$. Der Lastwechsel bei $t approx 300"s"$ hinterlässt im Offset-Verlauf keine erkennbare Spur. Eine einzelne Ausnahme bildet ein isoliertes Verlustereignis bei $t approx 475"s"$, das sich als schmaler Ausschlag im Drop-Anteil zeigt. Es entspricht den $44$ in Stufe 2 verlorenen Paketen aus @tab-netzwerklast-durchsatz und beeinflusst den Offset nicht messbar.

Mit dem Übergang in die dritte Laststufe bei $t approx 610"s"$ ändert sich das Bild schlagartig. Am Port von Bridge 1 kommen nun rund $14"Mbit/s"$ an, von denen die Bridge einen erheblichen Teil verwirft. Der Drop-Anteil schwankt für den Rest der Stufe zwischen etwa $30$ und annähernd $100"%"$ der jeweils anliegenden Rate und beträgt über die Stufe gemittelt die in @tab-netzwerklast-durchsatz ausgewiesenen $20,15"%"$. Zeitgleich verlässt der Offset aller drei Messpunkte sein bis dahin stabiles Band. Der zeitliche Zusammenfall von einsetzendem Paketverlust und ausbrechendem Offset ist der zentrale Befund dieses Laufs.

Die sichtbaren Ausschläge von rund $-930$ bis $+920"ns"$ geben dabei nicht die tatsächliche Abweichung wieder. Ein #acr-emph("PPS")-Signal ist ein reiner Sekundenpuls und trägt keine Information darüber, zu welcher Sekunde es gehört. Das Oszilloskop misst deshalb ausschließlich den Phasenversatz zweier Flanken zueinander, nicht den absoluten Zeitunterschied der dahinterliegenden Uhren. Liegen zwei Flanken dicht beieinander, während ihre Uhren mehrere Sekunden auseinanderliegen, bleibt dieser Anteil der Abweichung unsichtbar. Genau das ist hier der Fall. Die Messpunkte liegen auf dem Oszilloskop weiterhin innerhalb weniger hundert Nanosekunden, die zugehörigen Uhren unterscheiden sich zu diesem Zeitpunkt jedoch um Sekunden. Das scheinbar auf knapp $1mu s$ begrenzte Band ist damit eine Eigenschaft des Messverfahrens und nicht der Synchronisation.

Dazu passt, dass stellenweise gar keine gültigen Flanken mehr erfasst wurden. Die langgezogenen Geraden zwischen $t approx 660"s"$ und $t approx 960"s"$ enthalten keine validen Datenpunkte. Die Zeitsynchronisation über die Bridge büßt unter dieser Last also nicht nur an Genauigkeit ein, sondern funktioniert schlicht nicht mehr.

Die Gegenprobe bestätigt die Ursache. Nach dem Abschalten der Last bei $t approx 910"s"$ fangen sich alle drei Messpunkte innerhalb weniger Perioden wieder und kehren in ihr ursprüngliches Band zurück, in dem sie bis zum Ende der Messung verbleiben.

=== Ergebnisse in Konfiguration B
Derselbe Lauf wurde anschließend mit Konfiguration B wiederholt. Die Last wurde dabei wieder in drei Stufen von je rund $300"s"$ gesteigert, allerdings beginnend bei $15"Mbit/s"$ in $15"Mbit/s"$-Schritten. Die am Port von Bridge 1 tatsächlich empfangene Datenrate lag dabei bei rund $14$, $28$ und $42"Mbit/s"$.

#figure(
  image("../assets/Tests/pps_offset_netzwerklast_cbs.png", width: 100%),
  caption: [PPS-Offset und Netzwerklast mit Priorisierung],
) <fig-pps-netzwerklast-cbs>

@fig-pps-netzwerklast-cbs zeigt beide Größen über einer gemeinsamen Zeitachse. Entscheidend ist der Vergleich mit @fig-pps-netzwerklast-ohne-cbs, denn die Bridge steht hier unter deutlich höherer Last. Bereits die erste Stufe entspricht mit rund $14"Mbit/s"$ genau jener Rate, bei der die Synchronisation in Konfiguration A zusammenbrach, und die dritte liegt mit $42"Mbit/s"$ um den Faktor drei darüber. Der Nutzverkehr leidet entsprechend. Schon in der ersten Stufe verwirft die Bridge rund ein Drittel der eingehenden Pakete, in den beiden höheren Stufen etwa die Hälfte. Der Anteil verworfener #acr("gPTP")-Frames bleibt dabei über die gesamte Messdauer bei null. Genau die Trennung, die in Konfiguration A fehlte.

Im Offset-Verlauf ist von alledem nichts zu sehen. Beide Bridge-1-Messpunkte verbleiben durchgehend in einem gemeinsamen Band von rund $60$ bis $230"ns"$, der Endpoint spiegelbildlich zwischen etwa $-80$ und $-300"ns"$. Die Lastwechsel bei $t approx 300"s"$ und $t approx 600"s"$ hinterlassen keine erkennbare Reaktion, und die mittleren Abweichungen zum Grandmaster liegen mit $116$, $145$ und $156"ns"$ sogar leicht unter denen der ungestörten Phase aus @fig-pps-netzwerklast-ohne-cbs. Vor allem aber ist die Messreihe lückenlos. Es fehlen keine #acr-emph("PPS")-Flanken, und der Offset bleibt über die gesamten $1000"s"$ in demselben Band, statt wie in Konfiguration A über die Sekundengrenze hinaus wegzulaufen.

=== Vergleich und Einordnung
Der gemessene Unterschied ist dabei nicht dem #acr("CBS") zuzuschreiben. Der Shaper regelt ausschließlich die Senderichtung, die Last trifft die Bridge hier aber am Eingang. Ausschlaggebend sind deshalb die empfangsseitigen Maßnahmen aus @impl-lastschutz, insbesondere der reservierte Pufferpool: Ohne ihn teilen sich Nutzlast und #acr("gPTP")-Nachrichten denselben Speicher, und die Bridge verwirft unter Last beide gleichermaßen. Da die Maßnahmen aus @tab-lastschutz-massnahmen erst in ihrer Kombination greifen, sind sie bewusst nicht einzeln bewertet worden.

Damit ist erreicht, was eine Time-Aware Bridge leisten muss. Gefordert ist nicht, dass der Nutzdatendurchsatz unter Last erhalten bleibt, sondern dass die Zeitsynchronisation es tut. In Konfiguration B verwirft die Bridge bei $42"Mbit/s"$ rund die Hälfte des eingehenden Nutzverkehrs, aber keinen einzigen #acr("gPTP")-Frame, und der Offset bleibt unverändert innerhalb der geforderten Grenzen. Die Degradation trifft ausschließlich die unkritische Verkehrsklasse, während in Konfiguration A beide betroffen sind und damit genau die Funktion ausfällt, die den Zweck der Bridge ausmacht.

=== Ausblick
Wie in @testaufbau beschrieben, verfügt nur der enet1g-Port über #acr("CBS")-Unterstützung. Die Last ließ sich deshalb nur in eine Richtung erzeugen und die Wirkung der Maßnahmen nur an diesem einen Port beobachten. Eine aussagekräftigere Auswertung des Verhaltens unter Netzlast, insbesondere in beide Richtungen und über mehrere Hops hinweg, setzt daher Hardware voraus, die die betrachteten #acr("TSN")-Mechanismen auf allen Ports bereitstellt.
