#import "../meta.typ": acr-emph, asm-listing, c-listing, diff-listing, fig-platzhalter-mittel, note, tab-d, tab-h
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Implementierung
Im folgenden Kapitel werden die Anpassungen vorgestellt, damit das #acr("gPTP")-Protokoll zuverlässig funktioniert. Dazu wird zunächst auf die Board-spezifischen Änderungen eingegangen, anschließend auf die Anpassungen im #acr("gPTP")-Subsystem selbst. Abschließend wird die interne Synchronisierung der beiden Bridge-Ports beschrieben.

== Anpassungen in Zephyr <anpassungen-in-zephyr>
Zephyrs #acr("gPTP")-Implementierung ist grundsätzlich für Endgeräte mit einer einzigen Ethernet-Schnittstelle ausgelegt und soll dort einwandfrei funktionieren, ohne dass Anwender Anpassungen vornehmen müssen. Der in dieser Arbeit verwendete Testaufbau erfordert jedoch eine Bridge mit zwei unabhängigen ENET-Instanzen - eine Konfiguration, die der Stack zwar implementiert, allerdings nie auf ihre Funktionalität validiert hat. Zudem sind im Laufe der Arbeit Fehler aufgetaucht, welche Anpassungen an Board-spezifischen Treiber als auch an dem #acr("gPTP")-Subsystem selbst erfordern. Die folgenden beiden Unterkapitel beschreiben diese Änderungen.

=== Board-spezifische Änderungen (NXP i.MX RT)
*#acr("PTP")-Clock Konfiguration*\
Die Initialisierung der #acr("PTP")-Clock wurde angepasst. Der ursprüngliche Zephyr-Code konfiguriert nur einen Clock für eine einzelne ENET-Instanz. Für die Bridge wurde ein zweiter, identisch konfigurierte CLock für die zweite ENET-Instanz ergänzt. Beide Clocks werden aus `SYS_PLL1_DIV2` (geteilt durch 20) abgeleitet, was einer Taktfrequenz von $25"MHz"$ entspricht, und erfüllen damit die in Abschnitt 3.4 geforderte Mindestauflösung.

#figure(
  diff-listing(
    "rootCfg.mux = kCLOCK_ENET_TIMER1_ClockRoot_MuxSysPll1Div2;\n"
      + "rootCfg.div = 20;\nCLOCK_SetRootClock(kCLOCK_Root_Enet_Timer1, &rootCfg);\n"
      + "\n"
      + "+rootCfg.mux = kCLOCK_ENET_TIMER2_ClockRoot_MuxSysPll1Div2;\n"
      + "+rootCfg.div = 20\n"
      + "+CLOCK_SetRootClock(kCLOCK_Root_Enet_Timer2, &rootCfg);",
    width: 90%,
  ),
  caption: [PTP-Clock Konfiguration],
) <lst:PTP-Clock_config>

Ein einzelner, gemeinsam genutzter #acr("PTP")-Timer für beide Ports ist dabei keine Alternative. In klassischen Switch-ICs, deren Ports über eine gemeinsame, integrierte Switching-Fabric verbunden sind, verteilt genau eine zentraler Clock seinen Zählerstand intern an die Timestamp-Einheiten aller Ports, sodass sich eine zusätzliche Synchronisierung zwischen den Ports von vornherein erübrigt. Auf dem hier eingesetzten #acr-emph("SoC") ist dieser Weg jedoch nicht umsetzbar: `enet` und `enet1g` sind zwei eigenständige #acr("MAC")-Peripherien, die ursprünglich für den Einsatz als jeweils einzelne Schnittstelle in einem Endgerät ausgelegt sind. Jede besitzt einen eigenen #acr("PTP")-Timer, der laut Clock-Baum des Referenzhandbuchs fest mit genau einem eigenen Taktausgang der Clock-Control-Einheit verschaltet ist (`ENET_TIMER1` bzw. `ENET_TIMER2`) @nxp_imxrt1170_refman[S. 1426]; einen internen Pfad, über den sich einer der beiden Taktausgänge zusätzlich auf die jeweils andere Instanz routen ließe, sieht die Hardware nicht vor. Eine Instanz kann folglich nicht an die Clock der anderen angeschlossen werden - weshalb zwei separate Clocks konfiguriert werden müssen und weshalb überhaupt erst die in Abschnitt 3.4 beschriebene bridge-interne Synchronisierung der beiden Timer notwendig wird.

