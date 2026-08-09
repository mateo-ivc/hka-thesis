#import "../meta.typ": acr-emph, fig-platzhalter-mittel, note, tab-d, tab-h
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Tests

*Tests*:
//https://www2.informatik.uni-stuttgart.de/bibliothek/ftp/ncstrl.ustuttgart_fi/TR-2021-02/TR-2021-02.pdf
- Testaufbau wo die Clock mehrere Stunden läuft -> Um eine Langzeitstabilität analysieren zukönnen.
  - gemessen wird: PPS-Signal üebr 6H, es werden logs aufgezeichnet, dabei wird der

- Simulierte Systemlast -> Um zu zeigen, dass die Synchronisierung auch unter Last funktioniert.
  - Ein task der ständig etwas berechnet und somit die CPU last hochzieht.
  - Die Clocks sollten weiterhin Synchron bleiben, da Zephyr die Tasks geschickt scheduled

- Auseinanderlaufen von Clocks zeigen durch Zeitsynchronisierung (keine Syntonisierung)

== Basis PPS-Messung


== Simulierte Netzwerklast

=== Ziel
Das eigentliche Versprechen einer Time-Aware Bridge im Sinne von #acr("TSN") besteht nicht nur darin, unter Idealbedingungen synchron zu bleiben, sondern insbesondere auch dann, wenn dieselbe physische Verbindung gleichzeitig von Best-Effort-Nutzverkehr belegt wird. Die bisherigen Messungen fanden ausschließlich in einem ansonsten unbelasteten Netz statt.

Dieser Test verfolgt daher zwei Ziele. Zum einen soll er zeigen, ob die #acr-emph("gPTP")-Synchronisation der Bridge auch dann innerhalb der nach @tab-zeitanforderungen geforderten Grenzen bleibt, wenn ihr Port gleichzeitig mit einer möglichst hohen Datenmenge belastet wird. Zum anderen soll er nachweisen, dass dies keine Eigenschaft des unveränderten Netzwerkstacks ist, sondern erst durch die in @impl-lastschutz beschriebenen Maßnahmen erreicht wird. Der Test wird deshalb als Vorher-Nachher-Vergleich mit identischem Lastprofil und identischem Messaufbau durchgeführt.

=== Testaufbau
Anstelle der vollständigen Kette (Grandmaster $<->$ Bridge 1 $<->$ Bridge 2 $<->$ Bridge 3 $<->$ Endpunkt) wurde der Test auf die ersten beiden Hops reduziert (Grandmaster $<->$ Bridge 1 $<->$ Endpoint). So lässt sich die Wirkung der Last isoliert an Bridge 1 beobachten, während der Endpoint gleichzeitig den Nachweis der kumulativen #acr-emph("E2E")-Synchronisationsgenauigkeit nach @tab-zeitanforderungen über beide Hops liefert.

Als Lastgenerator kommt `zperf` zum Einsatz, ein in Zephyr eingebautes, shellgesteuertes Werkzeug zur Messung des Netzwerkdurchsatzes @zephyr_zperf. Der Grandmaster sendet dabei per #acr-emph("UDP") eine konstante Datenrate an einen auf Bridge 1 laufenden `zperf`-Server - über denselben physischen Port, über den auch die #acr("gPTP")-Nachrichten laufen. #acr-emph("UDP") wurde hier bewusst gegenüber #acr("TCP") bevorzugt, da dessen Congestion Control die tatsächlich angebotene Last variabel und damit für die Messung schwerer kontrollierbar macht. `zperf` erlaubt es stattdessen, eine feste Ziel-Bitrate vorzugeben und den tatsächlich erreichten Durchsatz sowie den Paketverlust getrennt auf Sender- und Empfängerseite auszuwerten.

