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
Warum reicht normales Ethernet für Echtzeitanwendungen?
- Best-Effort-Prinzip, fehlende Determinismus

Welche Rolle spielt die Zeitsynchronisation:
- TSN besteht aus mehreren Rollen, als Grundbaustein steht gPTP im vordergrund um nachfolgende Protokolle wie Time-Aware Shaper (802.1Qbv) erst zu ermöglichen.


== Das Zeitsynchronisationsprotokoll IEEE 802.1AS
Dieses Kaptiel beschreibt das Zeitsynchronisationsprotokoll IEEE 802.1AS, das im TSN-Kontext auch als gPTP (Generalized Precision Time Protocol) bezeichent wird. gPTP definiert Verfahren, um die Uhren verteilert System über ein lokases Netzwerk im Sub-Mikrosekundenbereich zu synchronisieren. Im Folgenden werden die Abgrenzungen zu anderen Protokollen, die Netzwerktopologie, die Synchronisations- und Messmechanismen sowie die Rolle einer gPTP-Bridge im Detail erläutert.


=== Einordnung und Abgrenzung
Um die Notwendigkeit von gPTP besser zu verstehen, muss es gegeüber dem im Internet etablierten Network Time Protocol (NTP) sowie dem ursprünglichem Precision Time Protocol (PTPv2/IEEE 1588) abgegrenzt werden.
//todo: vergleichs tabelle mit vergleich zwischen den verschieden protokollen

/*
Genauigkeit     | wie genau synchronisiert das protokoll (ms, ns,...?)
Hardwarebedarf  | welche extra Hardware benötigt es
Netzwerktyp     | in welchen Netzwerken wird es verwendent (LAN, WLAN, lokal, ...)
Architektur     | art der Synchoronisierung (E2E, P2P)
Komplexität     | wie komplex ist die implementierung
Einstatzgebiert | wo ist es sinnvoll das protokoll zu verwenden

*/
#figure(
  table(
    columns: (1.5fr, 1.8fr, 2fr, 2fr),
    stroke: none,
    table.hline(),
    tab-h[Merkmal], tab-h[NTP], tab-h[PTPv2], tab-h[gPTP],
    table.hline(stroke: 0.5pt),
    tab-d[Genauigkeit], tab-d[mikro bis Milliskeundenbereich], tab-d[sub Mikrosekunden], tab-d[sub Mikrosekunden],
    tab-d[Laufzeitmessung], tab-d[E2E], tab-d[E2E/P2P], tab-d[P2P],
    tab-d[Komplexität],
    tab-d[Einfach],
    tab-d[Sehr Komplex],
    tab-d[eingeschränktes Profil und Konfigurationmöglichkeiten],
    tab-d[Transportschicht], tab-d[], tab-d[], tab-d[],
    tab-d[Hardwarebedarf], tab-d[-], tab-d[], tab-d[TSN fähige Hardware nötig],
    tab-d[Einsatzgebiet], tab-d[], tab-d[], tab-d[],
    table.hline(),
  ),
  caption: [Vergleich NTP, PTPv2 und gPTP],
)<comparison-ptp-gptp>

Eigentlich setzt NTP einen standard was die Synchronisierunge der System angeht. Leider is diese nur bis zu einer gewissen Genauigkeit möglich und ist desweiteren so Konzipiert, abweichungen bis in den Milliskeundenbereich zu tollerieren. \
In der industriellen Automatisierung oder im Automobilbereich werden Genauigkeiten bis in den Nanosekundebreich gefordert. Diese Präzision biete PTPv2 auch, nur scheitert es hier bei der Interoperabilität. Da der Standard über 100 Konfigurationsoptionen und Profile offenlässt. gPTP löst dies, indem es eine festes und spezifischer definierteres Profil darstellt. Es erzwingt die P2P-Laufzeitmessung, schreibt feste Nachrichtenraten vor und automatisiert die Netzwerkkonfiguration

=== Rollen und Netzwerktopologie
- gPTP-Domäne: logische Gruppe von Geräten die synchron zueinander laufen.

- Rollen der Geräte:
  - Grandmaster Clock (GM): Die Referenzuhr für die Gesamte Domäne
  - Time-Aware Bridge: Verbindet Netzwerksegemente. Sie synchronisieren sich an einem Port als Slave und fungieren am anderen Port als Master
  - Timer-Aware Endstation: Endpoint welche sich nur Synchronisiert.