*Instanzabhängige Taktraten-Abfrage*\
Da nun zwei unabhängige Taktgeber für die #acr("PTP")-Timer existieren, muss auch die von Zephyr bereitgestellte Taktraten-Abfrage instanzabhängig auflösen. Der #acr("PTP")-Clock-Treiber fragt darüber die Taktrate der jeweiligen ENET-Instanz ab und leitet daraus sowohl die Initialisierung des #acr("PTP")-Timers als auch die Umrechnung seiner Ticks in Nanosekunden ab. Die zuständige Funktion (`mcux_ccm_get_subsys_rate()`) gab jedoch für beide ENET-Instanzen bislang einheitlich die Taktrate derselben Instanz zurück, unabhängig davon, welche Instanz tatsächlich angefragt wurde. Im vorliegenden Aufbau sind beide Clocks zwar identisch konfiguriert, sodass dieser Fehler bislang folgenlos blieb - grundsätzlich hätte eine Instanz dadurch aber einen falschen Wert für ihre eigene Taktrate erhalten, wodurch sowohl die Initialisierung ihres #acr("PTP")-Timers als auch die spätere Rate-Korrektur auf einer falschen Zeitbasis beruht hätten. Um dies auszuschließen, wurde eine instanzabhängige Zuordnung ergänzt, sodass jede ENET-Instanz zuverlässig die Taktrate ihres eigenen #acr("PTP")-Timers zurückerhält.

*Capture/Compare-Konfiguration der #acr("PTP")-Timer*\
Die capture und compare funktion der timer wurde richtig gesetzt. Zudem wurde in den Callback die Funktion hinzugefügt, timestamp an einen Task zusenden, wenn ein bei einem Timer das Capture/Compare Event ausgelöst hat.
Benötigt ist dies, um anschließend beide Timer zu Synchronisieren.

Der #acr("PTP")-Timer der Gigabit-Instanz (`enet1g`) wurde so konfiguriert, dass er bei einem Compare-Event einen Puls über einen #acr("GPIO")-Pin ausgibt. Der #acr("PTP")-Timer der 10/100-Mbit-Instanz (`enet`) wurde so konfiguriert, dass er diesen Puls per Capture-Event einliest. In diesem Testaufbau liegt der #acr("gPTP")-Slave-Port der Bridge auf `enet1g`: Dessen Timer wird bereits durch das #acr("gPTP")-Protokoll selbst korrekt zur Grandmaster Clock synchronisiert und dient deshalb innerhalb der Bridge als Zeitreferenz. Der #acr("gPTP")-Master-Port liegt auf `enet`; sein Timer wird vom #acr("gPTP")-Stack hingegen nicht angefasst (siehe Abschnitt 3.3) und muss daher durch die in Abschnitt 4.2 beschriebene bridge-interne Synchronisierung an den Timer von `enet1g` angeglichen werden. Diese Zuordnung wirkt auf den ersten Blick vertauscht, da im #acr("gPTP")-Protokoll selbst stets die Slave-Seite korrigiert wird -- hier ist es jedoch, rein bridge-intern, umgekehrt: Der bereits synchronisierte Slave-Port dient als Referenz für den noch unsynchronisierten Master-Port. Der Aufbau setzt dabei fest voraus, dass der #acr("gPTP")-Slave-Port stets auf `enet1g` liegt. Zusätzlich wurde die #acr-emph("ISR") erweitert:\
Löst eines der beiden Events aus, wird der zugehörige Zeitstempel über eine Message-Queue an einen Task übergeben - Vorraussetzung dafür, dass beide Timer in Anschluss synchronisiert werden können.

=== Änderungen im gPTP-Subsystem
*Synchronisationsaussetzer durch blockierte #acr("gPTP")-Ports*\
Beim Senden einer Nachricht, die einen exakten Sendezeitpunkt benötigt (z.B. eine Sync-Nachricht), wird dieser Zeitstempel im #acr("gPTP")-Subsystem für die Erstellung der Follow-Up-Nachricht benötigt. Aufgenommen wird der Zeitstempel jedoch erst im #acr("MAC"). Um ihn aus dem unteren Layer in den Netzwerkstack zu bekommen, löst Zephyr dies über Callbacks: Beim Senden einer solchen Nachricht wird für den jeweiligen Port ein Callback registriert, der mit dem konkreten Paket verknüpft ist.

Wird das Paket übertragen, nimmt der #acr("MAC") den Zeitstempel per Interrupt auf und trägt ihn im Paket nach. Da dies im Interrupt-Kontext geschieht, kann der eigentliche Callback nicht direkt dort ausgeführt werden — das Paket wird stattdessen über eine Warteschlange an einen dedizierten Thread übergeben, der den Callback zeitversetzt aufruft.

Bleibt dieser Callback aus — etwa weil das Senden fehlschlägt, die Hardware für dieses Frame keinen Zeitstempel liefert, oder weil er schlicht erst später eintrifft, als die #acr("gPTP")-Zustandsmaschine auf ihn wartet — bleibt der zugehörige Registrierungs-Slot für den Port belegt. Da pro Port nur ein Slot existiert, kann kein nachfolgendes Paket mehr registriert werden, bis dieser Zustand aufgelöst wird. Dadurch kann sich der Zustand der Zustandsmaschine nicht ändern und die Synchronisation setzt aus.

Um dieses Problem zu lösen, wurden zwei sich ergänzende Anpassungen im #acr("gPTP")-Stack vorgenommen.
Zum einen wird beim Registrieren eines neuen Callbacks in `gptp_send_sync()` geprüft, ob für den Port bereits ein Callback registriert ist und ob dessen Paket-Pointer vom aktuell zu sendenden Paket abweicht. Nur in diesem Fall — wenn also erkennbar noch ein Eintrag für ein altes, nie zurückgemeldetes Paket existiert — wird dieser verworfen und stattdessen ein neuer Callback für das aktuelle Paket registriert.

