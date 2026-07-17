#import "../meta.typ": acr-emph, acrpl-emph, fig-platzhalter-mittel, note, tab-d, tab-h
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Grundlagen

Dieses Kapitel legt die für das Verständnis notwendigen Grundlagen.
Erklärt werden soll hier wie:
- Time-Sensitive Networking -> fokussiert auf gPTP
- Echtzeitbetriebssysteme ZephyrRTOS
- notwendige Informationen, die später in den Testsetups benötigt werden.
  - Time-stamps, MAC vs Phy Timestamping,
  - Sync, pDelay, ...

== Time-Sensitive Networking
Standard-Ethernet wurde für den maximalen Durchsatz und Fehlertoleranz konzipiert, arbeitet jedoch nach dem Best-Effort-Prinzip. Dies führt in industriellen Anwendungen zu unvorhersehbaren Verzögerungen (Jitter) und Paketverlusten, da Switches Pakete in Warteschlangen (Queues) puffern und bei Überlast verwerfen. Für zeitkritische Steuerungsanwendungen ist jedoch ein deterministisches Zeitverhalten zwingend erforderlich, bei dem die maximale Übertragungsdauer (Bounded Latency) garantiert ist.

Time-Sensitive Networking (TSN) erweitert das klassische Ethernet um Mechanismen auf Layer 2 des ISO/OSI-Modells, um diesen Determinismus zu gewährleisten. Das Fundament aller TSN-Mechanismen ist eine gemeinsame Zeitbasis aller Netzwerkknoten. Diese wird durch den Standard IEEE 802.1AS bereitgestellt.

== Das Zeitsynchronisationsprotokoll IEEE 802.1AS
Dieses Kaptiel beschreibt das Zeitsynchronisationsprotokoll IEEE 802.1AS, das im TSN-Kontext auch als gPTP (Generalized Precision Time Protocol) bezeichent wird. gPTP definiert Verfahren, um die Clocks verteilert System über ein lokases Netzwerk im Sub-Mikrosekundenbereich zu synchronisieren. Im Folgenden werden die Abgrenzungen zu anderen Protokollen, die Netzwerktopologie, die Synchronisations- und Messmechanismen sowie die Rolle einer gPTP-Bridge im Detail erläutert.


=== Einordnung und Abgrenzung
Um die Notwendigkeit von gPTP besser zu verstehen, muss es gegeüber dem im Internet etablierten Network Time Protocol (NTP) sowie dem ursprünglichem Precision Time Protocol (PTPv2/IEEE 1588) abgegrenzt werden.

#figure(
  table(
    columns: (1.5fr, 1.8fr, 2fr, 2fr),
    stroke: none,
    table.hline(),
    tab-h[Merkmal], tab-h[NTP], tab-h[PTPv2], tab-h[gPTP],
    table.hline(stroke: 0.5pt),
    tab-d[Genauigkeit], tab-d[$mu$s - ms], tab-d[< 1 $mu$s], tab-d[ < 1 $mu$s],
    tab-d[Laufzeitmessung], tab-d[E2E], tab-d[E2E/P2P], tab-d[P2P],
    tab-d[Komplexität],
    tab-d[Einfach],
    tab-d[Hoch],
    tab-d[Plug-and-Play],
    tab-d[Transportschicht], tab-d[Layer 7], tab-d[Layer 2/Layer 3], tab-d[Layer 2],
    tab-d[Hardwarebedarf], tab-d[-], tab-d[TSN Hardware], tab-d[TSN Hardware ],
    tab-d[Ziel], tab-d[Generell], tab-d[Weiträumige Netzwerke], tab-d[lokale, Zeitkritische Systeme],
    table.hline(),
  ),
  caption: [Vergleich NTP, PTPv2 und gPTP],
)<comparison-ptp-gptp>


NTP stellt das Standardverfahren für die allgemaine Systemzeitsynchronistation im IT-Bereich dar. Es ist darauf ausgelegt, Netzwerklatenzen und Routenänderungen im Internet oder in Weitverkehrsnetzen statistisch auszugleichen, toleriert dabei jedoch Abweichungen im Milliskeundenbereich. Für Anwendungen in der industriellen Automotisierung oder im Automobilbereich sind jedoch Präzisionen im Nanosekundebreich erforderlich.

