#import "../meta.typ": acr-emph, asm-listing, c-listing, fig-platzhalter-mittel, note
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Implementierung

Im folgenden Kapitel werden die Anpassungen vorgestellt, damit das gPTP-Protokoll zuverlässig funktioniert. Dazu wird zunächst auf die Board-spezifischen Änderungen eingegangen, anschließend auf die Anpassungen im gPTP-Subsystem selbst. Abschließend wird die interne Synchronisierung der beiden Bridge-Ports beschrieben.

== Anpassungen in Zephyr
Zephyrs gPTP-Implementierung ist grundsätzlich für Endgeräte mit einer einzigen Ethernet-Schnittstelle ausgelegt und soll dort einwandfrei funktioniere, ohne dass Anwender Anspassungen vornehmen müssen. Der in dieser Arbeit verwendete Testaufbau erfordert jedoch eine Bridge mit zwei unabhängigen ENET-Instanzen - eine Konfiguration, die der Stack zwar implementiert, allerdings nie auf ihre Funktionalität validiert hat. Zudem sind im Laufe der Arbeit Fehler aufgetaucht, welche Anpassungen an Board-spezifischen Treiber als auch an dem gPTP-Subsystem selbst erfordern. Die folgenden beiden Unterkaptiel beschreiben diese Änderungen.

=== Board Spezifische Änderungen
//todo: Überschriften umbennenen
*imxrt11xx/soc.c:*\
Die Initialisierung der PTP-Timer-Taktgeber wurde angepasst. Der unrsprüngliche Zephyr-Code konfiguriert nur einen Taktgeber für eine einzelne ENET-Instanz. Für die Bridge wurde allerdings ein zweiter, identische konfigurierter Taktgeber für die zweite ENET-Instanz ergänzt. Beide Taktgeber werden aus `SYS_PLL1_DIV2` (geteilt durch 20) abgeleitet, was einer PTP-Timer-Frequenz von $25"MHz"$ entspricht, und erfüllt somit die in Abschnitt 3.4 geforderte Mindestauflösung.

//hier noch schreiben wieso für beide timer nicht ein CLK_ROOT verwendet werden kann: Grund ist das die Hardware verschaltung es nicht zulässt. Siehe S.1426 im Handbuch.

*clock_control/clock_control_mcux_ccm_rev2.c:*
Die Funktion, über die Zephyr die Taktrate eine Peripherie abfragt (`mcux_ccm_get_subsys_rate()`), gab für beide ENET-Instanzen bisher die Taktrate einer Instanz zurück. Da nun aber zwei unabhängig Taktgeber für die PTP-Timer existieren wurde eine instanzabhängige Zuordnung ergänzt, sodass jede ENET-Instanz die Taktrate ihres eigenen PTP-Timers zurückerhält.

*ptp_clock/ptp_clock_nxp_enet.c:* Die capture und compare funktion der timer wurde richtig gesetzt. Zudem wurde in den Callback die Funktion hinzugefügt, timestamp an einen Task zusenden, wenn ein bei einem Timer das Capture/Compare Event ausgelöst hat.
Benötigt ist dies, um anschließend beide Timer zu Synchronisieren.

Der PTP-Timer der Gigabit-Instanz (`enet1g`) wurde so konfiguriert, dass er bei einem Compare-Event einen Pulse über einenen GPIO-Pin ausgibt. Der PTP-Timer der 10/100-Mbit-Instanz (`enet`) wurde so konfiguriert, dass er diesen Puls per Capture-Event einliest. In der 4.3 beschriebenen Synchronisierung übernimmt `enet1g` damit die Rolle der Slave-Instanz (Refernz) und `enet` die Rolle der Master-Instanz (wird korrigiert). Zusätzlich wurde die Interrupt-Service-Routine erweitert:\
Löst eines der beiden Events aus, wird der zugehörige Zeitstempel über eine Message-Queue an einen Task übergeben - Vorraussetzung dafür, dass beide Timer in Anschluss synchronisiert werden können.

Für das STM32H7-Board wurde entsprechend eine Funktion ergänzt, die bei einem Capture-Event ebenfalls den aktuellen Zeitstempel an einen Task übergibt.

=== Änderungen im gPTP-Subsystem
*gptp_message.c*

Beim senden einer Nachricht z.B. der Sync Nachricht werden die TX-Zeitstempel wieder im gPTP-Subsystem benötigt. Der Zeitstempel selbst wird allerdings erst im MAC aufgenommen. Hier stellt sich das Problem, wie man diesen vom unteren Layer in den oberen bekommt. Zephyr löst dies geschickt über Callbacks. Jede Nachricht die versendet wird, bekommt einen Callback angeängt, welcher ausgeführt wird wenn der Zeitstempel aufgenommen wurde. Problematisch bei der Implementierung war, dass der Edge-Case wenn der Callback für den Zeitstempel nicht ausgeführt wurde - etwa weil die Queue schon voll ist und dadurch das Paket verloren wurde - oder ein `gptp_send_sync()` erneut aufgerufen wurde, bevor der vorherige Callback abgeschlossen war. Dadurch konnte für die nächste Sync-Nachricht keine neuen Callbacks mehr regestiert werden, und es kamen keine neuen TX-Zeitstempel mehr an.