#figure(
  diff-listing(
    "void gptp_send_sync(int port, struct net_pkt *pkt){\n"
      + "+    if (sync_cb_registered[port - 1]) {\n"
      + "+         if (sync_timestamp_cb[port - 1].pkt != pkt) {\n"
      + "+              net_if_unregister_timestamp_cb(sync_timestamp_cb[port - 1];\n"
      + "+              sync_cb_registered[port - 1] = false;\n"
      + "+        }\n"
      + "+    }\n"
      + "     if (!sync_cb_registered[port - 1]) {\n"
      + "          net_if_register_timestamp_cb(&sync_timestamp_cb[port - 1], pkt, \n"
      + "          net_pkt_iface(pkt),\n"
      + "          gptp_sync_timestamp_callback);\n"
      + "          sync_cb_registered[port - 1] = true;\n"
      + "     }\n"
      + "}\n",
    width: 100%,
  ),
  caption: [Bugfix in gptp_send_sync],
) <lst:sync-callback-fix>

Zum anderen wartet die Zustandsmaschine des Sync-Sendepfads nicht mehr unbegrenzt auf den TX-Zeitstempel: Beim Versenden der Sync-Nachricht wird zusätzlich ein Software-Zeitstempel aufgenommen, anhand dessen die im Zustand `GPTP_SYNC_SEND_SEND_FUP` verstrichene Zeit gemessen wird. Bleibt der TX-Zeitstempel länger als 50 ms aus, wird der Callback über `gptp_sync_send_abort()` explizit deregistriert und der Zustand zurück auf `GPTP_SYNC_SEND_SEND_SYNC` gesetzt, um den Sync-Mechanismus gezielt neu zu starten, statt auf einen Zeitstempel zu warten, der möglicherweise nie mehr eintrifft.

#figure(
  diff-listing(
    "case GPTP_SYNC_SEND_SEND_FUP:\n"
      + "     if (state->md_sync_timestamp_avail) {\n"
      + "          // send Follow_Up message ....\n"
      + "          state->state = GPTP_SYNC_SEND_SEND_SYNC;\n"
      + "+     } else if ((k_uptime_get() - state->sync_sent_uptime_ms) >=\n"
      + "+          GPTP_SYNC_TS_TIMEOUT_MS) {\n"
      + "         \n"
      + "+          gptp_sync_send_abort(port);\n"
      + "+          state->md_sync_timestamp_avail = false;\n"
      + "+          if (state->sync_ptr) {\n"
      + "+               net_pkt_unref(state->sync_ptr);\n"
      + "+               state->sync_ptr = NULL;\n"
      + "+          }\n"
      + "+          state->state = GPTP_SYNC_SEND_SEND_SYNC;\n"
      + "+     }\n"
      + "      break;\n"
      + "}",
    width: 100%,
  ),
  caption: [Timeout-Mechanismus gegen das Hängenbleiben der Sync-Send-Zustandsmaschine],
) <lst:sync-send-timeout>

Die Timeoutzeit von 50 ms wurde bewusst gewählt: Da im Standardfall alle 125 ms eine neue Sync-Nachricht versendet wird, bleibt der Zustandsmaschine damit ausreichend Zeit, um auf den TX-Zeitstempel-Callback zu warten, ohne dass ein hängen gebliebener Callback bis zum nächsten Sync-Intervall unbemerkt bliebe.

*Conversion-Bug bei der Berechnung der `rateRatio`:*\
Empfängt eine Bridge eine Follow-Up-Nachricht, so enthält deren #acr-emph("TLV") unter anderem das Feld `cumulativeScaledRateOffset`. Dieses beschreibt, um welchen (skalierten) Anteil die Taktrate der vorgelagerten Uhr von deren nominaler Rate abweicht, und wird von der Bridge zur lokalen `rateRatio` weiterverarbeitet. Diese `rateRatio` wird anschließend unter anderem dazu verwendet, die gemessene `residence time` beim Fortschreiben des `correctionField` korrekt zu skalieren. Da eine Uhr sowohl schneller als auch langsamer als nominal laufen kann, ist `cumulativeScaledRateOffset` im Standard bewusst als vorzeichenbehafteter 32-bit-Wert (`int32_t`) definiert - und genau bei dessen Konvertierung lag der Fehler.

Da das #acr("TLV")-Feld in Netz-Byte-Order übertragen wird, muss es vor der Weiterverarbeitung mittels `net_ntohl()` konvertiert werden. `net_ntohl()` liefert allerdings einen vorzeichenlosen `uint32_t`-Wert zurück. Übergibt man dieser Funktion direkt den `int32_t`-Wert aus `cumulative_scaled_rate_offset` und weist das Ergebnis ohne weiteren Zwischenschritt der `rateRatio` (Typ `double`) zu, wird das Bitmuster eines negativen Offsets bei der impliziten Konvertierung als sehr große vorzeichenlose Zahl interpretiert, bevor daraus ein `double` gebildet wird. Aus einer kleinen, negativen Ratenabweichung wird so ein um viele Größenordnungen zu großer, positiver `double`-Wert.