Zeitgleich läuft an drei #acr-emph("PPS")-Messpunkten - Bridge 1 (Slave-Port, GM-seitig), Bridge 1 (Master-Port, Endpoint-seitig) und Endpoint - die in Kapitel "Analyse und Entwurf" beschriebene Oszilloskop-Messung gegen den #acr("GM") als Referenz mit. Zusätzlich protokolliert Bridge 1 sekündlich die am belasteten Port tatsächlich empfangene Datenrate sowie den Anteil verworfener Rahmen, getrennt nach Nutzlast und #acr("gPTP")-Verkehr, sodass sich der Synchronisationsverlauf direkt der jeweils anliegenden Last gegenüberstellen lässt.

=== Untersuchte Konfigurationen
Verglichen werden zwei Softwarestände derselben Bridge, die sich ausschließlich in den Maßnahmen aus @tab-lastschutz-massnahmen unterscheiden:

*Konfiguration A (Ausgangszustand)* verwendet den unveränderten ENET-Treiber und mit dem Änderungen aus @bridge-sync-impl und @anpassungen-in-zephyr. #acr("gPTP")-Nachrichten sind nicht als eigene Verkehrsklasse gekennzeichnet, teilen sich den Best-Effort-Sende-Ring mit der Nutzlast und werden aus demselben globalen Empfangs-Pufferpool bedient.

*Konfiguration B* aktiviert sämtliche Maßnahmen aus @tab-lastschutz-massnahmen: VLAN-Kennzeichnung der #acr("gPTP")-Nachrichten, den kreditgeformten Sende-Ring, die verschränkte Bedienung beider Empfangs-Ringe, die eigene Empfangs-Verkehrsklasse sowie den reservierten Empfangs-Pufferpool.

Alle übrigen Einstellungen sind in beiden Konfigurationen identisch. Beide laufen mit vier Sende- und Empfangs-Verkehrsklassen (`CONFIG_NET_TC_TX_COUNT`/`_RX_COUNT` $=4$), die Rahmen anhand des in IEEE 802.1Q definierten Priority-Code-Points eigenen Warteschlangen zuordnen @zephyr_net_l2, und mit auf das jeweilige Maximum angehobenen Puffern: `CONFIG_NET_PKT_RX_COUNT`/`_TX_COUNT` $=1024$, `CONFIG_NET_BUF_RX_COUNT`/`_TX_COUNT` $=4096$ sowie die vom NXP-ENET-Treiber separat verwalteten #acr-emph("DMA")-Deskriptorringe `CONFIG_ETH_NXP_ENET_RX_BUFFERS`/`_TX_BUFFERS` $=16$.

Hervorzuheben ist dabei, dass diese Verkehrsklassen in Konfiguration A auf der Empfangsseite trotz Konfiguration wirkungslos bleiben: Wie in @impl-lastschutz beschrieben, weist der unveränderte Treiber eingehenden Rahmen keine Priorität zu, sodass #acr("gPTP")-Nachrichten und Nutzlast unabhängig von dieser Einstellung in derselben Warteschlange landen. Die Trennung der Verkehrsklassen greift erst in Konfiguration B.

=== Ergebnisse in Konfiguration A bei geringer Last
Ein erster Lauf in Konfiguration A wurde mit einer konstanten Last von $15"Mbit/s"$ und $1"KB"$ großen Paketen über $960"s"$ durchgeführt (`zperf udp upload -a 10.0.1.2 5001 30 1K 15M`). @tab-netzwerklast-durchsatz fasst die auf Bridge 1 gemessene Durchsatz- und Verlustkennzahl zusammen. Die von Grandmaster und Bridge 1 unabhängig protokollierten Werte stimmen dabei überein.

