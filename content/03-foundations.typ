#import "../meta.typ": acr-cap, acr-emph, acrpl-emph, cap-long-only, fig-platzhalter-mittel, gls, note, tab-d, tab-h
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Grundlagen

Um die in den folgenden Kapiteln beschriebenen Anpassungen, sowie deren messtechnische Validierung nachvollziehen zu können, vermittelt dieses Kapitel die dafür notwendigen Grundlagen.

Zunächst wird mit dem #acr-emph("OSI")-Referenzmodell die begriffliche Grundlage geschaffen, auf der alle folgenden Abschnitte aufbauen, insbesondere um #acr("TSN") und #acr("gPTP") später präzise auf Layer 2 darstellen zu können. Anschließend wird #acr("TSN") als übergeordnetes Konzept eingeordnet und das darin enthaltene Zeitsynchronisationsprotokoll IEEE 802.1AS #acr("gPTP") im Detail vorgestellt. Dessen Mechanismen, insbesondere Sync- und #gls("pdelay")[pDelay]-Nachrichten, sowie die Rolle einer Bridge bilden die normative Grundlage, gegen die die in dieser Arbeit untersuchte Implementierung validiert wird. Anschließend werden die hardwareseitigen Voraussetzungen für ein #acr("gPTP")-konformes Timestamping erläutert, insbesondere die Unterscheidung zwischen #acr("MAC")- und #acr("PHY")-Timestamping. Diese ist für die spätere Einordnung der Messergebnisse von zentraler Bedeutung. Abschließend wird das Echtzeitbetriebssystem Zephyr vorgestellt, dessen Scheduling-Verhalten, Treiberschicht und Netzwerk-Subsysteme den Rahmen bilden, innerhalb dessen die in Kapitel 4 beschriebenen Anpassungen umgesetzt wurden.

== Das ISO/OSI-Referenzmodell <osi-model>
Um die Kommunikation zwischen Netzwerkgeräten trotz unterschiedlichster Hardware und Übertragungsmedien einheitlich beschreiben zu können, unterteilt das #acr-emph("OSI")-Referenzmodell die Netzwerkkommunikation in sieben aufeinander aufbauende Schichten (Layer). Jede Schicht übernimmt dabei eine klar abgegrenzte Aufgabe und stellt der jeweils darüberliegenden Schicht ihre Funktionalität über eine definierte Schnittstelle zur Verfügung, ohne dass diese die konkrete Umsetzung darunter kennen muss. Diese Kapselung erlaubt es, einzelne Schichten unabhängig voneinander auszutauschen oder weiterzuentwickeln.

Für die vorliegende Arbeit sind vor allem die beiden untersten Schichten relevant, auf denen #acr("TSN") und #acr("gPTP") operieren:

- *Bitübertragungsschicht (Layer 1, Physical Layer):* Definiert die physikalische Übertragung von Bitfolgen über ein Medium, u. a. Spannungspegel, Steckerbelegung und Signalkodierung@ethernetDefinitiveGuide. Sie wird in dieser Arbeit vor allem im Zusammenhang mit dem #acr("PHY")-Baustein relevant (siehe @hardware-basics).

- *Sicherungsschicht (Layer 2, Data Link Layer):* Organisiert die Übertragung von Datenframes zwischen unmittelbar benachbarten Netzwerkknoten und gliedert sich nach IEEE 802 in zwei Teilschichten: die #acr-emph("LLC")-Teilschicht sowie die darunterliegende #acr-emph("MAC")-Teilschicht, welche u. a. die Adressierung über #acr("MAC")-Adressen sowie den Zugriff auf das Übertragungsmedium regelt@ethernetDefinitiveGuide. #acr("TSN") und #acr("gPTP") setzen ausschließlich auf dieser Schicht auf (siehe @tsn-intro), wodurch sie unabhängig von höheren, routingfähigen Protokollen wie #acr-emph("IP") funktionieren.