#figure(
  diff-listing(
    "-sync_rcv->rate_ratio = net_ntohl(fup->tlv.cumulative_scaled_rate_offset);\n"
      + "+int32_t signed_rate_offset = \n"
      + "+    (int32_t)net_ntohl(fup->tlv.cumulative_scaled_rate_offset);\n"
      + "+sync_rcv->rate_ratio = (double)signed_rate_offset;\n"
      + " sync_rcv->rate_ratio /= GPTP_POW2_41;\n"
      + " sync_rcv->rate_ratio += 1;",
    width: 100%,
  ),
  caption: [Fehlender Rück-Cast auf int32_t bei der Konvertierung des cumulativeScaledRateOffset],
) <lst:rate-ratio-fix>

Der Fix führt daher explizit eine Zwischenvariable vom Typ `int32_t` ein, in die der von `net_ntohl()` zurückgegebene Wert zurückgecastet wird, bevor er der `rateRatio` zugewiesen wird. Erst dieser Rück-Cast sorgt dafür, dass das Bitmuster wieder als vorzeichenbehaftete Zahl interpretiert wird und ein kleiner negativer Offset auch als solcher - und nicht als riesiger positiver Wert - in die `double`-Repräsentation übernommen wird.

Da die `rateRatio` unmittelbar in die Skalierung der `residence time` und damit in die Fortschreibung des `correctionField` einfließt, wirkt sich dieser Fehler direkt und ungedämpft auf das Ergebnis aus: Läuft die vorgelagerte Uhr - etwa kurz nach dem Start einer Instanz oder bei einem kurzzeitigen Offset zwischen den Timern - geringfügig langsamer als nominal, erhält die Bridge statt einer nahe bei eins liegenden `rateRatio` einen um mehrere Größenordnungen zu großen Wert. Das dadurch berechnete `correctionField` wird um denselben Faktor verfälscht, sodass die Uhr des Slaves bei jeder betroffenen Sync-Nachricht auf einen völlig falschen Wert springt. Eine Synchronisierung findet in diesem Fall faktisch nicht mehr statt.


== Implementierung der Bridge Synchronisation <bridge-sync-impl>
Das im Folgenden beschriebene Verfahren ist keine im Standard 802.1AS vorgesehene Funktion, sondern eine Board-spezifische Ergänzung, um das in Abschnitt 3.4 beschriebene Problem zu lösen: Da jede ENET-Instanz einen eigenen, unabhängigen #acr("PTP")-Timer besitzt, #acr("gPTP") aber nur den Timer des jeweils synchronisierten Ports korrigiert, würde der zweite (Master-)Port der Bridge sonst dauerhaft unsynchronisiert bleiben. Zur Lösung wurde ein eigener Task angelegt, der den Master-Port des Systems zum Slave-Port synchronisiert.

In Kapitel 4.1.1 wurde bereits beschrieben, wie die Timer-Instanzen konfiguriert sind. Der Timer der `enet1g`-Instanz vergleicht dabei fortlaufend seinen aktuellen Zählerstand mit dem im Register `ENET_TCCRn` definierten Wert. Sobald es zum Sekundenrollover kommt, speichert dieser Timer seinen aktuellen Zählerstand in einem Register und versendet einen PPS-Impuls. Die `enet`-Instanz wiederum latcht ihren aktuellen Zählerstand, sobald sie das PPS-Signal per Capture-Event erfasst.
Zusätzlich lösen beide Events einen Interrupt aus. Diese #acr("ISR") ermöglicht es, beide Hardware-Zeitstempel über eine Message-Queue an den Synchronisierungs-Task zu übergeben.
Dieser Task übernimmt die eigentliche Regelung: Er sorgt dafür, dass sich die Master-Instanz an die Slave-Instanz synchronisiert.

Der Task berechnet aus den beiden Zeitstempeln einen einfachen Phasenfehler zwischen Master- und Slave-Instanz. Überschreitet dieser Phasenfehler 500 ms, wird die Clock der Master-Instanz hart auf die von der Slave-Instanz bekannte Zeit gesetzt, anstatt sie über den #acr("PI")-Regler langsam anzunähern. Das verkürzt die Einschwingzeit erheblich, da die zu korrigierende Uhr in einem Schritt in die Nähe der Zielzeit gebracht wird - ein Vorteil vor allem dann, wenn ein Gerät neu in ein bereits laufendes System integriert wird und der anfängliche Offset dementsprechend groß ist. \
Liegt der Phasenfehler innerhalb der Schwelle, wird stattdessen die Zählrate des Timers der Master-Instanz über einen #acr("PI")-Regler angepasst:
Aus dem Phasenfehler berechnet der Regler eine Korrektur in #acr-emph("ppb"), mit der sich die Zählrate der Master-Instanz schrittweise an die der Slave-Instanz annähert.