#figure(
  table(
    columns: (1fr, 1fr),
    align: (left, left),
    stroke: none,
    table.hline(),
    tab-h[Metrik], tab-h[Wert],
    table.hline(stroke: 0.5pt),
    tab-d[Angebotene Rate], tab-d[15,00 Mbit/s],
    tab-d[Laufzeit], tab-d[16,00 min (960 s)],
    tab-d[Übertragene Pakete], tab-d[1.599.999],
    tab-d[Empfangene Pakete], tab-d[1.499.951],
    tab-d[Verlorene Pakete], tab-d[100.048],
    tab-d[Paketverlust], tab-d[6,25 %],
    tab-d[Effektiver Durchsatz], tab-d[12,49 Mbit/s],
    tab-d[Jitter], tab-d[588 µs],
    table.hline(),
  ),
  caption: [Von Grandmaster und Bridge 1 übereinstimmend protokollierter `zperf`-UDP-Lasttest (Paketgröße 1 KB, Zielrate 15 Mbit/s, Laufzeit 16 min)],
) <tab-netzwerklast-durchsatz>

Entscheidend ist an dieser Stelle nicht der Durchsatz selbst, sondern ob die #acr("gPTP")-Synchronisation über die gesamte Testdauer innerhalb der nach @tab-zeitanforderungen geforderten #acr-emph("E2E")-Synchronisationsgenauigkeit von $1mu s$ @ieee8021as2025[B.3] blieb, während gleichzeitig gut ein Sechzehntel der angebotenen Nutzlast auf demselben physischen Port verworfen wurde. @tab-pps-netzwerklast fasst die zeitgleich aufgezeichnete Oszilloskop-Messung zusammen.

#figure(
  table(
    columns: (1.6fr, 1fr, 1fr, 1fr, 1fr, 0.7fr),
    align: (left, left, left, left, left, left),
    stroke: none,
    table.hline(),
    tab-h[Messpunkt (GM-relativ)], tab-h[Mittelwert], tab-h[Std.-Abw.], tab-h[Min], tab-h[Max], tab-h[N],
    table.hline(stroke: 0.5pt),
    tab-d[Bridge 1, Slave-Port], tab-d[121 ns], tab-d[67 ns], tab-d[-525 ns], tab-d[499 ns], tab-d[972],
    tab-d[Bridge 1, Master-Port], tab-d[153 ns], tab-d[75 ns], tab-d[-512 ns], tab-d[538 ns], tab-d[950],
    tab-d[Endpoint (E2E, 2 Hops)], tab-d[-159 ns], tab-d[102 ns], tab-d[-1,191 µs], tab-d[480 ns], tab-d[982],
    table.hline(),
  ),
  caption: [PPS-Offset relativ zum Grandmaster während des Lasttests aus @tab-netzwerklast-durchsatz, gemessen mit dem Keysight MSOX3104T @keysight_msox3104t (N = Anzahl der von 1000 aufgezeichneten PPS-Perioden mit gültiger Flanke)],
) <tab-pps-netzwerklast>

Der #acr-emph("E2E")-Offset am Endpoint bleibt im Mittel bei $-159"ns"$ mit einer Standardabweichung von $102"ns"$ - deutlich innerhalb der geforderten $1mu s$. Auch die beiden Bridge-1-internen Messpunkte liegen mit Mittelwerten von $121"ns"$ beziehungsweise $153"ns"$ und vergleichbar geringer Streuung in derselben Größenordnung: Die Synchronisation blieb während des gesamten, durch Paketverlust geprägten Lasttests intakt.

#figure(
  image("../assets/Tests/pps-offset-netzwerklast.png", width: 100%),
  caption: [Zeitlicher Verlauf des PPS-Offsets aller drei Messpunkte relativ zum Grandmaster in Konfiguration A über die gesamte Testdauer aus @tab-netzwerklast-durchsatz],
) <fig-pps-netzwerklast>

@fig-pps-netzwerklast zeigt denselben Datensatz als Zeitreihe. Die Synchronisation war bereits vor Beginn der Messung eingeschwungen. Bridge 1 Slave- und Master-Port liegen über die gesamte Testdauer in einem engen, gemeinsamen Band von rund $100$ bis $200"ns"$, während der Endpoint durchgehend auf der gegenüberliegenden Seite der Null-Linie liegt, meist zwischen $-100$ und $-250"ns"$ - dieselbe Vorzeichenumkehr, die bereits die Mittelwerte in @tab-pps-netzwerklast zeigen.

