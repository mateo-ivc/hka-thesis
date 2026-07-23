#import "../meta.typ": acr-emph, asm-listing, c-listing, fig-platzhalter-mittel, note
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Implementierung

Im folgenden Kaptiel wir vorgestellt, wie die zuvor beschriebenen Probleme behoben wurden, als auch wie die Analyse Skripte implementiert wurden, welche für die nachfolgende Evaluation verwendet wurden.

== Implementierung der Bridge Synchronisierung
"Umsetzung der Timer Synchronisierung"

Konzept steht (2 Interrupts, Offset → rateRatio, PI-Regler) — noch fehlt:
Regelkreis-Frequenz (wie oft wird synchronisiert?)
PI-Parameter (Kp/Ki) und wie sie bestimmt wurden
Rückbezug zur Anforderung residenceTimer < 10 aus Kap. 3 — wie wirkt sich die Genauigkeit dieser internen Sync auf die residence time aus?
Ablaufdiagramm wäre hier sehr hilfreich (2 Interrupts + interne PPS-Erzeugung ist ohne Grafik schwer nachvollziehbar)


Dadurch lässt sich die rateRatio berechnen (offset in beiden Timestamps) und durch einen einfachen PI-Regler Synchronisieren.
== Probleme im gPTP-Subsystem
Bugs hier auflisten und zeigen wie sie behoben wurden

=== Board specific changes
*imxrt11xx/soc.c:* Initialisierung der Clocks wurden angepasst:
Es wurde vorerst nur eine ENET Instance mit einem Timer initialisiert. Des weiteren wurde die Frequenz angepasst -> SYS_PLL1_DIV2 / 20 = 25MHz für beide PTP Timer

*clock_control/clock_control_mcux_ccm_rev2.c:* Hard mapping der Timer zu den ENET Instanzen, damit jede Instanz den Korrekten timer zugeordnet bekommt.

*ptp_clock/ptp_clock_nxp_enet.c:* Die capture und compare funktion der timer wurde richtig gesetzt. Zudem wurde in den Callback die Funktion hinzugefügt, timestamp an einen Task zusenden, wenn ein bei einem Timer das Capture/Compare Event ausgelöst hat.
Benötigt ist dies, um anschließend beide Timer zu Synchronisieren.

*ethernet/eth_stm32_hal_common.c:*
Funktion hizugefüht, die bei einem Capture auf dem STM32H7 ebenfalls die aktuell timestamp zu einem Task schickt.

=== gPTP Changes
*gptp_message.c*

Davor: Wenn der Callback für den TX-Zeitstempel eines Sync-Pakets nie ausgelöst wurde, oder erneut aufgeruft wurde, bevor der vorherige Callback ausgeführt wurde, blieb sznc_cb_registered[port] für immer auf true und es konnte kein neuer Callback für die nächste Sync Nachricht gesetzt werden. -> TX Timestamps sind hängen geblieben.

Hinzufgeügt wurde ein Check der überprüft, ob  der registrierte Callback auf ein anderes Paket verweist, als das das grade gesendet wird. In diesem fall ist der Callback veraltet und wird gelöscht.

*gptp_md.c:* Sync-send state machine getting Stuck.

Davor: Falls der TX timestampf für die Sync Nachricht (md_sync_timestamp_avail) nicht vorhanden ist, bleibt die StateMachine im State Sync_SEND_SEND_FUP stecken. Dieses Problem wurde nirgends recovered und führt dazu, dass die Synchronisierung aussetzt.

*gptp_md.c:* Conversion bug - rate rateRatio

cumulative_scaled_rate_offset ist vom typ int32 also signed. allerdigs gibt die methode net_ntohl() einen uint32_t zurück, welche anschließend direkt in ein double convertiert wird.