== Priorisierung der gPTP-Nachrichten unter Netzwerklast <impl-lastschutz>
Die bisher beschriebenen Änderungen stellen sicher, dass die Synchronisierung in einem ansonsten unbelasteten Netz zuverlässig arbeitet. Sobald über denselben physischen Port zusätzlich Best-Effort-Nutzverkehr läuft, konkurriert dieser jedoch mit den #acr("gPTP")-Nachrichten um dieselben Ressourcen - und da eine Sync-Nachricht ihren Wert verliert, sobald sie verzögert oder verworfen wird, entscheidet sich genau hier, ob die Bridge die in @tab-zeitanforderungen geforderte Genauigkeit auch unter Last hält.

Der in @cbs beschriebene #acr("CBS") ist der dafür vorgesehene Mechanismus, und die #acr("MAC")-Peripherie der Gigabit-Instanz (`enet1g`) des eingesetzten #acr-emph("SoC") bringt ihn in Hardware mit; die von NXP bereitgestellte HAL macht ihn über `ENET_AVBConfigure()` zugänglich. Zephyrs ENET-Treiber nutzt diese Funktion allerdings nicht: Er betreibt für jede ENET-Instanz ausschließlich den Best-Effort-Ring 0, sodass sämtlicher Verkehr - #acr("gPTP") wie Nutzlast - denselben Sende-Ring teilt. Die Anbindung des Shapers musste daher im Treiber selbst ergänzt werden.

Der Shaper allein genügt jedoch nicht. Er reserviert ausschließlich #emph[Sende]bandbreite; die Last trifft die Bridge in diesem Aufbau aber überwiegend am Eingang, und dort entscheiden zwei weitere, rein softwareseitige Engpässe darüber, ob ein #acr("gPTP")-Frame überhaupt bis zum #acr("gPTP")-Stack gelangt: in welche Empfangs-Warteschlange es eingereiht wird und ob im Moment seines Eintreffens noch ein Netzwerkpuffer frei ist. Die folgenden Unterabschnitte beschreiben deshalb drei aufeinander aufbauende Ebenen: die Kennzeichnung der #acr("gPTP")-Nachrichten als eigene Verkehrsklasse, deren Bevorzugung auf dem Sendepfad durch den #acr("CBS") und deren Absicherung auf dem Empfangspfad.

=== Kennzeichnung der gPTP-Nachrichten
Voraussetzung für jede Priorisierung ist, dass ein Frame überhaupt als zeitkritisch erkennbar ist. Wie in @cbs beschrieben, entscheidet dies der 3 Bit breite Priority-Code-Point im VLAN-Tag. Zephyrs #acr("gPTP")-Subsystem versendet seine Nachrichten jedoch grundsätzlich ungetaggt, sodass sie sich für die #acr("MAC")-Schicht in nichts von Best-Effort-Verkehr unterscheiden.

Ergänzt wurden daher die beiden Optionen `CONFIG_NET_GPTP_VLAN_TAG` und `CONFIG_NET_GPTP_VLAN_PRIORITY`. Ist ein VLAN-Tag konfiguriert, aktiviert `gptp_add_port()` das #acr("VLAN") auf jedem als Port registrierten Interface, und `setup_gptp_frame()` versieht alle ausgehenden #acr("gPTP")-Nachrichten - Sync, Follow-Up, Announce sowie sämtliche Pdelay-Nachrichten - mit diesem Tag und dem konfigurierten Priority-Code-Point (im Testaufbau der höchste Wert 7). Der übrige Verkehr auf demselben physischen Interface bleibt davon unberührt und weiterhin ungetaggt.

Das Tagging deckte dabei eine Klasse von Fehlern im Netzwerkstack auf, die ohne #acr("VLAN") nicht auftreten kann: Die #acr("VLAN")-Verarbeitung schreibt das dem Paket zugeordnete Interface zwischen dem Zeitpunkt, zu dem der Code es liest, und dem Zeitpunkt, zu dem es tatsächlich verwendet wird, still um. Betroffen waren `gptp_prepare_pdelay_resp()`, das dadurch das (virtuelle und dauerhaft inaktive) Interface der empfangenen Anfrage erbte, der als Filter an `net_if_register_timestamp_cb()` übergebene Interface-Zeiger, der nach der Neuzuordnung nie mehr passte und damit den in @lst:sync-callback-fix behandelten TX-Zeitstempel-Callback gar nicht erst auslöste, sowie `gptp_handle_msg()`, das die Portnummer aus dem bereits umgeschriebenen Interface herleitete und deshalb jede nicht als kritisch eingestufte Nachricht verwarf.

=== Sendepfad: Anbindung des Credit Based Shapers
Die Erweiterung des Treibers ist über `CONFIG_ETH_NXP_ENET_1G_AVB` schaltbar und aktiviert einen zweiten Hardware-Ring (Ring 1) samt zugehöriger #acr-emph("DMA")-Deskriptoren, Sende-Semaphore und Staging-Puffer. Sie greift bewusst nur auf derjenigen ENET-Instanz, deren Devicetree-Knoten als `nxp,enet1g` deklariert ist: Die 10/100-Mbit-Instanz besitzt diese Hardware nicht, weshalb dort weder ein zweiter Ring aktiviert noch `ENET_AVBConfigure()` aufgerufen werden darf.