Diese Genauigkeit wird durch das Precision Time Protocol (PTPv2) erreicht, welches vor allem durch Hardware-Timestamping die Paketlaufzeit sehr genau erfasst. PTPv2 wurde als flexibler Baukasten konzipiert und definiert über 100 Konfigurationsoptionen und Profile für verschiedene Industrien. Diese Flexibilität führt in der Praxis jedoch häufig zu Interoperabilitätsproblemen zwischen Geräten unterschiedlicher Hersteller.

Das Protokoll gPTP löst dieses Problem, indem es ein fest definiertes, stark eingeschränktes Profil von PTPv2 vorschreibt. Es eliminiert optionale Parameter und erzwingt standardmäßig die P2P-Laufzeitmessung und eine feste Nachrichtenraten. Dadruch wird ein Plug-and-Play Verhalten für lokale, zeitkritische Ethernet-Netzwerke realisiert.

=== Rollen und Netzwerktopologie
Eine gPTP-Domäne definiert eine logische Gruppierung von Geräten, die über das Netzwerk miteinander kommunizieren und auf eine gemeinsame Zeitbasis synchronisiert werden. Innerhalb dieser Topologie übernimmt jedes Gerät eine spzifische Rolle ein. Die Netzwerkschnittstellen (Ports) eines Gerätes können dabei in verschieden Zustände versetzt wereden.

In einer gPTP-Domäne wird zwischen drei primären Gerätetypen unterschieden:

- *Grandmaster Clock (GM):* Die GM bildet die oberste Zeitreferenz für die gesamte Domäne. Sie verfügt in der Regel über eine hochpräzise Zeitquelle und verteilt ihre Zeit im Netzwerk.

- *Time-Aware Bridge:* Diese verbindet verschiedene Netzwerksegmente (vergleichbar mit einem Switch) und leitet Synchronisationsdaten weiter. Um Akkumulationseffekte von Verzögerungen zu vermeiden, nimmt sie eine aktive Rolle im Protokoll ein. Die Ports einer Bridge können dabei verschieden Rollen einnehmen:
  - *Master Port:* Dient als Zeitquelle für das angeschlossene Netzwerk. Sendet periodisch Synchronisationsnachrichten, um das Nochfolgende Gerät zu Synchronisieren.
  - *Slave Port:* Empängt die Synchronisationsnachrichten der übergeordneten Clock, um die eigene lokale Clock zu Synchronisieren.

- *Time-Aware Endstation:* Endstationen stellen die Endpunkte der Zeitsynchronisationshierarchie dar. Sie empfangen die Zeitinformationen, synchronisieren ihre lokale Uhr darauf, leiten diese jedoch nicht an andere Geräte weiter.

=== Die Sync-Nachricht

Um das Prinzip der Zeitsynchronisierung zu verstehen, muss zunächst die Funktionsweise einer Clock in digitalen System verstanden werden. Jeder CPU besitzt einen internen Taktgeber (Hardware-Oszillator), der als Frequenzquelle dient.
Ein Hardware-Timer zählt die Schwingungen dieses Oszillators und bildet daraus die lokale Systemzeit ab. Aufgrund von Fertigungstoleranzen, Temparaturschwankungen und Alterungen weisen diese Quarze jedoch eine geringfügige Frequenzabweichung sowie einen Phasenversatz zur Refferenzzeit auf. Ohne eine dauerhafte Korrektur laufen die Uhren im Laufe der Zeit auseinander.

Der Synchronisationsmechanismus gleicht diesen Versatz aus, indem die lokale Clock periodisch an die Zeitbasis des Masters angepasst wird. Hierbei unterscheidet der Standard zwischen zwei Verfahren: dem *Two-Step*- und dem *Single-Step*-Verfahren, wie in @sync-mechanism dargestellt.
#figure(
  image("../assets/Sync/gPTP-sync-mechanism.png", width: 80%),
  caption: [Darstellung des Sync-mechanismus],
) <sync-mechanism>


Bei dem im @sync-mechanism (linke Seite) dargestellten Two-Step-Verfahren erfolgt der Austausch in zwei Schritten:

1. Sync-Nachricht: Der Master sendet eine Sync-Nachricht an den Slave. Dabei werden der Sendezeitpunkt ($t_{s}$) auf Master-Seite und der Empfangszeitpunkt ($t_{r}$) auf Slave-Seite erfasst.

