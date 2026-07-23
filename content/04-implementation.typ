#import "../meta.typ": acr-emph, asm-listing, c-listing, fig-platzhalter-mittel, note
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Implementierung

Im folgenden Kapitel werden die Anpassungen vorgestellt, damit das gPTP-Protokoll zuverlässig funktioniert. Dazu wird zunächst auf die Board-spezifischen Änderungen eingegangen, anschließend auf die Anpassungen im gPTP-Subsystem selbst. Abschließend wird die interne Synchronisierung der beiden Bridge-Ports beschrieben.

== Anpassungen in Zephyr
Zephyrs gPTP-Implementierung ist grundsätzlich für Endgeräte mit einer einzigen Ethernet-Schnittstelle ausgelegt und soll dort einwandfrei funktioniere, ohne dass Anwender Anspassungen vornehmen müssen. Der in dieser Arbeit verwendete Testaufbau erfordert jedoch eine Bridge mit zwei unabhängigen ENET-Instanzen - eine Konfiguration, die der Stack zwar implementiert, allerdings nie auf ihre Funktionalität validiert hat. Zudem sind im Laufe der Arbeit Fehler aufgetaucht, welche Anpassungen an board-spezifischen Treiber als auch an dem gPTP-Subsystem selbst erfordern. Die folgenden beiden Unterkaptiel beschreiben diese Änderungen.

=== Board Spezifische Änderungen
//todo: Überschriften umbennenen
*imxrt11xx/soc.c:*\
Die Initialisierung der PTP-Timer-Taktgeber wurde angepasst. Der unrsprüngliche Zephyr-Code konfiguriert nur einen Taktgeber für eine einzelne ENET-Instanz. Für die Bridge wurde allerdings ein zweiter, identische konfigurierter Taktgeber für die zweite ENET-Instanz ergänzt. Beide Taktgeber werden aus `SYS_PLL1_DIV2` (geteilt durch 20) abgeleitet, was einer PTP-Timer-Frequenz von $25"MHz"$ entspricht, und erfüllt somit die in Abschnitt 3.4 geforderte Mindestauflösung.

//hier noch schreiben wieso für beide timer nicht ein CLK_ROOT verwendet werden kann: Grund ist das die Hardware verschaltung es nicht zulässt. Siehe S.1426 im Handbuch.

*clock_control/clock_control_mcux_ccm_rev2.c:*
Die Funktion, über die Zephyr die Taktrate eine Peripherie abfragt (`mcux_ccm_get_subsys_rate()`), gab für beide ENET-Instanzen bisher die Taktrate einer Instanz zurück. Dan nun aber zwei unabhängig Taktgeber für die PTP-Timer existierenm wurde eine instanzabhängige Zuordnung ergänzt, sodass jede ENET-Instanz die Taktrate ihres eigenen PTP-Timers zurückerhält.

*ptp_clock/ptp_clock_nxp_enet.c:* Die capture und compare funktion der timer wurde richtig gesetzt. Zudem wurde in den Callback die Funktion hinzugefügt, timestamp an einen Task zusenden, wenn ein bei einem Timer das Capture/Compare Event ausgelöst hat.
Benötigt ist dies, um anschließend beide Timer zu Synchronisieren.

*ethernet/eth_stm32_hal_common.c:*
Funktion hizugefüht, die bei einem Capture auf dem STM32H7 ebenfalls die aktuell timestamp zu einem Task schickt.

=== Änderungen im gPTP-Subsystem
*gptp_message.c*

Davor: Wenn der Callback für den TX-Zeitstempel eines Sync-Pakets nie ausgelöst wurde, oder erneut aufgeruft wurde, bevor der vorherige Callback ausgeführt wurde, blieb sznc_cb_registered[port] für immer auf true und es konnte kein neuer Callback für die nächste Sync Nachricht gesetzt werden. -> TX Timestamps sind hängen geblieben.

Hinzufgeügt wurde ein Check der überprüft, ob  der registrierte Callback auf ein anderes Paket verweist, als das das grade gesendet wird. In diesem fall ist der Callback veraltet und wird gelöscht.

*gptp_md.c:* Sync-send state machine getting Stuck.

Davor: Falls der TX timestamp für die Sync Nachricht (md_sync_timestamp_avail) nicht vorhanden ist, bleibt die StateMachine im State Sync_SEND_SEND_FUP stecken. Dieses Problem wurde nirgends recovered und führt dazu, dass die Synchronisierung aussetzt.\
Um das Problem zu lösen wird man im GPTP_SYNC_SEND_SEND_FUP State, wenn ein festhängen erkannt wird, wieder zurück in den GPTP_SYNC_SEND_SEND_SYNC gesetzt. Dieser Ansatz startet sogesehen die GPTP_SYNC_SEND Statemachine neu und erzwingt somit das erneute Senden eines Sync-Frames.

*gptp_md.c:* Conversion bug - rate rateRatio

cumulative_scaled_rate_offset ist vom typ int32 also signed. allerdigs gibt die methode net_ntohl() einen uint32_t zurück, welche anschließend direkt in ein double convertiert wird.
Die führt dazu, dass negative Offsets als eine hohe positive Zahl interpretiert werden. Dies betrifft allerdings nur Bridgesysteme. \
Damit die Bridge weiterhin Sinnvolle Daten weiterleitet, muss die unsigned int32 direkt wieder in einen int32 gecastet werden.

== Implementierung der Bridge Synchronisation
Die folgende Implemnetierung ist keine im 802.1AS vorgesehene Implementierung. Trotzdem ist diese auf Grund dem in 3.4 gennanten Problem erforlderlich.
Zur Lösung des Problems wurde ein extra Task für die Synchronisierung der Timer angelegt.

Die Synchronisierung funktioniert dabei wiefolgt.

Die Slave Instanz hat eine für den Timer eine compare event konfiguriert. Das bedeute, dass der timer die aktuelle Zeit mit einem gegebenen Wert vergleicht und anschließend ein Puls Signal über ein GPIO Pin versendet. Dieses Signal ist auch als PPS bekannt.

Die Master Instanz hingegen hat bei dem Timer ein Capture Event konfiguriert. Hier wird das gesendete Signal vom Slave eingelesen.

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