== Time-Sensitive Networking <tsn-intro>
Auf der in @osi-model eingeführten Sicherungsschicht (Layer 2) trifft Standard-Ethernet keine Aussage über garantierte Übertragungszeiten und arbeitet stattdessen nach dem Best-Effort-Prinzip@ethernetDefinitiveGuide. Switches puffern Pakete in Warteschlangen (Queues) und verwerfen sie bei Überlast. Dies kann in industriellen Anwendungen zu unvorhersehbaren Verzögerungen (#gls("jitter")[Jitter]) und Paketverlusten führen. Für zeitkritische Steuerungsanwendungen ist jedoch ein deterministisches Zeitverhalten zwingend erforderlich, bei dem die maximale Übertragungsdauer (#gls("bounded-latency")[Bounded Latency]) garantiert ist@zhang2024tsn. Genau hier setzt #acr("TSN") an.

#acr("TSN") erweitert das klassische Ethernet um entsprechende Mechanismen auf Layer 2, um diesen Determinismus zu gewährleisten. Das Fundament aller #acr("TSN")-Mechanismen ist eine gemeinsame Zeitbasis aller Netzwerkknoten. Diese wird durch den Standard IEEE 802.1AS bereitgestellt.

Eine gemeinsame Zeitbasis allein genügt jedoch nicht, um die Bounded Latency zu garantieren: Sie sorgt zwar dafür, dass alle Knoten dieselbe Zeit kennen, verhindert aber nicht, dass ein Burst an Best-Effort-Nachrichten die Synchronisation behindert. #acr("TSN") stellt dafür ergänzend Mechanismen zur Verkehrsformung bereit, die reservierten Datenströmen unabhängig vom übrigen Netzwerkverkehr eine garantierte Bandbreite zusichern. Diese gehen auf die #acr-emph("AVB")-Arbeitsgruppe zurück, aus der sich #acr("TSN") entwickelt hat @zhang2024tsn, und werden am Beispiel des Credit Based Shaping in @cbs wieder aufgegriffen.

== Das Zeitsynchronisationsprotokoll IEEE 802.1AS
Dieses Kapitel beschreibt das Zeitsynchronisationsprotokoll IEEE 802.1AS, das im #acr("TSN")-Kontext auch als #acr("gPTP") bezeichnet wird. #acr("gPTP") definiert Verfahren, um die Clocks verteilter Systeme über ein lokales Netzwerk im Sub-Mikrosekundenbereich zu synchronisieren. Im Folgenden werden die Abgrenzungen zu anderen Protokollen, die Netzwerktopologie, die Synchronisations- und Messmechanismen sowie die Rolle einer #acr("gPTP")-Bridge im Detail erläutert.


=== Einordnung und Abgrenzung
Um die Notwendigkeit von #acr("gPTP") besser zu verstehen, muss es gegenüber dem im Internet etablierten #acr-emph("NTP") sowie dem ursprünglichen #acr-emph("PTP")v2 (IEEE 1588) abgegrenzt werden.

#figure(
  table(
    columns: (1.5fr, 1.8fr, 2fr, 2fr),
    stroke: none,
    table.hline(),
    tab-h[Merkmal], tab-h[#acr-cap("NTP")], tab-h[#acr-cap("PTP")v2], tab-h[#acr-cap("gPTP")],
    table.hline(stroke: 0.5pt),
    tab-d[Genauigkeit], tab-d[$mu$s - ms], tab-d[< 1 $mu$s], tab-d[ < 1 $mu$s],
    table.hline(stroke: 0.2pt + luma(80)),
    tab-d[Laufzeitmessung], tab-d[#acr-cap("E2E")], tab-d[#acr-cap("E2E")/#acr-cap("P2P")], tab-d[#acr-cap("P2P")],
    table.hline(stroke: 0.2pt + luma(80)),
    tab-d[Komplexität],
    tab-d[Einfach],
    tab-d[Hoch],
    tab-d[Plug-and-Play],
    table.hline(stroke: 0.2pt + luma(80)),
    tab-d[Transportschicht], tab-d[Layer 7], tab-d[Layer 2/Layer 3&4], tab-d[Layer 2],
    table.hline(stroke: 0.2pt + luma(80)),
    tab-d[Hardwarebedarf], tab-d[-], tab-d[#acr-cap("TSN") Hardware], tab-d[#acr-cap("TSN") Hardware ],
    table.hline(stroke: 0.2pt + luma(80)),
    tab-d[Ziel], tab-d[Generell], tab-d[Weiträumige Netzwerke], tab-d[lokale, zeitkritische Systeme],
    table.hline(),
  ),
  caption: [Vergleich NTP, PTPv2 und gPTP#cap-long-only[ @ieee8021as2025[8.5]]],
)<comparison-ptp-gptp>

#acr("NTP") stellt das Standardverfahren für die allgemeine Systemzeitsynchronisation im IT-Bereich dar@rfc5905[1]. Es ist darauf ausgelegt, Latenzschwankungen und einzelne unzuverlässige Messungen im Internet oder in Weitverkehrsnetzen statistisch auszugleichen @rfc5905[10] @rfc5905[11.2.1]. Es toleriert dennoch Abweichungen im Millisekundenbereich@ieee8021as2025[C.3]. Für Anwendungen in der industriellen Automatisierung oder im Automobilbereich sind jedoch Genauigkeiten im Nanosekundenbereich immer häufiger von großer Bedeutung@ti_spry316.

Diese Genauigkeit erreicht PTPv2 vor allem durch Hardware-Timestamping der Paketlaufzeit @ieee1588_2019[7.3.4.1]. Da der Standard jedoch ein sehr breites Anwendungsspektrum abdecken soll, ist er hochgradig flexibel konzipiert. Zentrale Eigenschaften wie der Transportmechanismus, die Netzwerkarchitektur, das Laufzeitmessverfahren und die Zeitstempelverarbeitung werden nicht starr vorgegeben, sondern in sogenannten PTP-Profilen definiert @ieee8021as2025[7.6]. Diese weitreichende Konfigurierbarkeit hat jedoch den Nachteil, dass Hersteller oft unterschiedliche Optionen implementieren, was die Interoperabilität von Geräten verschiedener Anbieter in der Praxis erheblich erschwert.

Das #acr("gPTP") löst dieses Problem, indem es ein fest definiertes, stark eingeschränktes Profil von #acr("PTP")v2 vorschreibt @ieee8021as2025[7.1]. Es eliminiert optionale Parameter und erzwingt standardmäßig die #acr-emph("P2P")-Laufzeitmessung sowie standardisierte Nachrichtenintervalle @ieee8021as2025[7.6]. Dadurch wird ein Plug-and-Play Verhalten für lokale, zeitkritische Ethernet-Netzwerke realisiert.

=== Rollen und Netzwerktopologie
Eine #gls("domain")[#acr("gPTP")-Domäne] definiert eine logische Gruppierung von Geräten, die über das Netzwerk miteinander kommunizieren und auf eine gemeinsame Zeitbasis synchronisiert werden. Innerhalb dieser Topologie nimmt jedes Gerät eine spezifische Rolle ein. Die Netzwerkschnittstellen (Ports) eines Gerätes können dabei in verschiedene Zustände versetzt werden.

In einer #acr("gPTP")-Domäne wird zwischen drei primären Gerätetypen unterschieden:

- *#acr-emph("GM"):* Die #acr("GM") bildet die oberste Zeitreferenz für die gesamte Domäne. Sie verfügt in der Regel über eine hochpräzise Zeitquelle und verteilt ihre Zeit im Netzwerk@ieee8021as2025[3.16].

- *#gls("bridge")[Time-Aware Bridge]:* Auch PTP Relay Instance genannt, verbindet verschiedene Netzwerksegmente (vergleichbar mit einem Switch) und leitet Synchronisationsdaten weiter. Um Akkumulationseffekte von Verzögerungen zu vermeiden, nimmt sie eine aktive Rolle im Protokoll ein. Die Ports einer Bridge können dabei verschiedene Rollen einnehmen@ieee8021as2025[3.27]:
  - *#gls("port-roles")[Master Port]:* Dient als Zeitquelle für das angeschlossene Netzwerk. Sendet periodisch Synchronisationsnachrichten, um das nachfolgende Gerät zu synchronisieren.
  - *#gls("port-roles")[Slave Port]:* Empfängt die Synchronisationsnachrichten der übergeordneten Clock, um die eigene lokale Clock zu synchronisieren.

- *Time-Aware Endstation:* Eine PTP Instance, die den Endpunkt der Zeitsynchronisationshierarchie darstellt. Sie empfängt die Zeitinformationen, synchronisiert ihre lokale Clock darauf, leitet diese jedoch nicht an andere Geräte weiter. Ihr Port arbeitet daher immer im Slave-Modus@ieee8021as2025[3.25].

Welches Gerät welche dieser Rollen einnimmt, ist nicht statisch festgelegt, sondern wird im Normalbetrieb dynamisch durch den #acr-emph("BTCA") bestimmt: Alle Geräte einer Domäne tauschen dazu #gls("announce")[Announce-Nachrichten] mit vergleichbaren Qualitätsattributen ihrer Clock aus (u. a. `priority1`, Clock-Klasse und -Genauigkeit) @ieee8021as2025[8.6] und einigen sich verteilt darauf, welche Clock die beste verfügbare Referenz darstellt. Die so bestimmte Clock wird zum #gls("grandmaster")[Grandmaster]. Auf Basis dieses Vergleiches entscheidet jedes Gerät zudem selbst, in welchen Zustand die einzelnen Ports seiner Schnittstellen versetzt werden@ieee8021as2025[10.3.1.2]. In dem in @testaufbau beschriebenen Testaufbau dieser Arbeit ist der #acr("BTCA") jedoch nicht aktiv, da hier ausschließlich die Bridge-Funktionalität selbst validiert werden soll. Deshalb werden die Rollen den Geräten statisch zugewiesen.

=== Die Sync-Nachricht

Um das Prinzip der Zeitsynchronisierung zu verstehen, muss zunächst die Funktionsweise einer #gls("clock")[Clock] in digitalen Systemen verstanden werden. Jede #acr-emph("CPU") besitzt einen internen Taktgeber (Hardware-Oszillator), der als Frequenzquelle dient.
Eine Clock zählt die Schwingungen dieses Oszillators und bildet daraus die lokale Systemzeit ab@tanenbaum2016modernos[5.5.1]. Aufgrund von Fertigungstoleranzen, Temperaturschwankungen und Alterungen weisen diese Quarze jedoch eine geringfügige Frequenzabweichung sowie einen Phasenversatz zur Referenzzeit auf @vig2004tutorial. Ohne eine dauerhafte Korrektur laufen die Clocks im Laufe der Zeit auseinander.
Der Synchronisationsmechanismus gleicht diesen Versatz aus, indem die lokale Clock periodisch an die Zeitbasis des Masters angepasst wird. Hierbei unterscheidet der Standard zwischen zwei Verfahren: dem *#gls("step-mode")[Two-Step]*- und dem *#gls("step-mode")[Single-Step]*-Verfahren, die in @sync-mechanism dargestellt sind.
#figure(
  image("../assets/Sync/gPTP-sync-mechanism.png", width: 80%),
  caption: [Darstellung des Sync-Mechanismus#cap-long-only[, in Anlehnung an @ieee8021as2025]],
) <sync-mechanism>


Bei dem im @sync-mechanism (linke Seite) dargestellten Two-Step-Verfahren erfolgt der Austausch in zwei Schritten:

1. Sync-Nachricht: Der Master sendet eine Sync-Nachricht an den Slave. Dabei wird der Sendezeitpunkt ($t_{s}$) auf Master-Seite und der Empfangszeitpunkt ($t_{r}$) auf Slave-Seite erfasst@ieee8021as2025[11.1.3].

2. Follow_Up-Nachricht: Um dem Slave die notwendigen Informationen für die Synchronisation bereitzustellen, sendet der Master anschließend eine Follow_Up-Nachricht. Diese enthält den präzisen Sendezeitpunkt der Sync-Nachricht (#gls("preciseorigintimestamp")[`preciseOriginTimestamp`]), das #gls("correctionfield")[`correctionField`] sowie die `rateRatio`.@ieee8021as2025[11.1.3]

  - *`preciseOriginTimestamp`:* Der zuvor auf Master-Seite erfasste Sendezeitpunkt $t_s$, ausgedrückt in der Zeitbasis der Grandmaster Clock. Er bildet die eigentliche Referenzzeit, auf die sich alle weiteren Korrekturen beziehen@ieee8021as2025[10.2.2].

  - *`correctionField`:* Ein von der Grandmaster Clock mit dem Wert "0" initialisierter Korrekturwert, der auf dem Weg zum Slave alle Verzögerungen aufsummiert, die im `preciseOriginTimestamp` noch nicht enthalten sind. Besonders die gemessene #gls("path-delay")[Leitungsverzögerung], die eine Nachricht über zwischengeschaltete Bridges akkumuliert (#gls("residence-time")[`residence time`]), darf hier nicht missachtet werden. Damit lässt sich der tatsächliche Sendezeitpunkt der Grandmaster Clock trotz dieser Verzögerungen exakt rekonstruieren@ieee8021as2025[10.2.2].

  - *#gls("rateratio")[`rateRatio`]:* Das Verhältnis der Frequenz der Grandmaster Clock zur Frequenz der lokalen Clock des Slaves. Ausgehend vom Wert eins bei der Grandmaster Clock wird sie über jeden Hop hinweg fortgeschrieben und beschreibt so stets das aktuelle Frequenzverhältnis zur ursprünglichen Zeitquelle (siehe Abschnitt „Die #acr("gPTP") Bridge"). Neben der Offset-Korrektur erlaubt sie dem Slave dadurch auch, seine lokale Taktrate an die des Masters anzupassen@ieee8021as2025[10.2.2].

Dieser Ablauf kann auch in einem Schritt erfolgen. Dabei werden, wie auf der rechten Seite der @sync-mechanism dargestellt, bereits alle nötigen Informationen in der Sync-Nachricht übermittelt@ieee8021as2025[11.1.3].


=== Messung der Leitungsverzögerung
Ein weiterer wichtiger Mechanismus ist das Berechnen des #gls("path-delay")[`propagation Delays`]. Hierbei wird ermittelt, wie lange ein #gls("frame")[Frame] auf der physischen Leitung benötigt.

#figure(
  image("../assets/Sync/gPTP-pDelay-mechanism.png", width: 80%),
  caption: [Darstellung des pDelay-Mechanismus#cap-long-only[, in Anlehnung an @ieee8021as2025]],
) <pDelay-mechanism>

Der Mechanismus nutzt drei Arten von Nachrichten.
Der Initiator sendet zuerst eine `pDelay_Req` Nachricht. Dabei wird beim Senden der Nachricht der Zeitstempel $t_1$ und beim Empfangen durch den Partner der Zeitstempel $t_2$ aufgenommen. Anschließend sendet der Empfänger die Nachricht `pDelay_Resp` zurück, wobei die Zeitstempel $t_3$ (Senden) und $t_4$ (Empfangen) erfasst werden. Mit der Nachricht `pDelay_Resp_Follow_Up` wird zuletzt der Zeitstempel t3 an den Initiator übermittelt@ieee8021as2025[11.1.2].

Da der Initiator nun alle vier Zeitstempel besitzt, kann die Berechnung wie folgt durchgeführt werden:

$
  t_("ir") & = t_2 - t_1 \
  t_("ri") & = t_4 - t_3 \
         D & = (t_("ir") + t_("ri"))/2 = ((t_4 - t_1) - (t_3 - t_2))/2
$ <pdelay-calc>

Das Ergebnis $D$ entspricht dem durchschnittlichen `propagation Delay`. Neben $D$ liefert der pDelay-Mechanismus über die Zeit hinweg noch eine Größe. Aus der Steigung aufeinanderfolgender $t_("ir")$- bzw. $t_("ri")$-Messreihen lässt sich das Frequenzverhältnis zum unmittelbaren Nachbarn ableiten, die #gls("neighborrateratio")[`neighborRateRatio`] @ieee8021as2025[11.2.19.3.3]. Sie beschreibt -- anders als die über Follow_Up-Nachrichten propagierte `rateRatio` -- das Frequenzverhältnis ausschließlich zwischen zwei direkt benachbarten Ports @ieee8021as2025[10.2.5.7] und wird von einer Bridge zur Fortschreibung der eigenen `rateRatio` benötigt @ieee8021as2025[10.2.8] (siehe Abschnitt „Die gPTP Bridge").

=== Der Synchronisationsmechanismus <sync-process>
Nachdem der Slave alle Informationen erhalten hat, führt er die finale Synchronisation der lokalen Clock durch. Dieser Prozess besteht aus drei Schritten:

1. *Berechnung des Sendezeitpunkts:* Aus der Follow_Up-Nachricht kennt der Slave den `preciseOriginTimestamp` und das `correctionField`. Die Summe beider Werte beantwortet die Frage, wie spät es auf der Grandmaster Clock genau in dem Moment war, als die Nachricht den letzten Knoten verlassen hat.@ieee8021as2025[11.1.3]

2. *Einbeziehung der Leitungsverzögerung:* Um den absoluten Zeitversatz zur Master-Clock zu bestimmen, addiert der Slave die zuvor gemessene Leitungsverzögerung ($D$) zur zuvor berechneten Zeit. Der Vergleich mit dem eigenen Empfangszeitpunkt ($t_r$) ergibt den aktuellen #gls("offset")[Offset], um den die lokale Clock korrigiert werden muss.@ieee8021as2025[11.1.3]

3. *Frequenzanpassung (#gls("syntonization")[Syntonisierung]):* Um ein erneutes Auseinanderlaufen der Uhren zu verhindern, verwendet der Slave die `rateRatio`. Dies ist das Verhältnis der Grandmaster-Frequenz zur eigenen lokalen Frequenz. Durch die Anpassung der lokalen Zählrate an diesen Wert wird die Frequenz des lokalen Oszillators an den Takt des Masters angeglichen.@ieee8021as2025[11.1.3]

=== Die gPTP Bridge
Anders als ein klassischer Ethernet-Switch, der Frames auf Layer 2 lediglich weiterleitet, nimmt eine Time-Aware Bridge aktiv am #acr("gPTP") teil. Dabei terminiert die Bridge eingehende Sync-Nachrichten auf dem Slave-Port und generiert auf den Master-Ports eigene, neue Sync- und Follow_Up Nachrichten für die nachfolgenden Geräte. Diese aktive Beteiligung ist notwendig, damit sowohl die im vorherigen Abschnitt beschriebenen Leitungsverzögerungen als auch die interne Verarbeitungszeit an jedem Hop korrekt kompensiert werden und sich Messfehler nicht unkontrolliert über mehrere Bridges hinweg akkumulieren.

Damit die Bridge eine eingehende Sync-Nachricht korrekt an ihre Master-Ports weiterleiten kann, sind folgende Schritte notwendig:

1. *Empfangen auf dem Slave-Port:* Die Bridge empfängt die Sync-Nachricht und erfasst analog zum in @sync-mechanism dargestellten Sync-Verfahren den Empfangszeitpunkt $t_r$.

2. *Messung der `residence time`:* Bevor die Bridge die Nachricht weiterleiten kann, durchläuft diese intern den Netzwerk-Stack des Geräts. Die dafür benötigte Zeitspanne bis zum Absenden auf dem Master-Port zum Zeitpunkt $t_s$ wird als `residence time` bezeichnet und ergibt sich aus $t_s - t_r$.

3. *Aktualisierung der `rateRatio`:* Die Bridge verknüpft die im Follow_Up empfangene `rateRatio` mit der über den in @pDelay-mechanism beschriebenen pDelay-Mechanismus lokal gemessenen `neighborRateRatio` (dem Frequenzverhältnis zur Master Clock): $ "rateRatio"_("neu") = "rateRatio"_("alt") dot "neighborRateRatio" $
  Dadurch bleibt die `rateRatio` über beliebig viele Hops hinweg gültig und beschreibt stets das Frequenzverhältnis zwischen der Grandmaster Clock und der lokalen Clock der Bridge.@ieee8021as2025[11.1.3]

4. *Aktualisierung des `correctionField`:* Zum eingehenden `correctionField` addiert die Bridge sowohl die gemessene Leitungsverzögerung $D$ (skaliert mit der eingehenden `rateRatio`) als auch die zuvor ermittelte `residence time` (skaliert mit der soeben aktualisierten `rateRatio`)@ieee8021as2025[11.1.3]:
$
  "correctionField"_("neu") = "correctionField"_("alt") + D dot "rateRatio"_("alt") + (t_s - t_r) dot "rateRatio"_("neu")
$
Der `preciseOriginTimestamp` bleibt dabei unverändert, da er stets die ursprüngliche Sendezeit der Grandmaster Clock referenziert. Das `correctionField` trägt hingegen die seit dem Grandmaster akkumulierte Korrektur aus Laufzeit und Verarbeitungszeit. Da $D$ und die `residence time` jeweils mit der `rateRatio` skaliert werden, liegt das `correctionField` durchgehend in der Zeitbasis der Grandmaster Clock vor, unabhängig davon, wie viele Hops die Nachricht bereits durchlaufen hat.

Die in @sync-process beschriebene Syntonisierung lässt sich auf zwei grundsätzlich unterschiedliche Arten realisieren. Entweder wird die tatsächliche Oszillatorfrequenz selbst nachgeregelt, etwa über einen spannungsgesteuerten Oszillator oder eine anpassbare #acr-emph("PLL"). Oder die physikalische Taktfrequenz bleibt fest, und stattdessen wird das Inkrement angepasst, um das der Zählerstand der Clock bei jedem Takt erhöht wird @nxp_imxrt1170_refman[60.3.8.1.1]. Letzteres Verfahren ist bei #acr("PTP")-Clocks weit verbreitet, da es sich rein digital realisieren lässt, ohne dass die Hardware-Taktquelle selbst verändert werden muss. Zephyr stellt diese Funktionalität über eine #acr-emph("API") bereit.
Dabei kann die #acr("PTP")-Clock über den `rate_adjust()`-Callback die Rate zur Laufzeit anpassen. Die in Kapitel 4 beschriebene Implementierung nutzt diesen Mechanismus.

== Hardware Grundlagen <hardware-basics>
Die in den vorangegangenen Abschnitten beschriebenen Synchronisations- und Messmechanismen setzen voraus, dass die beteiligten #gls("timestamp")[Zeitstempel] mit einer dem geforderten Sub-Mikrosekundenbereich entsprechenden Genauigkeit erfasst werden. Dieses Kapitel beleuchtet die dafür notwendigen Hardware-Grundlagen. Zunächst wird die #acr-emph("MAC")-Schicht als die Komponente eingeführt, in der sowohl das Timestamping als auch die im Anschluss vorgestellte Verkehrsformung stattfinden. Anschließend wird erläutert, warum reines Software-Timestamping für #acr("gPTP") ungeeignet ist und stattdessen spezialisierte Netzwerk-Hardware benötigt wird, sowie die Unterscheidung zwischen #acr("PHY")- und #acr("MAC")-Timestamping als zwei mögliche Realisierungsvarianten dieses Hardware-Timestampings im Detail betrachtet. Abschließend wird mit dem Credit Based Shaping der in @tsn-intro angekündigte #acr-emph("AVB")-Mechanismus vorgestellt, mit dem die #acr("MAC")-Schicht die geforderte Bounded Latency durchsetzt.

=== Die MAC-Schicht <mac-layer>
Die #acr("MAC")-Schicht bildet die untere der beiden in @osi-model eingeführten Teilschichten von Layer 2 und übernimmt drei zentrale Aufgaben: das Bilden und Zerlegen von Ethernet-Frames (u. a. Präambel, #acr("SFD"), Header mit Quell- und Ziel-#acr("MAC")-Adresse, Nutzdaten und Prüfsumme), die Adressierung über #acr("MAC")-Adressen sowie die Steuerung des Zugriffs auf das Übertragungsmedium @ethernetDefinitiveGuide. Diese Zugriffssteuerung war ursprünglich als CSMA/CD (Carrier Sense Multiple Access with Collision Detection) notwendig, um auf einem gemeinsam genutzten Bus Kollisionen zwischen gleichzeitig sendenden Teilnehmern zu erkennen und aufzulösen @ethernetDefinitiveGuide. In den heute üblichen geswitchten Vollduplex-Topologien entfällt diese Koordinierung, da jede Verbindung nur noch zwei Teilnehmer besitzt; Framing und Adressierung bleiben jedoch weiterhin Aufgabe der #acr("MAC")-Schicht. Zur Hardware hin ist sie über eine standardisierte Schnittstelle (z. B. MII, RMII oder RGMII) an den #acr("PHY") angebunden, über die auch der in @phy-mac-timestamping beschriebene #acr("SFD")-Impuls übertragen wird.

=== Hardware-Timestamping <hardware-timestamping>
Wie in @comparison-ptp-gptp dargestellt, erfordert #acr("gPTP") eine Genauigkeit im Sub-Mikrosekundenbereich. Diese Anforderung hat direkte Konsequenzen für die Art und Weise, wie die Zeitstempel erfasst werden müssen.\
Eine naheliegende Möglichkeit wäre, den Zeitstempel rein in Software zu erfassen, etwa in dem Moment, in dem die Applikation oder der Netzwerktreiber ein empfangenes Paket verarbeitet. Ein solcher Zeitstempel unterliegt jedoch mehreren Verzögerungsquellen. Abhängig von der Distanz zum Physical Layer (Layer 1) entstehen dabei variable Latenzen durch #gls("interrupt-handling")[Interrupt-Handling], Paketverarbeitung, Betriebssystem-#gls("scheduling")[Scheduling] und das Weiterreichen der Pakete durch den Netzwerk-Stack bis zur Applikation@mahmood2014delayjitter.
Diese Verzögerungen summieren sich auf, sodass Abweichungen im Bereich mehrerer zehn bis hundert Mikrosekunden entstehen und damit um ein Vielfaches von der durch #acr("gPTP") geforderten Genauigkeit abweichen. Reines Software-Timestamping ist damit für #acr("gPTP") ungeeignet.\
Aus diesem Grund wird für #acr("gPTP")-fähige Systeme dedizierte Netzwerk-Hardware benötigt, die in der Lage ist, Zeitstempel autonom zu erfassen: Die Erfassung erfolgt direkt durch eine Logikeinheit in der Netzwerk-Hardware selbst, ausgelöst durch das tatsächliche Auftreten des Signals, und ist damit unabhängig von der aktuellen Auslastung der #acr("CPU") oder des Betriebssystems. Diese Fähigkeit ist nicht bei jeder Ethernet-Hardware gegeben, sondern setzt entsprechend ausgestattete #acr-emph("MAC")-Controller bzw. #acr("PHY")-Bausteine voraus.
Ein für die Zeitstempel-Erfassung besonders relevantes Signal ist dabei der #acr-emph("SFD"): ein festes 1-Byte-Muster (`0xD5`), das im Ethernet-Frame unmittelbar auf die Präambel folgt und das Ende der Präambel sowie den Beginn der eigentlichen Nutzdaten markiert @ethernetDefinitiveGuide[4.]. Da seine Bitfolge im Gegensatz zur Präambel eindeutig ist, lässt es sich zuverlässig per Logik in Hardware erkennen und eignet sich damit als präziser, reproduzierbarer Auslösepunkt für einen Zeitstempel.

=== PHY vs. MAC Timestamping <phy-mac-timestamping>
Für die im vorherigen Abschnitt beschriebenen Mechanismen, insbesondere die Messung der Leitungsverzögerung sowie der `residence time`, ist die Genauigkeit der Zeitstempel $t_1$ bis $t_4$ bzw. $t_r$ und $t_s$ entscheidend. Ein Hardware-Zeitstempel kann dabei an drei unterschiedlichen Stellen im Signalpfad entstehen, die sich sowohl im Ort der eigentlichen Erfassung als auch im auslösenden Ereignis unterscheiden:

- *#acr("PHY")-Timestamping:* Sowohl die Erkennung des #acr("SFD") als auch die Clock, die den Zeitstempel aufnimmt, befinden sich vollständig im #acr-emph("PHY"). Der Zeitstempel entsteht damit in dem Moment, in dem das Signal auf der physischen Leitung erkannt wird, ohne dass eine Signalübertragung zu einer anderen Komponente nötig ist. Dabei wird der Zeitstempel direkt in das Paket eingetragen, noch bevor dieses an den #acr("MAC") weitergereicht wird. Da hier keine weitere Verarbeitung zwischen Erfassung und physischer Leitung liegt, gilt dieses Verfahren als das genaueste @ti_snla242.

- *#acr("SFD")-Timestamping:* Der #acr("PHY") erkennt zwar ebenfalls den #acr("SFD"),  verfügt jedoch selbst über keine Clock, um in diesem Moment einen Zeitstempel aufzunehmen. Stattdessen sendet er bei der Erkennung des #acr("SFD") einen Impuls an den #acr("MAC"). Dieser Impuls signalisiert dem #acr("MAC") das Eintreffen eines Pakets, sodass der Zeitstempel bereits zu diesem Zeitpunkt erfasst werden kann, noch bevor die restlichen Bits des Frames eingelesen wurden. Ein solcher #acr("SFD")-Impuls liefert dadurch einen deutlich stabileren und reproduzierbareren Zeitstempel als das gewöhnliche Interface-Signal @ti_snla242.

- *#acr("MAC")-Timestamping:* Steht kein solcher #acr("SFD")-Impuls zur Verfügung, muss der #acr("MAC") den Beginn eines Frames selbst anhand des regulären Interface-Signals erkennen, über das der #acr("MAC") ihm signalisiert, dass Daten anliegen. Zwischen der physischen Ankunft des Signals und der Zeitstempel-Erfassung liegt dadurch eine zusätzliche, von der Schnittstelle abhängige Latenz, die zudem nicht zwangsläufig konstant ist: Da #acr("MAC") und #acr("PHY") in der Regel unabhängige Taktquellen besitzen, muss das Interface-Signal beim Übergang in die Taktdomäne des #acr("MAC") synchronisiert werden, was zusätzlichen Jitter erzeugt @ti_snla242.

Diese zusätzliche Latenz stellt keinen reinen Nachteil dar, sofern sie bekannt und konstant ist. Der Standard sieht mit den Korrekturgrößen `ingressLatency` und `egressLatency` einen Mechanismus vor, um Zeitstempel unabhängig davon, ob sie per reinem #acr("MAC")-Timestamping oder per #acr("SFD")-Timestamping erfasst wurden, auf eine gemeinsame Referenzebene zurückzurechnen @ieee8021as2025[8.4.3]. Voraussetzung dafür ist jedoch in beiden Fällen, dass die jeweilige Latenz hinreichend deterministisch ist, ein Kriterium, das reines #acr("MAC")-Timestamping aufgrund der beschriebenen Taktdomänen-Problematik tendenziell schlechter erfüllt als #acr("SFD")-Timestamping @ti_snla242.

=== Credit Based Shaping <cbs>
Die in @mac-layer vorgestellte #acr("MAC")-Schicht verwaltet mehrere interne, priorisierte Sende-Warteschlangen, muss aber entscheiden, in welcher Reihenfolge sie deren Frames auf die eine physische Verbindung legt. Der #acr-emph("CBS") ist einer von mehreren Algorithmen, mit dem #acr("TSN") diese Einplanung für reservierte Verkehrsklassen regelt: Er begrenzt den Sendeanteil einer priorisierten Warteschlange auf eine vorab reservierte Bandbreite und verhindert so, dass Best-Effort-Verkehr sie verdrängt @ieee8021qav2009.

Welcher Warteschlange ein Frame dabei zugeordnet wird, entscheidet sich bereits beim Empfang: Jedes Frame trägt in seinem VLAN-Tag ein 3 Bit breites Priority Code Point (PCP)-Feld, das seine Verkehrsklasse kennzeichnet @ieee8021qav2009. Anhand dieses Werts reiht die #acr("MAC")-Schicht das Frame beim, ggf. erst später erfolgenden, Senden in die passende, von einem eigenen Credit-Zähler gesteuerte Warteschlange ein. Bei der in dieser Arbeit untersuchten Bridge, die ein Frame auf einem Port empfängt und über den anderen weiterleitet (siehe Abschnitt „Die gPTP Bridge"), legt somit bereits die Klassifizierung beim Empfang fest, welchem #acr("CBS") das Frame beim Weiterleiten unterliegt.

Jeder von #acr("CBS") verwalteten Warteschlange ist dabei ein Credit-Zähler zugeordnet @ieee8021qav2009: Ist die Warteschlange nicht leer, sendet aber gerade nicht (weil z. B. eine andere Warteschlange den Link belegt), steigt der Credit mit der Rate `idleSlope`, welche der für diese Klasse reservierten Bandbreite entspricht. Während die Warteschlange aktiv sendet, sinkt der Credit mit der Rate `sendSlope`, die sich aus `idleSlope` abzüglich der Port-Datenrate ergibt und damit negativ ist. Ein Frame darf nur dann zur Übertragung ausgewählt werden, wenn der Credit größer oder gleich null ist; sinkt er durch das Senden unter null, muss die Warteschlange warten, bis er sich durch erneutes Ansammeln wieder erholt hat. Über die Zeit gemittelt kann eine Warteschlange dadurch nicht mehr als ihre reservierte Bandbreite `idleSlope` in Anspruch nehmen, wodurch sich die maximale Wartezeit eines Frames in dieser Warteschlange bestimmen lässt @zhang2024tsn.

#acr("CBS") wird üblicherweise direkt in der #acr("MAC")-Schicht in Hardware als eine von mehreren parallelen, kreditverwalteten Sende-Warteschlangen umgesetzt.

Die #acr("MAC")-Peripherie des in dieser Arbeit eingesetzten #acr("SoC") stellt einen solchen kreditgeformten Sende-Ring bereit; wie er im Testaufbau angebunden und konfiguriert wird, beschreibt @impl-lastschutz.

== Das Echtzeitbetriebssystem Zephyr

Nachdem die konzeptionellen Grundlagen des #acr("gPTP") sowie die Anforderungen an die Hardware für präzises Timestamping erläutert wurden, stellt dieses Kapitel das Echtzeitbetriebssystem Zephyr vor. Es dient als die Software-Plattform, in der die abstrakte Protokolllogik und die physikalischen Hardware-Fähigkeiten zusammengeführt werden, um eine funktionale Einheit zu bilden. Ein #acr-emph("RTOS") ist speziell dafür entwickelt, Aufgaben innerhalb eines fest definierten Zeitrahmens auszuführen. Im Gegensatz zu normalen Betriebssystemen, die auf maximalen Durchsatz optimiert sind, kommt es beim #acr("RTOS") auf Determinismus an. Das bedeutet, das Zeitverhalten muss absolut vorhersagbar sein. Kern dabei ist der Scheduler, welcher die #acr("CPU")-Zuweisung steuert. Dieser sorgt dafür, dass kritische Prozesse priorisiert werden und so ihre Fristen einhalten können.

Zephyr ist weit mehr als nur ein Kernel. Es ist ein vollständiges, modulares Ökosystem, das von der Linux Foundation verwaltet wird @zephyr_about und Open-Source-Standards in die Embedded-Welt bringt. Im Gegensatz zu klassischen #acr("RTOS") wie Free#acr("RTOS"), die meist nur einen einfachen Kernel anbieten, bringt Zephyr Treiber, Softwarestacks und viele weitere Komponenten mit.

=== Kernkonzepte und Architektur
Der Zephyr-Kernel unterscheidet zwei Klassen von Threads, die sich in ihrem Scheduling-Verhalten grundlegend unterscheiden: präemptive und kooperative Threads @zephyr_threads. Welcher Klasse ein Thread angehört, ergibt sich unmittelbar aus seiner Priorität: Zephyr nummeriert Prioritäten so, dass ein numerisch kleinerer Wert eine höhere Priorität bedeutet@zephyr_threads.

*Präemptive Threads* verhalten sich wie in klassischen Betriebssystemen. Der Scheduler kann einen laufenden Thread jederzeit unterbrechen, sobald ein Thread höherer Priorität rechenbereit wird, und weist ihm über Zeitscheiben (Time Slicing) auch bei gleicher Priorität regelmäßig die #acr-emph("CPU") zu @zephyr_scheduling.

*Kooperative Threads* bleiben dagegen so lange aktiv, bis sie die #acr("CPU") von sich aus freigeben@zephyr_threads. Ein kooperativer Thread kann somit von keinem anderen Thread unterbrochen werden, selbst wenn dieser eine höhere Priorität besitzt. Er läuft bis zu einem selbst gewählten Punkt vollständig durch. Dieses Verhalten eignet sich für kurze, zeitkritische Abschnitte, die nicht durch das Scheduling anderer Threads verzögert werden dürfen, etwa unmittelbar auf einen Interrupt folgende Verarbeitungsschritte. Es setzt jedoch voraus, dass der Thread selbst diszipliniert und regelmäßig die #acr("CPU") abgibt, da er andernfalls alle Threads gleicher oder niedrigerer Priorität dauerhaft blockiert.

Zusätzlich ist die Hardware-Abstraktion mittels #gls("devicetree")[Device Tree] ein zentrales architektonisches Merkmal @zephyr_devicetree. Dieses Konzept, das auch in Linux verwendet wird, ermöglicht die Beschreibung der Hardware-Konfiguration (z. B. Ethernet-Peripherie, #acr("PTP")-kompatible Timer) getrennt vom eigentlichen Applikationscode. Dadurch wird die maximale Portierbarkeit der Anwendung gewährleistet, da der C-Code ausschließlich die Zephyr-APIs anspricht und die spezifische Hardware-Anbindung über die Device Tree Definitionen erfolgt.

=== Netzwerkarchitektur und relevante Subsysteme <zephyr-network-arch>
Die Architektur des Zephyr-Netzwerkstacks ist auf hohe Performance ausgelegt, was durch mehrere Kernprinzipien erreicht wird. Ein zentrales Prinzip ist das „Zero-Copy“-Verfahren mittels sogenannter Netzwerk-Puffer (`net_buf`) @zephyr_net_buf. Innerhalb des Software-Stacks wird der zugrunde liegende Puffer beim Durchreichen zwischen den Schichten nicht dupliziert, sondern lediglich referenziert, was die #acr("CPU")-Last gegenüber einem durchgehend kopierenden Ansatz reduziert. Ein Kopiervorgang bleibt jedoch an der Treiber-Hardware-Grenze bestehen, wo Treiber die Paketdaten weiterhin zwischen ihrem DMA-Puffer und dem `net_pkt` kopieren @zephyr_eth_nxp_enet_source.

Der Stack ist ähnlich aufgebaut wie das Schichtenmodell aus @osi-model @zephyr_net_stack_architecture. Von oben nach unten gliedert er sich wie folgt:
- *Anwendung*: Socket- bzw. Management-#acr("API")
- *Netzwerkprotokolle*: #acr("IP"), #acr("UDP"), #acr("TCP")
- *Schnittstellen-Abstraktion*: Netzwerkschnittstelle
- *L2-Technologie*: Ethernet
- *Gerätetreiber*: Die unterste Schicht, die den direkten Kontakt zur Hardware herstellt.

Um die Integration von Protokollen wie #acr("gPTP") zu ermöglichen und die präzisen Hardware-Fähigkeiten zu nutzen, stellt Zephyr auf den oberen Schichten eine Reihe relevanter #acrpl-emph("API") und Subsysteme bereit:

- Die *Layer-2-#acr("API")* ermöglicht den direkten Zugriff auf Ethernet-Frames, welche das Transportmittel für #acr("gPTP")-Nachrichten darstellen @zephyr_net_l2. Dies ist zwingend erforderlich, da #acr("gPTP") auf Layer 2 operiert und höhere Protokollschichten wie #acr-emph("IP") oder #acr-emph("UDP") umgangen werden müssen.

- Die *Timestamping-Schnittstelle* bildet die softwareseitige Abstraktion für die in @hardware-basics erläuterten #acr("MAC")-Timestamping-Fähigkeiten @zephyr_ptp_time. Sie ist das entscheidende Bindeglied, das es der Protokoll-Implementierung ermöglicht, auf die für die #acr("gPTP")-Algorithmen nötigen Zeitstempel ($t_1$ bis $t_4$) präzise zuzugreifen.
- Ergänzt wird dies durch *#acr("PTP")-Clock-Treiber*, über welche die Hardware-Timer, die als Referenz für die lokale Zeit dienen, dem System zur Verfügung gestellt und von der #acr("gPTP")-Logik synchronisiert werden können @zephyr_ptp_clock_api. Diese Treiber kapseln die spezifischen Registerzugriffe der Hardware.

=== Die Treiberschicht
Die im vorherigen Abschnitt genannten #acrpl-emph("API") setzen auf dem allgemeinen Zephyr-Treibermodell auf, das die unterste Schicht des Netzwerkstacks bildet und den eigentlichen Kontakt zur Hardware herstellt. Da dieses Modell für die in Kapitel 4 beschriebenen Anpassungen am Ethernet-Treiber unmittelbar relevant ist, wird es im Folgenden kurz umrissen.

Ein Treiber bündelt in Zephyr Konfiguration (z. B. Registeradressen, üblicherweise aus dem Device Tree generiert), Laufzeitzustand und eine API mit Funktionszeigern auf die eigentlichen Treiberoperationen (z. B. Senden, Empfangen) @zephyr_drivers. Diese Trennung erlaubt es, dieselbe Treiberimplementierung für mehrere Hardware-Instanzen wiederzuverwenden, die sich nur in Konfiguration und Zustand unterscheiden. Dies ist  für die beiden ENET-Instanzen `enet` und `enet1g` relevant, die in Kapitel 4 unabhängig voneinander angesprochen werden. Höhere Schichten des Netzwerkstacks kommunizieren dabei nie direkt mit der Hardware, sondern ausschließlich über diese treiberseitige API @zephyr_net_l2.

In der Praxis läuft diese Kommunikation über zwei Einstiegspunkte. Beim Senden reicht der Stack ein fertiges Paket an die Sende-Funktion des Treibers durch, der es an die Hardware übergibt. Beim Empfang übernimmt der Treiber ein eingetroffenes Frame von der Hardware und reicht es zur weiteren Verarbeitung an den Stack weiter @zephyr_net_l2.

=== Datenfluss im Netzwerkstack
Der *Datenfluss* im Stack lässt sich am besten anhand des Weges eines Pakets nachvollziehen, wobei die zuvor beschriebenen Komponenten der Treiberschicht sowie die in @zephyr-network-arch genannten #acrpl-emph("API") zum Einsatz kommen. Der *#gls("ingress-egress")[Ingress-Pfad]* (Empfang) beginnt, wenn ein Ethernet-Frame von der Hardware empfangen wird. Wie in @hardware-basics beschrieben, kann hier durch den #acr("MAC")-Controller ein Hardware-Zeitstempel erfasst werden. Der Zephyr-*Ethernet-Treiber* nimmt diesen Frame samt Zeitstempel-Metadaten entgegen, verpackt ihn in einen `net_buf` und reiht ihn in eine zentrale Verarbeitungswarteschlange ein. An dieser Stelle im Software-Stack sind nun alle Informationen verfügbar, welche die #acr("gPTP")-Logik zur Berechnung des `ingress timestamps (t2)` benötigt.

Beim *#gls("ingress-egress")[Egress-Pfad]* (Senden) erstellt die Applikationslogik einen `net_buf`, der die zu sendende Nachricht enthält. Dieser wird über die Layer-2-#acr("API") an den Treiber übergeben. Nachdem der Treiber das Paket physisch versendet und der #acr("MAC") den exakten Sendezeitpunkt als `egress timestamp (t1)` erfasst hat, wird diese Zeitinformation über einen Callback-Mechanismus (`tx_tstamp`) der Timestamping-Schnittstelle an die Applikation zurückgemeldet @zephyr_net_if_source. Dieser Mechanismus ist die softwareseitige Realisierung der Anforderung aus dem #acr("gPTP")-Standard, den exakten Sendezeitpunkt für die Erstellung der `Follow_Up`-Nachricht zu kennen.