2. Follow_Up-Nachricht: Um dem Slave die notwendigen Informationen für die Synchronisation bereitzustellen, sendet der Master anschließend eine Follow_Up-Nachricht. Diese enthält den präzisen Sendezeitpunkt (preciseOriginTimestamp), das correctionField sowie die rateRatio.

Dieser kann auch in einem Schritt erfolgen. Dabei werden wie in der rechten Seite der @sync-mechanism dargestellt, bereits alle nötigen Informationen im Sync-Paket übermittelt.


=== Messung der Leitungsverzögerung
Ein weiterer wichtiger Mechanismus ist das berechenen des `propagation Delays`. Hierbei wird ermittelt, wie lange ein Paket auf der physischen Leitung benötigt.

#figure(
  image("../assets/Sync/gPTP-pDelay-mechanism.png", width: 80%),
  caption: [Darstellung des pDelay-Mechanismus],
) <pDelay-mechanism>

Der Mechanismus nutzt drei Arten von Nachrichten:
Der Initiator sendet zuerst ein `pDelay_Req`. Dabei wird beim Senden der Nachricht der Zeitstempel $t_1$ und beim Empfangen durch den Partner der Zeitstempel $t_2$ aufgenommen. Anschließend sendet der Empfänger das Paket `pDelay_Resp` zurück, wobei die Zeitstempel $t_3$ (Senden) und $t_4$ (Empfangen) erfasst werden. Mit der Nachricht `pDelay_Resp_Follow_Up` wird zuletzt der Zeitstempel t3 an den Initiator übermittelt.

Da der Initiator nun alle vier Zeitstempel besitzt, kann die Berechnung wiefolgt durchgeführt werden:

$t_("ir") = t_2 - t_1\
t_("ri") = t_4 - t_3\
D = (t_("ir") + t_("ri"))/2 = ((t_4 - t_1) - (t_3 - t_2))/2$

Das Ergebnis $D$ entspricht dem durchschnittlichen `propagation Delay`.
=== Der Synchronisationsmechanismus
Nachdem der Slave alle Informationen erhalten hat, führt er die finale Synchronisation der lokalen Clock durch. Dieser Prozess besteht aus drei Schritten:

1. *Berechnung der korrigierten Zeit:* Der Slave nutzt den `precisionOriginTimestamp` als Basiszeit des Grandmasters und addiert das `correctionField` hinzu. Das `correctionField` kompensiert dabei Laufzeitdifferenzen, die durch Zwischenkonoten entstanden sind. Die Summe ergbit die synchronisierte Zeit zum Zeitpunkt des Absendens der Sync-Nachricht.

2. *Einbeziehung der Leitungsverzögerung:* Um den absoluten Zeitversatz zur Master-Uhr zu bestimmen, addiert der Slave die zuvor gemessene Leitungsverzögerung ($D$) zu der korrigierten Zeit. Der Vergleich mit dem eigenen Empfangszeitpunkt ($t_r$) ergibt den aktuellen Offset, um den die lokale Uhr korrigiert werden muss.

3. *Frequenzanpassung (Syntonisierung):* Um ein erneutes Auseinanderlaufen der Uhren zu verhindern, verwendet der Slave die rateRatio. Dies ist das Verhältnis der Grandmaster-Frequenz zur eigenen lokalen Frequenz. Durch die Anpassung der lokalen Zählrate an diesen Wert wird die Frequenz des lokalen Oszillators an den Takt des Masters angeglichen.

=== Die gPTP Bridge
Anders als ein klassicher Ethernet-Switch, der Frames auf Layer 2 im Store-and-Forward-Verfahren rein weiterleitet, nimmt eine Time-Aware Bridge aktiv am gPTP-Protokoll teil. Dabei terminiert die Bridge eingehende Sync-Nachrichten auf dem Slave-Port und generiert auf den Master-Ports eigene, neue Sync- und Follow_Up Nachrichten für die nachfolgenden Geräte. Diese aktive Beteiligung ist notwendig, damit sowohl die im vorherigen Abschnitt beschriebenen Leitungsverzögerungen als auch die interne Verarbeitsungszeit an jedem Hop korrekt kompensiert werden und sich Messfehler nicht unkontrolliert über mehrere Bridges hinweg akkumulieren.

Damit die Bridge eine eingehende Sync-Nachricht korrekt an ihre Master-Ports weiterleiten kann, sind folgende Schritte notwendig:

1. *Empfangen auf dem Slave-Port:* Die Bridge empfängt die Sync-Nachricht und erfasst analog zum in @sync-mechanism dargestellten Verfahren den Empfangszeitpunkt $t_r$.

2. *Messung der `residence time`:* Bevor die Bridge die Nachricht weiterleiten kann, durchläuft diese intern den Netzwer-Stack des Geräts. Die dafür benötigte Zeitspanne bis zum Abesende auf dem Master-Port zum Zeitpunkt $t_s$ wird als `residence time` bezeichent und ergibt sich aus $t_s - t_r$.

3. *Aktualisierung der `rateRatio`:* Die Bridge verknüpft die im Follow_Up empfangene `rateRatio` mit der über den in Abbildung 2.2 beschriebenen pDelay-Mechanismus lokal gemessenen `neighborRateRatio` (dem Frequenzverhältnis zur Master Clock): $ "rateRatio"_("neu") = "rateRatio"_("alt") dot "neighborRateRatio" $
  Dadurch bleibt die `rateRatio` über beliebig viele Hops hinweg gültig und beschreibt stets das Frequenzverhältnis zwischen der Grandmaster Clock und der lokalen Clock der Bridge.

4. *Aktualisierung des `correctionField`:* Zum eingehenden `correctionField` addiert die Bridge sowohl die gemessene Leitungsverzögerung $D$ (skaliert mit der eingehenden `rateRatio`) als auch die zuvor ermittelte `residence time` (skaliert mit der soeben aktualisierten `rateRatio`):
$
  "correctionField"_("neu") = "correctionField"_("alt") + D dot "rateRatio"_("alt") + (t_s - t_r) dot "rateRatio"_("neu")
$
Der `preciseOriginTimestamp` bleibt dabei unverändert, da er stets die ursprüngliche Sendezeit der Grandmaster Clock referenziert; das `correctionField` trägt hingegen die seit dem Grandmaster akkumulierte Korrektur aus Laufzeit und Verarbeitungszeit.
== Hardware Grundlagen
Die in den vorangegangenen Abschnitten beschriebenen Synchronisations- und Messmechanismen setzen voraus, dass die beteiligten Zeitstempel mit einer dem geforderten Sub-Mikrosekundenbereich entsprechenden Genauigkeit erfasst werden. Dieses Kapitel beleuchtet die dafür notwendigen Hardware-Grundlagen. Im Folgenden wird zunächst erläutert, warum eine rein softwareseitige Zeitstempelung für gPTP ungeeignet ist und stattdessen spezialisierte Netzwerk-Hardware benötigt wird. Anschließend wird die Unterscheidung zwischen PHY- und MAC-Timestamping als zwei mögliche Realisierungsvarianten dieser Hardware-Zeitstempelung im Detail betrachtet.
=== Hardware-Timestamping
Wie in @comparison-ptp-gptp dargestellt, erfordert gPTP eine Genauigkeit im Sub-Mikrosekundenbereich. Diese Anforderung hat direkte Konsequenzen für die Art und Weise, wie die Zeitstempel erfasst werden müssen.\
Eine naheliegende Möglichkeit wäre, den Zeitstempel rein in Software zu erfassen, etwa in dem Moment, in dem die Applikation oder der Netzwerktreiber ein empfangenes Paket verarbeitet. Ein solcher Zeitstempel unterliegt jedoch mehreren nicht-deterministischen Verzögerungsquellen.
//todo: welche quellen? -> Interrupt Latenz, OS-Scheduling, Netzwerk-Stack, ...
Diese Verzögerungen summieren sich auf, das Abweichungen im Bereich mehrerer zehn bis hundert Mikrosekunden enstehen und damit zu einem Vielfachen der von gPTP geforderten Genauigkeit abweicht. Reines Software-Timestamping ist damit für gPTP ungeeignet.\
Aus diesem Grund wird für gPTP-fähige Systeme dedizierte Netzwerk-Hardware benötigt, die in der Lage ist, Zeitstempel autonom zu erfassen: Die Erfassung erfolgt direkt durch eine Logikeinheit in der Netzwerk-Hardware selbst, ausgelöst durch das tatsächliche Auftreten des Signals, und ist damit unabhängig von der aktuellen Auslastung der CPU oder des Betriebssystems. Diese Fähigkeit ist nicht bei jeder Ethernet-Hardware gegeben, sondern setzt entsprechend ausgestattete MAC-Controller bzw. PHY-Bausteine voraus.

