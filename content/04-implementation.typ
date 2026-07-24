#import "../meta.typ": acr-emph, asm-listing, c-listing, fig-platzhalter-mittel, note
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Implementierung

Im folgenden Kapitel werden die Anpassungen vorgestellt, damit das gPTP-Protokoll zuverlässig funktioniert. Dazu wird zunächst auf die Board-spezifischen Änderungen eingegangen, anschließend auf die Anpassungen im gPTP-Subsystem selbst. Abschließend wird die interne Synchronisierung der beiden Bridge-Ports beschrieben.

== Anpassungen in Zephyr
Zephyrs gPTP-Implementierung ist grundsätzlich für Endgeräte mit einer einzigen Ethernet-Schnittstelle ausgelegt und soll dort einwandfrei funktionieren, ohne dass Anwender Anpassungen vornehmen müssen. Der in dieser Arbeit verwendete Testaufbau erfordert jedoch eine Bridge mit zwei unabhängigen ENET-Instanzen - eine Konfiguration, die der Stack zwar implementiert, allerdings nie auf ihre Funktionalität validiert hat. Zudem sind im Laufe der Arbeit Fehler aufgetaucht, welche Anpassungen an Board-spezifischen Treiber als auch an dem gPTP-Subsystem selbst erfordern. Die folgenden beiden Unterkapitel beschreiben diese Änderungen.

=== Board Spezifische Änderungen
//todo: Überschriften umbennenen
*PTP-Clock Konfiguration*\
Die Initialisierung der PTP-Clock wurde angepasst. Der ursprüngliche Zephyr-Code konfiguriert nur einen Clock für eine einzelne ENET-Instanz. Für die Bridge wurde allerdings ein zweite, identische konfigurierte Clock für die zweite ENET-Instanz ergänzt. Die Konfiguration einer zweiten Clock ist zwingend notwendig, da eine Instanz physisch nicht mit der Clock der anderen Instanz verbunden werden kann. Beide Clocks werden aus `SYS_PLL1_DIV2` (geteilt durch 20) abgeleitet, was einer Clockfrequenz von $25"MHz"$ entspricht, und erfüllt somit die in Abschnitt 3.4 geforderte Mindestauflösung.

//hier noch schreiben wieso für beide timer nicht ein CLK_ROOT verwendet werden kann: Grund ist das die Hardware verschaltung es nicht zulässt. Siehe S.1426 im Handbuch.

#figure(
  c-listing(
    "1\n2\n3\n4\n5\n6\n7\n",
    "rootCfg.mux = kCLOCK_ENET_TIMER1_ClockRoot_MuxSysPll1Div2;\nrootCfg.div = 20;\nCLOCK_SetRootClock(kCLOCK_Root_Enet_Timer1, &rootCfg);\n\nrootCfg.mux = kCLOCK_ENET_TIMER2_ClockRoot_MuxSysPll1Div2;\nrootCfg.div = 20;\nCLOCK_SetRootClock(kCLOCK_Root_Enet_Timer2, &rootCfg);",
    width: 90%,
  ),
  caption: [PTP-Clock Konfiguration],
) <lst:PTP-Clock_config>


*clock_control/clock_control_mcux_ccm_rev2.c:*
Die Funktion, über die Zephyr die Taktrate eine Peripherie abfragt (`mcux_ccm_get_subsys_rate()`), gab für beide ENET-Instanzen bisher die Taktrate einer Instanz zurück. Da nun aber zwei unabhängig Taktgeber für die PTP-Timer existieren wurde eine instanzabhängige Zuordnung ergänzt, sodass jede ENET-Instanz die Taktrate ihres eigenen PTP-Timers zurückerhält.

*ptp_clock/ptp_clock_nxp_enet.c:* Die capture und compare funktion der timer wurde richtig gesetzt. Zudem wurde in den Callback die Funktion hinzugefügt, timestamp an einen Task zusenden, wenn ein bei einem Timer das Capture/Compare Event ausgelöst hat.
Benötigt ist dies, um anschließend beide Timer zu Synchronisieren.

Der PTP-Timer der Gigabit-Instanz (`enet1g`) wurde so konfiguriert, dass er bei einem Compare-Event einen Puls über einenen GPIO-Pin ausgibt. Der PTP-Timer der 10/100-Mbit-Instanz (`enet`) wurde so konfiguriert, dass er diesen Puls per Capture-Event einliest. In der 4.3 beschriebenen Synchronisierung übernimmt `enet1g` damit die Rolle der Slave-Instanz (Refernz) und `enet` die Rolle der Master-Instanz (wird korrigiert). Zusätzlich wurde die Interrupt-Service-Routine erweitert:\
Löst eines der beiden Events aus, wird der zugehörige Zeitstempel über eine Message-Queue an einen Task übergeben - Vorraussetzung dafür, dass beide Timer in Anschluss synchronisiert werden können.