Zwei Ausreißer stechen dabei hervor. Bereits ganz zu Beginn der Messung, bei $t approx 10"s"$, springt allein der Endpoint auf einen negativen Extremwert in der Größenordnung des in @tab-pps-netzwerklast verzeichneten Minimums von $-1,191mu s$ - ohne dass Bridge 1 zu diesem Zeitpunkt aus ihrem Band ausschlägt. Da dieser Ausreißer isoliert am Endpoint auftritt und Bridge 1 bereits von Beginn an in ihrem eingeschwungenen Band liegt, handelt es sich vermutlich um einen eigenen, dem Endpoint zuzuordnenden Einschwingvorgang - er reiht sich damit nicht in die weiter unten beschriebenen, über die gesamte Messung verteilten Endpoint-Störungen ein, sondern bleibt auf die ersten Sekunden der Messung beschränkt.

Der zweite, allen drei Messpunkten gemeinsame Ausreißer liegt bei $t approx 470"s"$: An genau dieser #acr-emph("PPS")-Periode springen Bridge 1 und Endpoint gleichzeitig aus ihrem sonst engen Band. Bridge 1 auf die in @tab-pps-netzwerklast verzeichneten Maximalwerte ($499"ns"$ Slave-Port, $538"ns"$ Master-Port), der Endpoint zeitgleich auf einen ähnlich ausgeprägten negativen Ausschlag. Da alle drei Messpunkte exakt dieselbe Periode betrifft, liegt eine gemeinsame Ursache näher als unabhängiges Rauschen an drei verschiedenen Messpunkten - am wahrscheinlichsten eine zu diesem Zeitpunkt verlorene oder verzögerte #acr("gPTP")-Nachricht, die sich über die gesamte Kette fortpflanzt.

Daneben zeigt insbesondere der Endpoint über die Messung verteilt weitere isolierte Ausreißer, die sich nicht in gleicher Form bei Bridge 1 zeigen - ein Hinweis darauf, dass ein Teil der Streuung erst auf dem zweiten Hop (Bridge 1 zum Endpoint) entsteht und nicht bereits auf dem ersten Hop (Grandmaster zu Bridge 1) angelegt ist.

Für sich genommen legt dieser Lauf nahe, die Anforderung sei bereits im Ausgangszustand erfüllt. Bei $15"Mbit/s"$ auf einem Gigabit-Link ist die Bridge jedoch weit von ihrer Kapazitätsgrenze entfernt: Die $6,25"%"$ Paketverlust entstehen nicht durch eine überlastete Leitung, sondern durch die Verarbeitungsgeschwindigkeit der Bridge, und sie treffen bei dieser Rate noch ausschließlich die Nutzlast. Die Frage, ob #acr("gPTP") gegenüber der Nutzlast tatsächlich bevorzugt behandelt wird, stellt sich erst, wenn die Bridge so weit belastet wird, dass sie Rahmen verwerfen muss, ohne zwischen beiden unterscheiden zu können. Der folgende Lauf steigert die Last deshalb stufenweise.

=== Ergebnisse in Konfiguration A bei gesteigerter Last
#note[
  Hier den eigentlichen Nachweislauf einsetzen: Konfiguration A mit demselben Stufenprofil wie der Lauf in Konfiguration B (drei Stufen à $300"s"$). Benötigt werden dieselben drei Artefakte wie unten - Durchsatz-/Verlusttabelle je Laststufe, PPS-Offset-Tabelle je Laststufe und die kombinierte Abbildung aus PPS-Offset und Netzwerklast. Entscheidend für die Argumentation ist, ab welcher Laststufe der Offset das $1mu s$-Toleranzband verlässt und ob zu diesem Zeitpunkt auch #acr("gPTP")-Rahmen verworfen werden (Anteil `ptp_drop`) - Letzteres ist der direkte Beleg dafür, dass es sich um fehlende Priorisierung und nicht um allgemeine Überlast handelt.
]