Die eigentliche Konfiguration des Shapers erfolgt beim Zurücksetzen des #acr("MAC"). Der Parameter `idleSlope` legt dabei die für Ring 1 garantierte Bandbreite fest; der reservierte Anteil der Linkbandbreite ergibt sich zu $1 \/ (1 + 512 \/ "idleSlope")$, sodass der verwendete Wert von 128 rund $20%$ entspricht.

#figure(
  c-listing(
    "1\n2\n3\n4\n5\n6\n7\n8\n9\n10",
    "if (config->avb_capable) {\n"
      + "     enet_avb_config_t avb_config = {\n"
      + "          .rxClassifyMatch = {\n"
      + "               (7U << 12) | (7U << 8) | (7U << 4) | 7U,\n"
      + "          },\n"
      + "          .idleSlope = { CONFIG_ETH_NXP_ENET_1G_AVB_IDLE_SLOPE },\n"
      + "     };\n"
      + "\n"
      + "     ENET_AVBConfigure(data->base, &data->enet_handle, &avb_config);\n"
      + "}",
    width: 100%,
  ),
  caption: [Konfiguration des Credit Based Shapers für Ring 1 der Gigabit-Instanz],
) <lst:avb-configure>

Auf dem Sendepfad wählt `eth_nxp_enet_tx()` anschließend anhand des Frame-Typs den Ring aus: #acr("PTP")-Frames werden auf den kreditgeformten Ring 1 geleitet, aller übrige Verkehr verbleibt auf Ring 0. Da beide Ringe eigene Deskriptoren und einen eigenen Staging-Puffer besitzen, kann ein voller Ring 0 den Sendevorgang einer Sync-Nachricht nicht mehr blockieren.

Dass diese Umleitung zunächst wirkungslos blieb, lag an einem Fehler in der NXP-HAL. `ENET_TransmitIRQHandler()` wertet zwar den bedienten Ring aus, um die passende Interrupt-Maske zu bestimmen, prüfte für die Entscheidung, ob die Sende-Deskriptoren zurückgewonnen werden, aber unabhängig davon fest das Interrupt-Bit von Ring 0. Für Ring 1 war diese Bedingung nie erfüllt, sodass `ENET_ReclaimTxDescriptor()` dort nie aufgerufen wurde. In der Folge blieb die Sende-Metainformation eines jeden auf Ring 1 übertragenen Frames leer - und damit auch der Zeitstempel, den der in @lst:sync-callback-fix beschriebene Mechanismus benötigt. Behoben wurde dies, indem das auszuwertende Interrupt-Bit wie die Maske selbst pro Ring bestimmt wird.

#figure(
  diff-listing(
    "uint32_t mask     = kENET_TxBufferInterrupt | kENET_TxFrameInterrupt;\n"
      + "+uint32_t frameIrq = kENET_TxFrameInterrupt;\n"
      + "\n"
      + " switch (ringId) {\n"
      + " case kENET_Ring1:\n"
      + "      mask     = kENET_TxFrame1Interrupt | kENET_TxBuffer1Interrupt;\n"
      + "+     frameIrq = kENET_TxFrame1Interrupt;\n"
      + "      break;\n"
      + " /* ... */\n"
      + " }\n"
      + "\n"
      + "-if (handle->txReclaimEnable[index] && (irq & kENET_TxFrameInterrupt)) {\n"
      + "+if (handle->txReclaimEnable[index] && (irq & frameIrq)) {\n"
      + "      ENET_ReclaimTxDescriptor(base, handle, index);\n"
      + " }",
    width: 100%,
  ),
  caption: [Ringabhängige Auswertung des Sende-Interrupts in `ENET_TransmitIRQHandler()`],
) <lst:hal-framirq-fix>

=== Empfangspfad: Ring-Bedienung, Verkehrsklasse und Pufferreservierung
Der #acr("CBS") schützt ausschließlich die Senderichtung. In dem in Kapitel "Tests" beschriebenen Lastszenario trifft die Nutzlast die Bridge aber am Eingang, sodass drei weitere Engpässe auf dem Empfangspfad beseitigt werden mussten.

*Verschränkte Bedienung beider Empfangs-Ringe*\
Der Empfangs-Task des Treibers leerte den bedienten Ring bislang vollständig, bevor er zurückkehrte - mit Ring 1 wäre daraus geworden, dass Ring 0 erst restlos abgearbeitet und Ring 1 anschließend bedient wird. Unter einer dauerhaft hohen Paketrate wird Ring 0 jedoch faktisch nie leer, sodass die Frames auf Ring 1 beliebig lange warten müssten. Die Ringe werden deshalb verschränkt bedient: abwechselnd ein Frame aus Ring 1 und eines aus Ring 0, bis beide leer sind. Damit ist die Wartezeit eines #acr("gPTP")-Frames unabhängig von der Last auf höchstens ein Ring-0-Frame begrenzt. Instanzen ohne AVB-Ring verhalten sich unverändert.