*gptp_md.c:* Sync-send state machine getting Stuck.
In der Implementierung der SyncSend Statemachine wird überprüft, ob das zuvor gesendete Sync-Nachricht schon eine TX-Zeitstempel generiert hat. Ist dieser im System, kann die Follow_UP-Nachricht versendet werden. Fehlt dieser Zeitstempel z.B. wegen dem zuvor angesprochenem Bug oder kommt aus einem anderen Grund nicht an. Bleibt man in dieser Statemachine dauerhaft im `GPTP_SYNC_SEND_SEND_FUP` Zustand stehen. Dadurch wird ebefalls die Synchronisierung ausgesetzt.
Die Lösung hierfür ist ein Timeout-Mechanismus, der nach einer gewissen Zeit, den State auf `GPTP_SYNC_SEND_SEND_SYNC` zurücksetzt um so eine neue Sync-Nachricht zu versenden.

*gptp_md.c:* Conversion bug - rate rateRatio

Die wichtigste Aufgabe die eine Bridge hat, ist einen richtigen `correctionField` zu übermitteln.
Während das versenden korrekt Implementiert wurde hat sich ein kleiner Bug in dessen Berechnung eingeschlichen.\
Im Standard ist das `correctionField` vom Typ int64, das es einen positiven als auch negativen wert annehmen kann. Da Daten zwischen Netz- und Host-System sich in ihrer Endianness untescheiden können, ist hier eine Konvertierung zwischen Big- und Little-Endian unbedingt nötigt. Zephyr Implementiert diese auch, allerdings gibt die `net_htonll()` Funktion die für die Konvertierung verwendet wird `uint64` Wert zurück. Das führte dazu, dass bei einem eingtlich Negativen  `correctionField` die Konvertierung von int64 -> uint64 -> double in eine hohe positive Zahl resultiert. Dadurch sind alle anschließenden Berechnung fehlerhaft und die Clock wird nicht Synchronisiert.


== Implementierung der Bridge Synchronisation

Das im Folgenden beschriebene Verfahren ist keine im Standard 802.1AS vorgesehene Funktion, sondern eine Board-spezifische Ergänzung, um das in Abschnitt 3.4 beschriebene Problem zu lösen: Da jede ENET-Instanz einen eigenen, unabhängigen PTP-Timer besitzt, gPTP aber nur den Timer des jeweils synchronisierten Ports korrigiert, würde der zweite (Master-)Port der Bridge sonst dauerhaft unsynchronisiert bleiben. Zur Lösung wurde ein eigener Task angelegt, der die beiden Timer der Bridge gegeneinander synchronisiert.

In Kapitel 4.1.1 wurde bereits beschrieben, wie die Timer-Instanzen Konfiguriert sind. Der Timer der `enet1g` Instanz vergleicht dabei fortlaufend seinen aktuellen Zählerstand mit dem Wert, den man im `ENET_TCCRn` definiert.

Beide Events lösen jeweils einen Interrupt aus, in dessen Interrupt-Service-Routine (ISR) der aktuelle Zählerstand des jeweiligen Timers ausgelesen wird – zu diesem frühestmöglichen Zeitpunkt ist der erfasste Zeitstempel am genauesten. Um die ISR so kurz wie möglich zu halten und damit Jitter gering sowie das Zeitverhalten deterministisch zu halten, findet die eigentliche Verarbeitung nicht in der ISR selbst statt: Der Zeitstempel wird lediglich über eine Message-Queue an den Synchronisierungs-Task übergeben.

Dieser Task übernimmt die eigentliche Regelung: Er sorgt dafür, dass sich die Master-Instanz an die Slave-Instanz synchronisiert.

Da beiden Events jeweils ein Interrupt werfen, wird zu genau diesem Zeitpunkt die aktuelle Zeit des Timers entnommen.
Die Timestamps werden in der ISR erfasst, da Sie hier am genausten sind. Das wird dadruch gewährleistet, da hier  Anschließend werden sie über eine Queue an die Synchronisierungs Task übergeben. Der Vorteil dabei ist, dass man die ISR so kurz wie möglich hält und somit den jitter so gering wie möglich und das deterministische verhalten so hoch wie möglich hält.

Der Task kümmert sich anschließend darum, dass die Master Instanz sich an die Slave Instanz Synchronisiert.

Der Mechanismus selbst berechnet aus den 2 Timestamps einen einfachen Phaseerror. Sollte dieser fehler größer als 500ms sein, wird die Clock hart auf die Zeit des Masters gesetzt. Dies Optimiert die Synchronisationzeit, da die zu Synchrnisierende Clock hier direkt näher an die Ziel Zeit gebracht wird. Vorallem wenn ein Grät in frisch in ein bereits bestehendes System integriert wird, kommt dies von großem Vorteil.

Im anderen Fall wird mittels dem Phaseerror und einem PI-Regler die ratio mit dem der Timer zählt angepasst. Durch den PI-Regler zählt der eigne Timer mit eine frequenz, die sich langsam aber sicher der Frequenz mit dem der Master zählt annähert.

/* todo: mehr inhalt mitrein bringen:



aktuell ist noch ein fester korrektur wert von 120ns drin. -> Durch messungen konnte ein 120ns offset erkannt werden.

*/
#figure(
  c-listing(
    "1\n2\n3",
    "int add(int a, int b) {\n  return a + b;\n}",
  ),
  caption: [Beispielhaftes C-Listing],
) <lst:c-beispiel>