#fig-platzhalter-mittel(
  caption: [Zeitlicher Verlauf des PPS-Offsets und der Netzwerklast in Konfiguration A],
  label: <fig-pps-netzwerklast-ohne-cbs>,
)[
  Zwei übereinanderliegende Diagramme über gemeinsamer Zeitachse: oben der #acr("PPS")-Offset der drei Messpunkte relativ zum #acr("GM") mit eingezeichnetem $1mu s$-Toleranzband, unten die tatsächlich empfangene Datenrate als Stufenprofil sowie der Anteil erfolgreich verarbeiteter, verworfener und speziell verworfener #acr("gPTP")-Rahmen. Erwartet wird, dass der Offset mit steigender Laststufe das Toleranzband verlässt.
]

=== Ergebnisse in Konfiguration B
Derselbe Lauf wurde anschließend mit Konfiguration B wiederholt. Die Last wurde dabei in drei Stufen von je rund $300"s"$ gesteigert; die am Port von Bridge 1 tatsächlich empfangene Datenrate lag dabei bei rund $14$, $28$ und $42"Mbit/s"$.

#figure(
  image("../assets/Tests/pps_offset_netzwerklast_cbs.png", width: 100%),
  caption: [PPS-Offset relativ zum Grandmaster (oben) und tatsächlich empfangene Netzwerklast mit Drop-Anteil (unten) in Konfiguration B über drei Laststufen],
) <fig-pps-netzwerklast-cbs>

@fig-pps-netzwerklast-cbs zeigt beide Größen über einer gemeinsamen Zeitachse. Ausschlaggebend ist der Vergleich der beiden Teildiagramme: Obwohl die angebotene Last zweimal sprunghaft ansteigt und der Anteil verworfener Nutzlastrahmen dabei über die Hälfte des Eingangsverkehrs erreicht, ist an den beiden Lastwechseln bei $t approx 300"s"$ und $t approx 600"s"$ im Offset-Verlauf keine Reaktion erkennbar. Beide Bridge-1-Messpunkte verbleiben über die gesamte Messdauer in einem gemeinsamen Band von rund $50$ bis $250"ns"$, der Endpoint spiegelbildlich zwischen etwa $-50$ und $-300"ns"$ - dieselbe Vorzeichenumkehr wie in @fig-pps-netzwerklast. Alle drei Messpunkte bleiben durchgehend deutlich innerhalb der geforderten $1mu s$, und die in @fig-pps-netzwerklast noch auffälligen, alle Messpunkte gleichzeitig betreffenden Ausreißer treten nicht mehr auf.

#note[
  Statistik-Tabelle analog zu @tab-pps-netzwerklast ergänzen, sinnvollerweise getrennt je Laststufe, damit sichtbar wird, dass Mittelwert und Streuung über die Stufen hinweg konstant bleiben. Ebenso die Durchsatz-/Verlusttabelle je Stufe inklusive des Anteils verworfener #acr("gPTP")-Rahmen - dieser sollte in Konfiguration B über alle Stufen null bleiben.
]

=== Vergleich und Einordnung
#note[
  Diesen Abschnitt nach Vorliegen des Laufs aus Konfiguration A schärfen; die folgende Argumentation ist bereits darauf ausgelegt, benötigt aber die konkreten Zahlen.
]

Der Vergleich beider Konfigurationen trennt zwei Aussagen, die sich aus einem einzelnen Lauf nicht trennen ließen. Zum einen bleibt die Zeitsynchronisation in Konfiguration B innerhalb der normativen Anforderung, obwohl der Best-Effort-Durchsatz auf demselben Port bereits massiv eingeschränkt ist - genau das ist das Kernversprechen von #acr("TSN"): Nicht die Leitung wird ausgelastet, sondern die zeitkritische Verkehrsklasse wird gegenüber der unkritischen bevorzugt, und die Degradation trifft ausschließlich Letztere. Zum anderen zeigt Konfiguration A, dass dies keine Eigenschaft des unveränderten Stacks ist.