- Rollen der Ports:
  - Master Port: Sendet Synchronisations- und pDelay-Nachrichten aus.
  - Slave Port: Empfängt Synchronisationsdaten um die eigene Uhr zu synchronisieren. Sendet ebenfalls pDelay-Nachrichten.
  - Disabled: Nimmt nicht an der Synchronisation teil.


=== Der Synchronisationsmechanismus

*Note*: Hier will ich nur den Mechanismus zwischen zwei Systemen erklären. Damit ich im späteren Kaptiel (gPTP Bridge) erklären kann, wieso eine Bridge benötigt wird. Dort soll z.B der Begriff gPTP Domäne beschrieben werden und die verschiedenen Portstate erklärt werden.



Was wird eigentlich genau Synchronisiert?\
Letztendlich hat jeder Mikrocontroller einen Timer der hochzählt. Diese ist durch eine Hardware Clock angetribene.

In einer gPTP-Domäne gibt es eine Grandmaster Clock geben. Diese ist der Taktgeber für alle Timer-Aware Systeme in der Domäne. Damit sich eine System mit seinem Nachbarn synchronisiert wird der Sync-Mechanismus benötigt.

Der Sync Mechanismus definiert letzendlich wie schnell das hochzählen erfolgen soll. Damit die frequenz mit der Master-Clock übereinstimmt wurde sich folgendes Prinzip überlegt:

#figure(
  image("../assets/Sync/gPTP-sync-mechanism.png", width: 80%),
  caption: [Darstellung des Sync-mechanismus],
) <sync-mechanism>

@sync-mechanism Sieht man 2 verfahren wie die Synchronisierung erfolgen kann. \ Link das two-step verfahren:

Hier wird werden 2 aufeinander Folgenden Nachirchten versendet. 1. die Sync Nachricht. Diese Dient dazu die Zeit zwischen Master und Slave herauszufinden. Dabei wird der egress timestamp t1 und der ingress timestamp t2 aufgenommen. t1 wird anschließend mit zwei weiteren Infromationen, dem correctionField und der rateRatio durch die Follow_UP Nachricht zum Slave gesendet.
Diese berechnen im anschluss wie genau die Lokale Clock zum Master Synchronisiert ist.

Beeim single-step verfahren ist der einzige Unterschied, dass die Sync-Nachircht bereits alle werte enthält die die Follow_UP Nachricht somit nicht benötigt wird. Das Funktioniert dadruch, dass der Timestamp t1 beim verlassen der Nachricht in das Ethernet-Frame geschrieben wird.

Eventuell noch hier erklären wieso man P2P anstelle von E2E verwedent.

=== Messung der Leitungsverzögerung
Ein weiterer wichtiger Mechanismus ist das berechenen des `propagation Delays`. In kurz wird hier berechnet, wie lange sich ein Paket auf der physischen Leitung befindent. Der Mechanimus funktioniert dabei wiefolgt.

#figure(
  image("../assets/Sync/gPTP-pDelay-mechanism.png", width: 80%),
  caption: [Darstellung des pDelay-Mechanismus],
) <pDelay-mechanism>

Ingsesamt werden 3 arten von Nachirchten versendent. Der initiator sendet zuerst ein `pDelay_Req`. Dabei wird beim egress der Nachricht der Zeitstemepl `t1` und beim ingress der Zeitstempel `t2` aufgenommen. Dadruchr lässt sich die Zeit herausfinden, die das Paket in eine Richtung benötigt. Anschließend Sendet der Empfänger das Pakter `pDelaty_Resp` zurück. Auch hier werden wieder beim egress (`t3`) und ingress (`t4`) Zeitstemepl aufgenommen. Die Letzte Nachricht `pDelay_Resp_Follow_Up` wird zuletzt gesendetn um den aufgenommen Zeitstemepl `t3` zu übermitteln.

Da der Initiator nun alle Zeitstempel hat, kann dieser nun die Berechnung durchführen.

Die Formel sieht wiefolgt aus:

$t_("ir") = t_2 - t_1\
t_("ri") = t_4 - t_3\
D = (t_("ir") + t_("ri"))/2 = ((t_4 - t_1) - (t_3 - t_2))/2$

Das Ergbnis unter D steht dabei für den Durchschnittlichen `propagation Delay`

Der primäre Nutzen der Rechnung ist für die Berechnung des

