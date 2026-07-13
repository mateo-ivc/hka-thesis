#import "../meta.typ": note, fig-platzhalter-mittel, tab-h, tab-d, acr-emph, acrpl-emph
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

- Abgrenzung zwischen NTP und PTPv2. Was sind die unterschiede und wieso wurde gPTP entwicklet?

NTP-> ist zu ungenau, gPTP zielt auf eine Genauigkeit im sub Mikrosekunden bereich während NTP im Milliskeundenbereich genau ist.

PTPv2 dient wie aug gPTP der Synchronisierung zwischen Timer-Aware System, ist allerdings durch unzählige Optionen, Profilen und Freiheitsgraden ein sehr mächtiges aber auch hochkomplexs Protokoll. Dies führt oft zu Inkompatibilität zwischen Geräten verschiedener Hersteller. 

gPTP ist ein spezifisches TSN-Profil von PTPv2, was die Optionen von PTPv2 massiv einschränkt, um eine Interoperabilität und Plug-and-Play zu garantieren. 



=== Der Synchronisationsmachanismus\

*Note*: Hier will ich nur den Mechanismus zwischen zwei Systemen erklären. Damit ich im späteren Kaptiel (gPTP Bridge) erklären kann, wieso eine Bridge benötigt wird. Dort soll z.B der Begriff gPTP Domäne beschrieben werden und die verschiedenen Portstate erklärt werden.



Was wird eigentlich genau Synchronisiert?\
Letztendlich hat jeder Mikrocontroller einen Timer der hochzählt. Diese ist durch eine Hardware Clock angetribene. 

In einer gPTP-Domäne gibt es eine Grandmaster Clock geben. Diese ist der Taktgeber für alle Timer-Aware Systeme in der Domäne. Damit sich eine System mit seinem Nachbarn synchronisiert wird der Sync-Mechanismus benötigt.

Der Sync Mechanismus definiert letzendlich wie schnell das hochzählen erfolgen soll. Damit die frequenz mit der Master-Clock übereinstimmt wurde sich folgendes Prinzip überlegt:

#figure(
  image("../assets/Sync/gPTP-sync-mechanism.png", width: 80%),
  caption: [Darstellung des Sync-mechanismus]
) <sync-mechanism>

@sync-mechanism Sieht man 2 verfahren wie die Synchronisierung erfolgen kann. \ Link das two-step verfahren:

Hier wird werden 2 aufeinander Folgenden Nachirchten versendet. 1. die Sync Nachricht. Diese Dient dazu die Zeit zwischen Master und Slave herauszufinden. Dabei wird der egress timestamp t1 und der ingress timestamp t2 aufgenommen. t1 wird anschließend mit zwei weiteren Infromationen, dem correctionField und der rateRatio durch die Follow_UP Nachricht zum Slave gesendet.
Diese berechnen im anschluss wie genau die Lokale Clock zum Master Synchronisiert ist. 

Beeim single-step verfahren ist der einzige Unterschied, dass die Sync-Nachircht bereits alle werte enthält die die Follow_UP Nachricht somit nicht benötigt wird. Das Funktioniert dadruch, dass der Timestamp t1 beim verlassen der Nachricht in das Ethernet-Frame geschrieben wird.

Eventuell noch hier erklären wieso man P2P anstelle von E2E verwedent. 

=== Messung der Leitungsverzögerung
Basically pDelay hier erklären und wie es sich auf die Synchornisierung auswirkt.

=== gPTP Bridge
*Note*: Hier soll dem Leser näher gebracht werden was eine Bridge wirklich macht. Sie dient nicht dem Stumpfen weiterleiten von Nachrichten. Die Bridge nimmt aktive am Protokoll teil und terminiert die Synchronisation auf einer Seite als Slave-Port, agiert allerdings auf dem anderen Port als Master um nachfolgende Systeme zu synchronisieren.  

Aufgaben die erläutert werden müssen:
- Empfangen der Sync Nachricht auf dem Slave-Port
- Messen der residenceTimer auf dem System
- Senden der neuen Sync-Nachricht auf allen Master-Ports
- Aktuallisieren des correctionFields und der rateRatio in der Follow_UP-Nachricht 



== Hardware Grundlagen
===  PHY vs. MAC Timestamping
Wieso spielt das eine große Rolle?
-> Wichtig für den pDelay. Es wird ein Hardware Timestamp aufgenommen, sobald the PHY das erste Bit einer Ethernet Messages einließt. \
Bei PHY Timestamping ist das am genausten, da der PHY den timestamp on the fly in den frame schreibt. \
Bei MAC Timestamping bekommt der MAC von dem PHY ein Signal, dass ein Frame eingelesen wurde und nimmt darauf den Timestamp auf. Nachteil ist, dass es zu einer Leichten verzögerung kommt.