=== PHY vs. MAC Timestamping
Für die im vorherigen Abschnitt beschriebenen Mechanismen — insbesondere die Messung der Leitungsverzögerung sowie der `residence time` — ist die Genauigkeit der Zeitstempel $t_1$ bis $t_4$ bzw. $t_r$ und $t_s$ entscheidend. Ein Hardware-Zeitstempel wird dabei erfasst, sobald ein definiertes Referenzsignal ( der Start Frame Delimiter, SFD) einer Ethernet-Nachricht erkannt wird. Je nachdem, an welcher Stelle im Signalpfad dieser Zeitpunkt erfasst wird, unterscheidet der Standard zwei Verfahren:

- *PHY-Timestamping:* Der Zeitstempel wird direkt im Physical-Layer-Baustein (PHY) erfasst, in dem Moment, in dem das Signal auf der physischen Leitung erkannt wird. Da hier keine weitere Verarbeitung oder Signalübertragung zwischen Erfassung und physischer Leitung liegt, gilt dieses Verfahren als das genaueste.

- *MAC-Timestamping:* Der Zeitstempel wird erst in der Media-Access-Control-Schicht (MAC) erfasst, nachdem der PHY dem MAC über eine dedizierte Schnittstelle signalisiert hat, dass ein Frame eingelesen wurde. Zwischen der eigentlichen physischen Ankunft des Signals und der Zeitstempel-Erfassung liegt dadurch eine zusätzliche, von der verwendeten Schnittstelle abhängige Latenz.

Diese zusätzliche Latenz stellt keinen reinen Nachteil dar, sofern sie bekannt und konstant ist: Der Standard sieht mit den Korrekturgrößen `ingressLatency` und `egressLatency` einen Mechanismus vor, um Zeitstempel unabhängig vom tatsächlichen Erfassungspunkt auf eine gemeinsame Referenzebene (die *reference plane* an der Media Dependent Interface, MDI) zurückzurechnen  Voraussetzung dafür ist jedoch, dass diese Latenz hinreichend deterministisch ist.

== Das Echtzeitbetriebssystem Zephyr

Nachdem die konzeptionellen Grundlagen des gPTP-Protokolls sowie die Anforderungen an die Hardware für eine präzise Zeitstempelung erläutert wurden, stellt dieses Kapitel das Echtzeitbetriebssystem Zephyr vor. Es dient als die Software-Plattform, in der die abstrakte Protokolllogik und die physikalischen Hardware-Fähigkeiten zusammengeführt werden, um eine funktionale Einheit zu bilden. Ein Echtzeitbetriebssystem (RTOS) ist speziell dafür entwickelt, Aufgaben innerhalb eines fest definierten Zeitrahmens auszuführen. Im Gegensatz zu normalen Betriebssystemen, die auf maximalen Durchsatz optimiert sind, kommt es beim RTOS auf Determinismus an. Das bedeutet: Das Zeitverhalten muss absolut vorhersagbar sein. Kern dabei ist der Scheduler, welcher die CPU-Zuweisung steuert. Dieser sorgt dafür, dass kritische Prozesse priorisiert werden und so ihre Fristen einhalten können.

Zephyr ist weit mehr als nur ein Kernel. Es ist ein vollständiges, modulares Ökosystem, das von der Linux Foundation verwaltet wird und Open-Source-Standards in die Embedded-Welt bringt. Im Gegensatz zu klassischen RTOS wie FreeRTOS, die meist nur einen einfachen Kernel anbieten, bringt Zephyr Treiber, Softwarestacks und viele weitere Komponenten mit.

=== Kernkonzepte und Architektur

Der Zephyr-Kernel zeichnet sich durch einen präemptiven, prioritätengesteuerten Scheduler aus. Diese Eigenschaft ist entscheidend für die Implementierung zeitkritischer Anwendungen wie einer gPTP-Bridge, da sie sicherstellt, dass hochpriorisierte Aufgaben, wie die Messung der `residence time`, mit minimaler und vorhersagbarer Latenz ausgeführt werden können.

