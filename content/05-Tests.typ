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
Das eigentliche Versprechen einer Time-Aware Bridge im Sinne von #acr("TSN") besteht nicht nur darin, unter Idealbedingungen synchron zu bleiben, sondern insbesondere auch dann, wenn dieselbe physische Verbindung gleichzeitig von Best-Effort-Nutzverkehr belegt wird. Die bisherigen Messungen fanden ausschließlich in einem ansonsten unbelasteten Netz statt. Dieser Test soll zeigen, ob die #acr-emph("gPTP")-Synchronisation der Bridge auch dann erhalten bleibt, wenn ihr Port gleichzeitig mit einer möglichst hohen Datenmenge belastet wird.

=== Testaufbau
Anstelle der vollständigen Kette (Grandmaster $<->$ Bridge 1 $<->$ Bridge 2 $<->$ Bridge 3 $<->$ Endpunkt) wurde der Test auf die ersten beiden Hops reduziert (Grandmaster $<->$ Bridge 1 $<->$ Endpoint). So lässt sich die Wirkung der Last isoliert an Bridge 1 beobachten, während der Endpoint gleichzeitig den Nachweis der kumulativen #acr-emph("E2E")-Synchronisationsgenauigkeit nach @tab-zeitanforderungen über beide Hops liefert.

Als Lastgenerator kommt `zperf` zum Einsatz, ein in Zephyr eingebautes, shellgesteuertes Werkzeug zur Messung des Netzwerkdurchsatzes @zephyr_zperf. Der Grandmaster sendet dabei per #acr-emph("UDP") eine konstante Datenrate an einen auf Bridge 1 laufenden `zperf`-Server - über denselben physischen Port, über den auch die #acr("gPTP")-Nachrichten laufen. #acr-emph("UDP") wurde hier bewusst gegenüber #acr("TCP") bevorzugt, da dessen Congestion Control die tatsächlich angebotene Last variabel und damit für die Messung schwerer kontrollierbar macht. `zperf` erlaubt es stattdessen, eine feste Ziel-Bitrate vorzugeben und den tatsächlich erreichten Durchsatz sowie den Paketverlust getrennt auf Sender- und Empfängerseite auszuwerten.

Bridge 1 lief für den hier ausgewerteten Testlauf mit vier priorisierten Sende- und Empfangswarteschlangen (`CONFIG_NET_TC_TX_COUNT`/`_RX_COUNT` $=4$), die Nutzlast, Follow-Up/Announce- und Sync/Pdelay-Nachrichten anhand des in IEEE 802.1Q definierten Priority-Code-Points jeweils eigenen Warteschlangen zuordnen @zephyr_net_l2. Zusätzlich sind sämtliche Empfangspuffer auf ein durch Datentyp beziehungsweise Treiber vorgegebenes Maximum angehoben: `CONFIG_NET_PKT_RX_COUNT`/`_TX_COUNT` $=1024$, `CONFIG_NET_BUF_RX_COUNT`/`_TX_COUNT` $=4096$ sowie die vom NXP-ENET-Treiber separat verwalteten #acr-emph("DMA")-Deskriptorringe `CONFIG_ETH_NXP_ENET_RX_BUFFERS`/`_TX_BUFFERS` $=16$ (jeweils das treiberseitige Kconfig-Maximum).

Bei dieser Konfiguration wurde der Grandmaster angewiesen, über $960"s"$ konstant $15"Mbit/s"$ #acr("UDP")-Last mit $1"KB"$ großen Paketen an Bridge 1 zu senden (`zperf udp upload -a 10.0.1.2 5001 30 1K 15M`), während zeitgleich an drei #acr-emph("PPS")-Messpunkten - Bridge 1 (Slave-Port, GM-seitig), Bridge 1 (Master-Port, Endpoint-seitig) und Endpoint - die in Kapitel "Analyse und Entwurf" beschriebene Oszilloskop-Messung gegen den #acr("GM") als Referenz mitlief.

=== Ergebnisse
@tab-netzwerklast-durchsatz fasst die auf Bridge 1 gemessene Durchsatz- und Verlustkennzahl zusammen. Die von Grandmaster und Bridge 1 unabhängig protokollierten Werte stimmen dabei überein.

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
  caption: [Zeitlicher Verlauf des PPS-Offsets aller drei Messpunkte relativ zum Grandmaster über die gesamte Testdauer aus @tab-netzwerklast-durchsatz],
) <fig-pps-netzwerklast>

@fig-pps-netzwerklast zeigt denselben Datensatz als Zeitreihe. Die Synchronisation war bereits vor Beginn der Messung eingeschwungen. Bridge 1 Slave- und Master-Port liegen über die gesamte Testdauer in einem engen, gemeinsamen Band von rund $100$ bis $200"ns"$, während der Endpoint durchgehend auf der gegenüberliegenden Seite der Null-Linie liegt, meist zwischen $-100$ und $-250"ns"$ - dieselbe Vorzeichenumkehr, die bereits die Mittelwerte in @tab-pps-netzwerklast zeigen.