=== gPTP Bridge
*Note*: Hier soll dem Leser näher gebracht werden was eine Bridge wirklich macht. Sie dient nicht dem Stumpfen weiterleiten von Nachrichten. Die Bridge nimmt aktive am Protokoll teil und terminiert die Synchronisation auf einer Seite als Slave-Port, agiert allerdings auf dem anderen Port als Master um nachfolgende Systeme zu synchronisieren.

Aufgaben die erläutert werden müssen:
- Empfangen der Sync Nachricht auf dem Slave-Port
- Messen der residenceTimer auf dem System
- Senden der neuen Sync-Nachricht auf allen Master-Ports
- Aktuallisieren des correctionFields und der rateRatio in der Follow_UP-Nachricht



== Hardware Grundlagen
=== PHY vs. MAC Timestamping
Wieso spielt das eine große Rolle?
-> Wichtig für den pDelay. Es wird ein Hardware Timestamp aufgenommen, sobald the PHY das erste Bit einer Ethernet Messages einließt. \
Bei PHY Timestamping ist das am genausten, da der PHY den timestamp on the fly in den frame schreibt. \
Bei MAC Timestamping bekommt der MAC von dem PHY ein Signal, dass ein Frame eingelesen wurde und nimmt darauf den Timestamp auf. Nachteil ist, dass es zu einer Leichten verzögerung kommt.

Erklären, wieso sich hier gegen PHY Timestamping entschieden wurde.
PHY Timestamping ist eigentlich der Goldenestandard, da man hier die genauste Zeit erhält. Allerdings ist MAC-Timestamping wesentlich einfacher zu verwenden.

Auserdem erklären was der unterschied zwischen MAC und PHY is Layern 1 und Layer 2
wichtig ist hier auch, dass man bei PHY keine kompensation für die Layerlatenz benötigt, was zu abweichungen in der pDelay-Berechnung fürhren kann
Desweiteren RMII erklären, das sich MAC Timestamping hierauf stützt. Die Taktung dieser Schnittstelle ist auch nicht ganz unwichtig, da bei 50MHz trotzdem eine physikalische Latenz zwischen PHY und MAC ensteht die berücksichtigt werden muss.

=== Schnitesellen und Latenzen


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

- Die *Timestamping-Schnittstelle* bildet die softwareseitige Abstraktion für die im Kapitel `Hardware Grundlagen` erläuterten MAC-Timestamping-Fähigkeiten. Sie ist das entscheidende Bindeglied, das es der Protokoll-Implementierung ermöglicht, auf die für die gPTP-Algorithmen nötigen Zeitstempel (`t1` bis `t4`) präzise zuzugreifen.
- Ergänzt wird dies durch *PTP-Clock-Treiber*, über welche die Hardware-Timer, die als Referenz für die lokale Zeit dienen, dem System zur Verfügung gestellt und von der gPTP-Logik synchronisiert werden können. Diese Treiber kapseln die spezifischen Registerzugriffe der Hardware.

Der *Datenfluss* im Stack lässt sich am besten anhand des Weges eines Pakets nachvollziehen, wobei die oben genannten Komponenten zum Einsatz kommen. Der *Ingress-Pfad* (Empfang) beginnt, wenn ein Ethernet-Frame von der Hardware empfangen wird. Wie im Kapitel `Hardware Grundlagen` beschrieben, kann hier durch den MAC-Controller ein Hardware-Zeitstempel erfasst werden. Der Zephyr-*Ethernet-Treiber* nimmt diesen Frame samt Zeitstempel-Metadaten entgegen, verpackt ihn in einen `net_buf` und reiht ihn in eine zentrale Verarbeitungswarteschlange ein. An dieser Stelle im Software-Stack sind nun alle Informationen verfügbar, welche die gPTP-Protokolllogik zur Berechnung des `ingress timestamps (t2)` benötigt.

Beim *Egress-Pfad* (Senden) erstellt die Applikationslogik einen `net_buf`, der die zu sendende Nachricht enthält. Dieser wird über die Layer-2-API an den Treiber übergeben. Nachdem der Treiber das Paket physisch versendet und der MAC den exakten Sendezeitpunkt als `egress timestamp (t1)` erfasst hat, wird diese Zeitinformation über einen Callback-Mechanismus (`tx_tstamp`) der Timestamping-Schnittstelle an die Applikation zurückgemeldet. Dieser Mechanismus ist die softwareseitige Realisierung der Anforderung aus dem gPTP-Standard, den exakten Sendezeitpunkt für die Erstellung der `Follow_Up`-Nachricht zu kennen.

TODO: Stack als modulare, schichtbasierte architektur darstellen