Erklären, wieso sich hier gegen PHY Timestamping entschieden wurde.
PHY Timestamping ist eigentlich der Goldenestandard, da man hier die genauste Zeit erhält. Allerdings ist MAC-Timestamping wesentlich einfacher zu verwenden.

Auserdem erklären was der unterschied zwischen MAC und PHY is Layern 1 und Layer 2
wichtig ist hier auch, dass man bei PHY keine kompensation für die Layerlatenz benötigt, was zu abweichungen in der pDelay-Berechnung fürhren kann
Desweiteren RMII erklären, das sich MAC Timestamping hierauf stützt. Die Taktung dieser Schnittstelle ist auch nicht ganz unwichtig, da bei 50MHz trotzdem eine physikalische Latenz zwischen PHY und MAC ensteht die berücksichtigt werden muss.



== Das Echtzeitbetriebssystem ZephyrRTOS
Erklärung was ein Echtzeitbetribssystem ist.\
Ein Betriebssystem, das speziell dafür entwickelt wurde, Aufgaben innerhalb eines fest definierten Zeitrahmens auszuführen.

Im Gegensatz zu normalen Betriebssystemen, die auf maximalen Durchsatz optimiert sind, kommt es beim RTOS auf Determinismus an. Das bedeutet: Das Zeitverhalten muss absolut vorhersagbar sein.

Kern dabei ist der Scheduler, welcher die CPU-Zuweisung (welche Task drann ist) im hintergrund steuert. Dieser sorgt dafür, dass kritische Prozesse priorisiert werden und so ihre Fristen einhalten können.\

Was macht ZephyrRTOS so besonders?\
Das „Linux der Mikrocontroller“: Zephyr ist weit mehr als nur ein Kernel. Es ist ein vollständiges, modulares Ökosystem, das von der Linux Foundation verwaltet wird und Open-Source-Standards in die Embedded-Welt bringt.

klassiche RTOS wie FreeRTOS bieten meist nur einen einfachen Kerne/Scheduler an. 
Treiber, Softwarestacks und vieles weitere müssen daher mühsam selst integriert werden. 
Zephyr bringt hierbei ein All-in-one Ökosystem mit.

Desweiteren biete Zephyr beihilfe inform von Device Trees und Overlays.
Das Konzept der Device Trees gibt es schon lange und wird in Linux verwedent. Zephyr hat dieses adaptiert, um so die Hardware und dessen Konfiguration komplett von eigentlich C-Code (Applikation Code) zu trennen. Dies sorgt für maximale Portierbarkeit, da der Applikationscode nur die Zephyr-API anspricht. 

Wie funktioniert das? Interne Macros, welche die definition in der Zephyr-API automatische auf die richtige HAL legen.

=== Zephyrs Netzwerkstack
Der Stack arbeitet nach dem "Producer-Consumer"-Prinzip, bei dem Daten über verschiedene Schichten (von der Applikation nach unten oder vom Ethernet nach oben) gereicht werden. 

*Netzwerk-Puffer*:
Kümmert sich um das Puffer-Managment. Pakete werden nicht kopiert, sondern durch Zeiger (Handler) durch den Stack gereicht, was den Overhead minimiert.

*Netzwerk-Interface*:
Eine Abstrakte Schnittstelle zur Hardware

*Netzwerk-Layer*:
Trennung in Layer 2 (MAC), Layer 3(IP) und Layer 4

Volgende Tasks werden dabei erstellt:

*ENET_RX*: 
Kümmert sich um den eigehenden Datenverkehr. Wird durch Interrupts der Netzwerkkarte getriggerd und gibt sie für die weiterverarbeitung weiter.

*rx_q*:
nimmt die von ENET_RX empfangenen roh Dataen an und leitet sie an den Netzwerkstacl weiter.

*tx_q*:
Zuständig für das Senden von Paketen. Verarbeitet die Warteschlange der Packete, die aus der Anwendung kommen.

*tx_tstamp*
Callback thread der nach dem senden eines Packets aufgerufen wird, um zusätzlich den generierten timestamp aus der Hardware zu erhalten. 
Benötigt wird dies zum Beispiel beim senden einer pDelay request. Sobald das Packet gesendet wird und der Timestamp generiert wurde, wird der callback aufgerufen um den Timestamp zurück in die Applikation Logik zu bringen. 

*gptp*

Implementierung des gPTP Protokolls das die gesamte Logik enthält und in einem eigenen Task läuft.

*net_mgmt*
Fungiert als zentraler Ereignis-Dispatcher. Er überwacht den Netzwerkstack auf Statusänderungen (z.B. Interface-Status, IP-Konfiguration, Verbindungsereignisse), filtert diese und verteilt sie asynchron an alle registrierten Event-Handler im System.“