#figure(
  diff-listing(
    "-do {\n"
      + "-     ret = eth_nxp_enet_rx(dev);\n"
      + "-} while (ret == 1);\n"
      + "+ring0_empty = false;\n"
      + "+ring1_empty = !avb_capable;\n"
      + "+\n"
      + "+while (!ring0_empty || !ring1_empty) {\n"
      + "+     if (!ring1_empty) {\n"
      + "+          ring1_empty = (eth_nxp_enet_rx(dev, AVB_RING_ID) != 1);\n"
      + "+     }\n"
      + "+     if (!ring0_empty) {\n"
      + "+          ring0_empty = (eth_nxp_enet_rx(dev, RING_ID) != 1);\n"
      + "+     }\n"
      + "+}",
    width: 100%,
  ),
  caption: [Verschränkte statt sequenzieller Bedienung der beiden Empfangs-Ringe],
) <lst:rx-ring-interleave>

*Eigene Empfangs-Verkehrsklasse für gPTP*\
Zephyr kann eingehende Pakete auf mehrere nach Priorität getrennte Empfangs-Warteschlangen verteilen, wählt die Warteschlange dabei aber anhand der Priorität, die dem Paket im Treiber zugewiesen wurde. Der ENET-Treiber setzte diese nie, sodass jedes Paket mit der Standardpriorität 0 im Netzwerkstack ankam. Bei den im Testaufbau konfigurierten vier Empfangs-Verkehrsklassen bildet die Zuordnungstabelle die Prioritäten 0 und 1 auf dieselbe Klasse ab - #acr("gPTP") und Nutzlast landeten damit gemeinsam in Klasse 0, und die Konfiguration mehrerer Empfangs-Verkehrsklassen war auf der Empfangsseite vollständig wirkungslos. #acr("gPTP")-Nachrichten reihten sich dadurch hinter der Nutzlast ein und wurden verworfen, sobald deren Slot-Budget erschöpft war.

Da die Empfangs-Verkehrsklassen zudem systemweit und nicht pro Schnittstelle geführt werden, betraf dieser Engpass auch den zweiten, selbst vollkommen lastfreien Port der Bridge - was erklärt, warum sich die Störung im Testaufbau bis zum Endpoint fortsetzte. Behoben wurde dies, indem #acr("PTP")-Frames im Treiber vor der Übergabe an den Netzwerkstack die Priorität `NET_PRIORITY_IC` erhalten und damit in einer eigenen Warteschlange mit eigenem Slot-Budget landen - dieselbe Klasse, die das #acr("gPTP")-Subsystem auf der Senderichtung ohnehin bereits setzt.

#figure(
  diff-listing(
    "+if (eth_get_ptp_data(iface, pkt)) {\n"
      + "+     net_pkt_set_priority(pkt, NET_PRIORITY_IC);\n"
      + "+}\n"
      + "\n"
      + " if (net_recv_data(iface, pkt) < 0) {\n"
      + "      goto error;\n"
      + " }",
    width: 100%,
  ),
  caption: [Zuordnung empfangener PTP-Frames zu einer eigenen Verkehrsklasse],
) <lst:rx-traffic-class>

*Reservierung von Empfangspuffern*\
Die beiden vorangegangenen Maßnahmen regeln, in welcher Reihenfolge Frames bedient und eingereiht werden - nicht aber, ob für sie überhaupt Speicher zur Verfügung steht. Genau hier lag der eigentliche Engpass: Der Netzwerkstack allokiert eingehende Pakete aus einem einzigen, für alle Schnittstellen gemeinsamen Pool. Eine Messung der treiberinternen Zähler unter Last zeigte, dass auf der Gigabit-Instanz bei rund 3.670 eintreffenden Frames pro Sekunde etwa 2.300 bereits an dieser Allokation scheiterten, also rund $63%$ des Eingangsverkehrs im Treiber verworfen wurden - und, entscheidend für die Diagnose, auf der lastfreien 10/100-Instanz mit rund $56%$ ein praktisch ebenso hoher Anteil. Ein reines Durchsatzproblem eines einzelnen Ports kann das nicht erklären; die Last einer Schnittstelle leerte den gemeinsamen Pool und ließ damit jede andere Schnittstelle verhungern.

Ursächlich dafür war die Reihenfolge im Treiber: Der Netzwerkpuffer wurde allokiert, *bevor* der Frame aus dem Ring gelesen wurde. Der Treiber musste sich also für einen Puffer entscheiden, ohne die Verkehrsklasse des Frames zu kennen - weshalb weder die Hardware-Klassifizierung über den AVB-Ring noch die zuvor beschriebenen Empfangs-Verkehrsklassen beeinflussen konnten, welche Frames einen Puffer erhalten. Beide Mechanismen wurden bei der ersten Software-Allokation ausgehebelt.