Ein zentrales architektonisches Merkmal ist die Hardware-Abstraktion mittels *Device Tree*. Dieses Konzept, das auch in Linux verwendet wird, ermöglicht die Beschreibung der Hardware-Konfiguration (z.B. Ethernet-Peripherie, PTP-kompatible Timer) getrennt vom eigentlichen Applikationscode. Dadurch wird die maximale Portierbarkeit der Anwendung gewährleistet, da der C-Code ausschließlich die Zephyr-APIs anspricht und die spezifische Hardware-Anbindung über die Device Tree Definitionen erfolgt.


=== Netzwerkarchitektur und relevante Subsysteme

Die Architektur des Zephyr-Netzwerkstacks ist auf hohe Performance und Flexibilität ausgelegt, was durch mehrere Kernprinzipien erreicht wird. Ein zentrales Prinzip ist das „Zero-Copy“-Verfahren mittels sogenannter Netzwerk-Puffer (`net_buf`). Anstatt Datenpakete beim Durchlauf durch die Netzwerkschichten im Speicher zu kopieren, wird lediglich ein Zeiger auf den Puffer weitergereicht. Dies reduziert die CPU-Last und ist für die Implementierung einer gPTP-Bridge von hoher Relevanz, da die Minimierung von Kopiervorgängen entscheidend dazu beiträgt, die Verarbeitungszeit im Gerät (die `residence time`) gering und vorhersagbar zu halten.

Um die Integration von Protokollen wie gPTP zu ermöglichen und die präzisen Hardware-Fähigkeiten zu nutzen, stellt Zephyr eine Reihe relevanter Softwareschnittstellen (APIs) und Subsysteme bereit:

- Die *Layer-2-API* ermöglicht den direkten Zugriff auf Ethernet-Frames, welche das Transportmittel für gPTP-Nachrichten darstellen. Dies ist zwingend erforderlich, da gPTP auf Layer 2 operiert und höhere Protokollschichten wie IP oder UDP umgangen werden müssen.

- Die *Timestamping-Schnittstelle* bildet die softwareseitige Abstraktion für die im Kapitel `Hardware Grundlagen` erläuterten MAC-Timestamping-Fähigkeiten. Sie ist das entscheidende Bindeglied, das es der Protokoll-Implementierung ermöglicht, auf die für die gPTP-Algorithmen nötigen Zeitstempel ($t_1$ bis $t_4$) präzise zuzugreifen.
- Ergänzt wird dies durch *PTP-Clock-Treiber*, über welche die Hardware-Timer, die als Referenz für die lokale Zeit dienen, dem System zur Verfügung gestellt und von der gPTP-Logik synchronisiert werden können. Diese Treiber kapseln die spezifischen Registerzugriffe der Hardware.

Der *Datenfluss* im Stack lässt sich am besten anhand des Weges eines Pakets nachvollziehen, wobei die oben genannten Komponenten zum Einsatz kommen. Der *Ingress-Pfad* (Empfang) beginnt, wenn ein Ethernet-Frame von der Hardware empfangen wird. Wie im Kapitel `Hardware Grundlagen` beschrieben, kann hier durch den MAC-Controller ein Hardware-Zeitstempel erfasst werden. Der Zephyr-*Ethernet-Treiber* nimmt diesen Frame samt Zeitstempel-Metadaten entgegen, verpackt ihn in einen `net_buf` und reiht ihn in eine zentrale Verarbeitungswarteschlange ein. An dieser Stelle im Software-Stack sind nun alle Informationen verfügbar, welche die gPTP-Protokolllogik zur Berechnung des `ingress timestamps (t2)` benötigt.

Beim *Egress-Pfad* (Senden) erstellt die Applikationslogik einen `net_buf`, der die zu sendende Nachricht enthält. Dieser wird über die Layer-2-API an den Treiber übergeben. Nachdem der Treiber das Paket physisch versendet und der MAC den exakten Sendezeitpunkt als `egress timestamp (t1)` erfasst hat, wird diese Zeitinformation über einen Callback-Mechanismus (`tx_tstamp`) der Timestamping-Schnittstelle an die Applikation zurückgemeldet. Dieser Mechanismus ist die softwareseitige Realisierung der Anforderung aus dem gPTP-Standard, den exakten Sendezeitpunkt für die Erstellung der `Follow_Up`-Nachricht zu kennen.

TODO: Stack als modulare, schichtbasierte architektur darstellen