Bemerkenswert ist dabei, worin die Bevorzugung tatsächlich besteht. Der #acr("CBS") selbst regelt ausschließlich die Senderichtung, die Last trifft die Bridge in diesem Szenario aber am Eingang. Der messbare Unterschied zwischen beiden Konfigurationen entsteht daher überwiegend durch die in @impl-lastschutz beschriebenen empfangsseitigen Maßnahmen - die eigene Verkehrsklasse und vor allem den reservierten Pufferpool. Der Shaper reserviert Sendebandbreite, der eigene Ring einen Zugangsweg in den Treiber; keiner von beiden reserviert jedoch Speicher, und ohne reservierte Puffer wird die Klassifizierung bereits bei der ersten Allokation im Treiber wirkungslos. Die Maßnahmen sind deshalb bewusst nicht einzeln bewertet worden.

802.1AS selbst schreibt dabei keine bestimmte Warteschlangen- oder Priorisierungsstrategie vor - der Standard definiert ausschließlich das Protokoll und die daraus resultierenden Genauigkeitsanforderungen, nicht wie die darunterliegende Ethernet-Schicht dafür sorgt, dass Nachrichten rechtzeitig ankommen. Die vorgenommenen Anpassungen bewegen sich im Rahmen von IEEE 802.1Q (Priority-Code-Point und Traffic-Class-Zuordnung) sowie IEEE 802.1Qav (Credit Based Shaping) @ieee8021qav2009 und sind damit standardkonform, aber nicht durch 802.1AS gefordert.

Die Aussage bleibt bewusst auf die hier gefahrenen Laststufen beschränkt: Der Test weist nach, dass die Synchronisation in Konfiguration B bis zu der höchsten gefahrenen Stufe innerhalb der Anforderung blieb, nicht, dass dies für beliebig hohe Lasten gilt. Eine durchgehende Kennlinie bis zur Leitungsgrenze wurde im Rahmen dieser Arbeit nicht erfasst.

=== Ausblick
Für eine belastbare Kennlinie sollte der Test in beiden Konfigurationen mit feineren Laststufen und mehreren Wiederholungen je Stufe bei definiertem Reset der Bridge zwischen den Läufen wiederholt werden, um die in @fig-pps-netzwerklast beobachtete Schwankung einzelner Perioden von einer systematischen Verschlechterung bei höherer Last unterscheiden zu können. Der in @fig-pps-netzwerklast bei $t approx 470"s"$ identifizierte, gemeinsame Ausreißer ließe sich zudem gezielt mit dem zeitgleich auf der Bridge protokollierten Paketverlust korrelieren, um die dort geäußerte Vermutung einer verlorenen oder verzögerten #acr("gPTP")-Nachricht als Ursache zu erhärten.

Ein weiterer, in dieser Arbeit nicht umgesetzter Ansatz betrifft die Hardware selbst: Die Gigabit-Instanz (`enet1g`) des verwendeten #acr("SoC") verfügt - im Gegensatz zur 10/100-Mbit-Instanz (`enet`) - über eine AVB-fähige Empfangs-Klassifizierung mit mehreren Hardware-Warteschlangen und einem sogenannten Receive-Classification-Match-Register je Warteschlange @nxp_imxrt1170_refman. Damit ließe sich die Zuordnung eines Rahmens zu einer Warteschlange bereits in der #acr("MAC")-Hardware vornehmen, statt sie wie in @impl-lastschutz beschrieben im Treiber auf dem bereits eingelesenen Rahmen vorzunehmen. Für die 10/100-Mbit-Instanz, die diese Hardware nicht besitzt, bliebe die Klassifizierung im Treiber dennoch erforderlich.