Die Reihenfolge wurde deshalb umgekehrt: Der Frame wird zuerst in den ohnehin vorhandenen Staging-Puffer gelesen, anhand der gelesenen Bytes klassifiziert und erst danach aus dem passenden Pool allokiert. Für #acr("PTP")-Frames steht dafür ein eigener, reservierter Pool bereit (`CONFIG_ETH_NXP_ENET_PTP_RX_PKTS`/`_BUFS`), auf den Best-Effort-Verkehr keinen Zugriff hat. Die Klassifizierung selbst wertet dabei das Frame auf der Leitung aus - zunächst auf einen VLAN-Tag, dann auf den dahinterliegenden EtherType - statt sich auf die #acr("VLAN")-Einstellung des Interfaces zu verlassen, und ist damit für getaggte wie ungetaggte Frames auf demselben Link korrekt.

#figure(
  diff-listing(
    "-pkt = net_pkt_rx_alloc_with_buffer(data->iface, frame_length, ...);\n"
      + "-if (!pkt) {\n"
      + "-     goto flush;\n"
      + "-}\n"
      + "-\n"
      + " status = ENET_ReadFrame(data->base, &data->enet_handle,\n"
      + "                         data->rx_frame_buf, frame_length, ring_id, &ts);\n"
      + "+\n"
      + "+if (eth_nxp_enet_buf_is_ptp(data->rx_frame_buf, frame_length)) {\n"
      + "+     pkt = eth_nxp_enet_ptp_rx_alloc(data->iface, frame_length);\n"
      + "+} else {\n"
      + "+     pkt = net_pkt_rx_alloc_with_buffer(data->iface, frame_length, ...);\n"
      + "+}\n"
      + "+if (!pkt) {\n"
      + "+     goto error;\n"
      + "+}\n"
      + "\n"
      + " net_pkt_write(pkt, data->rx_frame_buf, frame_length);",
    width: 100%,
  ),
  caption: [Klassifizierung vor der Allokation, um Empfangspuffer für PTP-Frames zu reservieren],
) <lst:rx-classify-before-alloc>

Bewusst ist dieser Pool nicht an den AVB-Ring gekoppelt, sondern an das Vorhandensein einer #acr("PTP")-Clock: Die 10/100-Mbit-Instanz besitzt keinen zweiten Ring, trägt im Testaufbau aber den #acr("gPTP")-Verkehr zum Endpoint und benötigt denselben Schutz. Ein gesonderter Freigabepfad ist nicht nötig, da sowohl das Paket als auch seine Datenpuffer ihre Herkunft selbst vermerken und beim Freigeben automatisch in den reservierten Pool zurückkehren.

=== Zusammenfassung der Maßnahmen
@tab-lastschutz-massnahmen fasst zusammen, auf welcher Ebene die einzelnen Maßnahmen ansetzen und über welche Option sie jeweils aktiviert werden. Sie greifen an unterschiedlichen Engpässen und lassen sich daher nicht sinnvoll einzeln bewerten; im Lasttest in Kapitel "Tests" werden sie deshalb gemeinsam als eine Konfiguration der unveränderten Ausgangskonfiguration gegenübergestellt.

#figure(
  table(
    columns: (1.5fr, 0.9fr, 1.4fr),
    align: (left, left, left),
    stroke: none,
    table.hline(),
    tab-h[Maßnahme], tab-h[Ebene], tab-h[Konfiguration],
    table.hline(stroke: 0.5pt),
    tab-d[Prioritätskennzeichnung der gPTP-Frames per VLAN-Tag],
    tab-d[gPTP-Subsystem],
    tab-d[`NET_GPTP_VLAN_TAG`, `NET_GPTP_VLAN_PRIORITY`],

    tab-d[Kreditgeformter Sende-Ring (#acr("CBS"))],
    tab-d[MAC-Hardware, Treiber],
    tab-d[`ETH_NXP_ENET_1G_AVB`, `..._IDLE_SLOPE`],

    tab-d[Verschränkte Bedienung beider Empfangs-Ringe],
    tab-d[Treiber],
    tab-d[an `ETH_NXP_ENET_1G_AVB` gekoppelt],

    tab-d[Eigene Empfangs-Verkehrsklasse für gPTP],
    tab-d[Treiber, Netzwerkstack],
    tab-d[`NET_TC_RX_COUNT`, `NET_PRIORITY_IC`],

    tab-d[Reservierter Empfangs-Pufferpool für PTP],
    tab-d[Treiber],
    tab-d[`ETH_NXP_ENET_PTP_RX_PKTS`, `..._BUFS`],
    table.hline(),
  ),
  caption: [Maßnahmen zum Schutz der gPTP-Verkehrsklasse unter Netzwerklast],
) <tab-lastschutz-massnahmen>

#note[Kontrollmessung der Verkehrsklassen-Zähler (`net stats`) unter Last nach der Umstellung ergänzen: vorher teilten sich alle 57.761 empfangenen Pakete Klasse 0, nachher lagen 53.563 Pakete in der Best-Effort- und 4.198 in der zeitkritischen Klasse, in beiden ohne Verluste. Prüfen, ob das hier oder besser im Testkapitel steht.]