Für das STM32H7-Board wurde entsprechend eine Funktion ergänzt, die bei einem Capture-Event ebenfalls den aktuellen Zeitstempel an einen Task übergibt.

=== Änderungen im gPTP-Subsystem
*gptp_messages.c*

Beim senden einer Nachricht z.B. der Sync Nachricht werden die TX-Zeitstempel wieder im gPTP-Subsystem benötigt. Der Zeitstempel selbst wird allerdings erst im MAC aufgenommen. Hier stellt sich das Problem, wie man diesen vom unteren Layer in den oberen bekommt. Zephyr löst dies geschickt über Callbacks. Jede Nachricht die versendet wird, bekommt einen Callback angeängt, welcher ausgeführt wird wenn der Zeitstempel aufgenommen wurde. Problematisch bei der Implementierung war, dass der Edge-Case wenn der Callback für den Zeitstempel nicht ausgeführt wurde - etwa weil die Queue schon voll ist und dadurch das Paket verloren wurde - oder ein `gptp_send_sync()` erneut aufgerufen wurde, bevor der vorherige Callback abgeschlossen war. Dadurch konnte für die nächste Sync-Nachricht keine neuen Callbacks mehr registriert werden, und es kamen keine neuen TX-Zeitstempel mehr an.

#figure(
  c-listing(
    "1\n2\n3\n4\n5\n6\n7\n8\n9\n10\n11\n12\n13\n14\n15\n16",
    "void gptp_send_sync(int port, struct net_pkt *pkt) {\n    if (sync_cb_registered[port - 1] &&\n        sync_timestamp_cb[port - 1].pkt != pkt) {\n        /* stale callback: unregister before re-registering */\n        LOG_WRN(\"Stale TX timestamp cb on port %d\", port);\n        net_if_unregister_timestamp_cb(&sync_timestamp_cb[port - 1]);\n        sync_cb_registered[port - 1] = false;\n    }\n\n    if (!sync_cb_registered[port - 1]) {\n        net_if_register_timestamp_cb(&sync_timestamp_cb[port - 1],\n            pkt, net_pkt_iface(pkt), gptp_sync_timestamp_callback);\n        sync_cb_registered[port - 1] = true;\n    }\n    ...\n}",
    width: 90%,
  ),
  caption: [Bugfix in gptp_send_sync],
) <lst:PTP-Clock_config>

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

Der Task berechnet aus den beiden Zeitstempeln einen einfachen Phasenfehler zwischen Master- und Slave-Instanz. Überschreitet dieser Phasenfehler 500 ms, wird die Clock der Master-Instanz hart auf die von der Slave-Instanz bekannte Zeit gesetzt, anstatt sie über den PI-Regler langsam anzunähern. Das verkürzt die Einschwingzeit erheblich, da die zu korrigierende Uhr in einem Schritt in die Nähe der Zielzeit gebracht wird - ein Vorteil vor allem dann, wenn ein Gerät neu in ein bereits laufendes System integriert wird und der anfängliche Offset dementsprechend groß ist. \
Liegt der Phasenfehler innerhalb der Schwelle, wird stattdessen die Zählrate des Timers der Master-Instanz über einen PI-Regler angepasst:
Aus dem Phasenfehler berechnet der Regler eine Korrektur in ppb (parts per billion), mit der sich die Zählrate der Master-Instanz schrittweise an die der Slave-Instanz annähert.

/* todo: mehr inhalt mitrein bringen:



aktuell ist noch ein fester korrektur wert von 120ns drin. -> Durch messungen konnte ein 120ns offset erkannt werden.

*/
#figure(
  c-listing(
    "1\n2\n3\n4\n5\n6\n7\n8\n9\n10",
    "double better_servo_pi(int64_t nanosecond_diff) {\n    double better_integral = 0.0;\n\n    double better_servo_pi(int64_t nanosecond_diff) {\n    const double Kp = 0.9;\n    const double Ki = 0.1;\n    better_integral += (double)nanosecond_diff;\n\n    return (Kp * (double)nanosecond_diff) + (Ki * better_integral);\n}",
    width: 90%,
  ),
  caption: [PI-Regler für die interne Timer Synchronisierung],
) <lst:PI-impl>