Zwei Ausreißer stechen dabei hervor. Bereits ganz zu Beginn der Messung, bei $t approx 10"s"$, springt allein der Endpoint auf einen negativen Extremwert in der Größenordnung des in @tab-pps-netzwerklast verzeichneten Minimums von $-1,191mu s$ - ohne dass Bridge 1 zu diesem Zeitpunkt aus ihrem Band ausschlägt. Da dieser Ausreißer isoliert am Endpoint auftritt und Bridge 1 bereits von Beginn an in ihrem eingeschwungenen Band liegt, handelt es sich vermutlich um einen eigenen, dem Endpoint zuzuordnenden Einschwingvorgang - er reiht sich damit nicht in die weiter unten beschriebenen, über die gesamte Messung verteilten Endpoint-Störungen ein, sondern bleibt auf die ersten Sekunden der Messung beschränkt.

Der zweite, allen drei Messpunkten gemeinsame Ausreißer liegt bei $t approx 470"s"$: An genau dieser #acr-emph("PPS")-Periode springen Bridge 1 und Endpoint gleichzeitig aus ihrem sonst engen Band. Bridge 1 auf die in @tab-pps-netzwerklast verzeichneten Maximalwerte ($499"ns"$ Slave-Port, $538"ns"$ Master-Port), der Endpoint zeitgleich auf einen ähnlich ausgeprägten negativen Ausschlag. Da alle drei Messpunkte exakt dieselbe Periode betrifft, liegt eine gemeinsame Ursache näher als unabhängiges Rauschen an drei verschiedenen Messpunkten - am wahrscheinlichsten eine zu diesem Zeitpunkt verlorene oder verzögerte #acr("gPTP")-Nachricht, die sich über die gesamte Kette fortpflanzt.

Daneben zeigt insbesondere der Endpoint über die Messung verteilt weitere isolierte Ausreißer, die sich nicht in gleicher Form bei Bridge 1 zeigen - ein Hinweis darauf, dass ein Teil der Streuung erst auf dem zweiten Hop (Bridge 1 zum Endpoint) entsteht und nicht bereits auf dem ersten Hop (Grandmaster zu Bridge 1) angelegt ist.

=== Einordnung
Für die angebotene Last von $15"Mbit/s"$ zeigt dieser Testlauf, dass die zentrale Eigenschaft einer Time-Aware Bridge im Sinne von #acr("TSN") erfüllt ist: Die Zeitsynchronisation bleibt innerhalb der normativen Anforderung, obwohl der Best-Effort-Durchsatz auf demselben Port mit $6,25"%"$ Paketverlust bereits spürbar eingeschränkt ist. Genau das ist das eigentliche Kernversprechen von #acr("TSN"). Möglich wurde dieses Ergebnis erst durch die in Abschnitt "Testaufbau" beschriebene Konfiguration aus priorisierten Warteschlangen und maximierten Puffer-Pools.

Die Aussage bleibt dabei bewusst auf die hier gewählte Lastgröße beschränkt: Der Test weist nach, dass die Synchronisation bei $15"Mbit/s"$ angebotener Last über $16$ Minuten hinweg innerhalb der Anforderung blieb, nicht, dass dies für beliebig hohe Lasten gilt. Wie sich der #acr-emph("E2E")-Offset verhält, wenn die angebotene Last über den in @tab-netzwerklast-durchsatz erreichten Durchsatz von $12,49"Mbit/s"$ hinaus weiter gesteigert wird, wurde im Rahmen dieser Arbeit nicht als durchgehende Kennlinie erfasst.
#note[Mehr Test mit unterschiedlichen Größen folgen.]

802.1AS selbst schreibt dabei keine bestimmte Warteschlangen- oder Priorisierungsstrategie vor - der Standard definiert ausschließlich das Protokoll und die daraus resultierenden Genauigkeitsanforderungen, nicht wie die darunterliegende Ethernet-Schicht dafür sorgt, dass Nachrichten rechtzeitig ankommen. Die vorgenommene Anpassung (Sende-Warteschlangen nach Priorität) bewegt sich im Rahmen von IEEE 802.1Q - Priority-Code-Point und Traffic-Class-Zuordnung.

=== Ausblick
Für eine belastbare Kennlinie sollte dieser Test bei mehreren Laststufen unterhalb und oberhalb der hier eingesetzten $15"Mbit/s"$ wiederholt werden, jeweils mit mehreren Wiederholungen je Stufe und definiertem Reset der Bridge zwischen den Läufen, um die in @fig-pps-netzwerklast beobachtete Schwankung einzelner Perioden von einer systematischen Verschlechterung bei höherer Last unterscheiden zu können. Der in @fig-pps-netzwerklast bei $t approx 470"s"$ identifizierte, gemeinsame Ausreißer ließe sich zudem gezielt mit dem zeitgleich auf der Bridge protokollierten Paketverlust korrelieren, um die dort geäußerte Vermutung einer verlorenen oder verzögerten #acr("gPTP")-Nachricht als Ursache zu erhärten.

Ein weiterer, in dieser Arbeit nicht umgesetzter Ansatz betrifft die Hardware selbst: Die Gigabit-Instanz (`enet1g`) des verwendeten #acr("SoC") verfügt - im Gegensatz zur 10/100-Mbit-Instanz (`enet`), die in diesem Testaufbau zum Einsatz kam - über eine AVB-fähige Empfangs-Klassifizierung mit mehreren Hardware-Warteschlangen und einem sogenannten Receive-Classification-Match-Register je Warteschlange @nxp_imxrt1170_refman. Damit ließe sich die Zuordnung eines Rahmens zu einer Warteschlange bereits in der #acr("MAC")-Hardware vornehmen, bevor überhaupt ein Speicherpuffer im Netzwerk-Stack allokiert wird. Was aber nicht Teil dieser Arbeit ist.
