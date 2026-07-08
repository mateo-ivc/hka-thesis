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

gPTP ist ein spezifisches TSN-Profil von PTPv2, was die Optionen von PTPv2 massiv einschränkt, um eine Interoperabilität und Plug-and-Plat zu garantieren. 



=== Der Synchronisationsmachanismus
Was wird eigentlich genau Synchronisiert?\
Letztendlich hat jeder Mikrocontroller einen Timer der hochzählt. Diese ist durch eine Hardware Clock angetribene. 
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

=== Hardware-Timestamping (MAC vs PHY)
Wieso spielt das eine große Rolle?
-> Wichtig für den pDelay. Es wird ein Hardware Timestamp aufgenommen, sobald the PHY das erste Bit einer Ethernet Messages einließt. \
Bei PHY Timestamping ist das am genausten, da der PHY den timestamp on the fly in den frame schreibt. \
Bei MAC Timestamping bekommt der MAC von dem PHY ein Signal, dass ein Frame eingelesen wurde und nimmt darauf den Timestamp auf. Nachteil ist, dass es zu einer Leichten verzögerung kommt.

Vielleicht erklären, wieso sich hier gegen PHY Timestamping entschieden wurde.

Auserdem erklären was der unterschied zwischen MAC und PHY is Layern 1 und Layer 2

Desweiteren RMII erklären, das sich MAC Timestamping hierauf stützt. Die Taktung dieser Schnittstelle ist auch nicht ganz unwichtig, da bei 50MHz trotzdem eine physikalische Latenz zwischen PHY und MAC ensteht die berücksichtigt werden muss.

== Funktionsweise einer gPTP Bridge
Was macht eine bridge aus?\
Prinzipell dient sie der Synchronisierung anderer Timer-Aware Systeme. Da Ethernet nur eine Point to point connection erlaubt muss das zuvor Synchronisierte Gerät auf dem nächsten Port als Master fungieren und so das Nachfolgende System Synchronisieren.

Zu beachten ist hier die residence Timer. Also die Zeit zwischen Angkommen des Sync Nachricht auf Port A und dem aussenden der Sync Nachricht auf Port B.

wieso ist diese so wichtig ?
Sonst kommt es zu einem Offset und man Synchronisiert sich nicht richtig \


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
Da es sich hier um ein Netzwerkprotokoll handlet ist es wichtig einam Zephyrs aufbau des Netzwerkstacks zu verstehen.