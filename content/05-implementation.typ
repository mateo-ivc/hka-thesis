#import "../meta.typ": acr-emph, asm-listing, c-listing, diff-listing, fig-platzhalter-mittel, note, tab-d, tab-h
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Implementierung <implementierung>
Im folgenden Kapitel werden die Anpassungen vorgestellt, die erforderlich sind, damit das #acr("gPTP")-Protokoll zuverlässig funktioniert. Sie basieren auf Zephyr 4.4.0@zephyr_home. Dazu wird zunächst auf die Board-spezifischen Änderungen eingegangen, anschließend auf die Anpassungen im #acr("gPTP")-Subsystem selbst. Darauf folgt die interne Synchronisation der beiden Bridge-Ports. Abschließend werden die Maßnahmen beschrieben, die die #acr("gPTP")-Nachrichten unter Netzwerklast schützen.

== Anpassungen in Zephyr <anpassungen-in-zephyr>
Zephyrs #acr("gPTP")-Implementierung ist grundsätzlich für Endgeräte mit einer einzigen Ethernet-Schnittstelle ausgelegt und soll dort einwandfrei funktionieren, ohne dass Anwender Anpassungen vornehmen müssen. Der in dieser Arbeit verwendete Testaufbau erfordert jedoch eine Bridge mit zwei unabhängigen ENET-Instanzen. Eine Konfiguration, die der Stack zwar implementiert, die aber nie auf ihre Funktionalität hin validiert wurde. Zudem sind im Laufe der Arbeit Fehler aufgetreten, die Anpassungen sowohl an Board-spezifischen Treibern als auch am #acr("gPTP")-Subsystem selbst erfordern. Die folgenden beiden Unterkapitel beschreiben diese Änderungen.

=== Board-spezifische Änderungen (NXP i.MX RT) <board-anpassungen>
*#acr("PTP")-Clock-Konfiguration*\
Die Initialisierung der #acr("PTP")-Clock wurde angepasst. Zuvor konfiguriert der Zephyr-Code, wie in @lst:PTP-Clock_config zu sehen ist, nur eine einzelne ENET-Instanz. Für die zweite ENET-Instanz der Bridge wurde eine weitere, identisch konfigurierte Clock ergänzt.
`rootCfg.mux` wählt `SYS_PLL1_DIV2` ($500"MHz"$) als Quelle aus, `rootCfg.div` teilt diese durch 4 und `CLOCK_SetRootClock()` überträgt die Einstellung auf den jeweiligen Taktausgang der Clock-Control-Einheit (`Enet_Timer1` für `enet`, `Enet_Timer2` für `enet1g`). Beide #acr("PTP")-Timer laufen damit mit $125"MHz"$ und erfüllen die in @normative-leistungsanforderungen geforderte Granularität von $40n s$ mit deutlichem Abstand ($8n s$).

#figure(
  diff-listing(
    "rootCfg.mux = kCLOCK_ENET_TIMER1_ClockRoot_MuxSysPll1Div2;\n"
      + "rootCfg.div = 4;\nCLOCK_SetRootClock(kCLOCK_Root_Enet_Timer1, &rootCfg);\n"
      + "\n"
      + "+rootCfg.mux = kCLOCK_ENET_TIMER2_ClockRoot_MuxSysPll1Div2;\n"
      + "+rootCfg.div = 4;\n"
      + "+CLOCK_SetRootClock(kCLOCK_Root_Enet_Timer2, &rootCfg);",
    width: 100%,
  ),
  caption: [#acr("PTP")-Clock-Konfiguration],
) <lst:PTP-Clock_config>

Ein einzelner, gemeinsam genutzter #acr("PTP")-Timer für beide Ports ist dabei keine Alternative. In klassischen Switch-ICs, deren Ports über eine gemeinsame, integrierte Switching-Fabric verbunden sind, verteilt genau eine zentrale Clock ihren Zählerstand intern an die Timestamp-Einheiten aller Ports, sodass sich eine zusätzliche Synchronisation zwischen den Ports von vornherein erübrigt. Auf dem hier eingesetzten #acr-emph("SoC") ist dieser Weg jedoch nicht umsetzbar. Die beiden Instanzen `enet` und `enet1g` verfügen jeweils über eine eigene #acr("MAC")-Peripherie. Dementsprechend besitzt jede auch einen eigenen #acr("PTP")-Timer, der laut Clock-Baum des Referenzhandbuchs fest mit genau einem eigenen Taktausgang der Clock-Control-Einheit verschaltet ist (`ENET_TIMER1` bzw. `ENET_TIMER2`) @nxp_imxrt1170_refman[15.3]. Einen internen Pfad, über den sich einer der beiden Taktausgänge zusätzlich zur jeweils anderen Instanz routen ließe, sieht die Hardware nicht vor. Eine Instanz kann folglich nicht an die Clock der anderen angeschlossen werden, weshalb zwei separate Clocks konfiguriert werden müssen und weshalb überhaupt erst die in @testaufbau beschriebene bridge-interne Synchronisation der beiden Timer notwendig wird.

*Instanzabhängige Taktraten-Abfrage*\
Da nun zwei unabhängige Taktgeber für die #acr("PTP")-Timer existieren, muss auch die von Zephyr bereitgestellte Taktraten-Abfrage instanzabhängig auflösen. Der #acr("PTP")-Clock-Treiber fragt darüber die Taktrate der jeweiligen ENET-Instanz ab und leitet daraus sowohl die Initialisierung des #acr("PTP")-Timers als auch die Umrechnung seiner Ticks in Nanosekunden ab. Die zuständige Funktion `mcux_ccm_get_subsys_rate()` gab jedoch für beide ENET-Instanzen bislang einheitlich die Taktrate derselben Instanz zurück, unabhängig davon, welche Instanz tatsächlich angefragt wurde. Im vorliegenden Aufbau sind beide Clocks zwar identisch konfiguriert, sodass dieser Fehler bislang folgenlos blieb, grundsätzlich hätte eine Instanz dadurch aber einen falschen Wert für ihre eigene Taktrate erhalten, wodurch sowohl die Initialisierung ihres #acr("PTP")-Timers als auch die spätere Rate-Korrektur auf einer falschen Zeitbasis beruht hätten. Um dies auszuschließen, wurde eine instanzabhängige Zuordnung ergänzt, sodass jede ENET-Instanz zuverlässig die Taktrate ihres eigenen #acr("PTP")-Timers zurückerhält.

*Capture/Compare-Konfiguration der #acr("PTP")-Timer*\
Für die in @bridge-sync-impl beschriebene bridge-interne Synchronisation sind die #acr("PTP")-Timer sowie deren spezifische Capture- und Compare-Funktionen zwingend erforderlich. Die #acr("PTP")-Timer sind von Beginn an aktiv, die Funktionen jedoch nicht, sie müssen daher zunächst konfiguriert werden.

Die Synchronisationsarchitektur sieht dabei wie folgt aus. Der #acr("gPTP")-Slave-Port der Bridge liegt nach @testaufbau fest auf der `enet1g`-Instanz. Dessen Timer ist durch das #acr("gPTP")-Protokoll selbst bereits korrekt zur Grandmaster Clock synchronisiert und dient somit als interne Zeitreferenz. Zudem wurde er so konfiguriert, dass er bei einem Compare-Event einen Puls über einen #acr("GPIO")-Pin ausgibt. Der Timer des #acr("gPTP")-Master-Ports, also der `enet`-Instanz, wird vom #acr("gPTP")-Stack hingegen nicht synchronisiert und muss an den `enet1g`-Timer angeglichen werden. Er empfängt den generierten Puls über ein Capture-Event. Diese Rollenverteilung wirkt auf den ersten Blick vertauscht, da im #acr("gPTP")-Protokoll selbst stets die Slave-Seite korrigiert wird, ist für die interne Angleichung jedoch zwingend logisch.

Um diese Hardware-Events softwareseitig zu verarbeiten, wurde die #acr-emph("ISR") `ptp_clock_nxp_enet_isr()` erweitert. Tritt nun eines der beiden Events ein, liest die #acr("ISR") den exakten Hardware-Zeitstempel aus und übergibt ihn über eine Message-Queue an einen Task. Dies schafft die notwendige Datengrundlage, um beide Timer im Anschluss präzise miteinander zu synchronisieren.

=== Änderungen im #acr("gPTP")-Subsystem
*Synchronisationsaussetzer durch blockierte #acr("gPTP")-Ports*\
Beim Senden einer Nachricht, die einen exakten Sendezeitpunkt benötigt, z. B. einer Sync-Nachricht, wird dieser Zeitstempel im #acr("gPTP")-Subsystem für die Erstellung der #emph[Follow\_Up]-Nachricht benötigt. Aufgenommen wird der Zeitstempel jedoch erst im #acr("MAC"). Um ihn aus dem unteren Layer in den Netzwerkstack zu bekommen, löst Zephyr dies über Callbacks. Beim Senden einer solchen Nachricht wird für den jeweiligen Port ein Callback registriert, der mit dem konkreten Paket verknüpft ist.

Wird das Paket übertragen, nimmt der #acr("MAC") den Zeitstempel per Interrupt auf und trägt ihn im Paket nach. Da dies im Interrupt-Kontext geschieht, kann der eigentliche Callback nicht direkt dort ausgeführt werden. Stattdessen wird das Paket über eine Warteschlange an einen dedizierten Thread übergeben, der den Callback zeitversetzt aufruft.

Bleibt dieser Callback aus, etwa weil das Senden fehlschlägt, die Hardware für dieses Frame keinen Zeitstempel liefert, oder weil er schlicht erst später eintrifft, als die #acr("gPTP")-Zustandsmaschine auf ihn wartet, bleibt der zugehörige Registrierungs-Slot für den Port belegt. Da pro Port nur ein Slot existiert, kann kein nachfolgendes Paket mehr registriert werden. Dadurch kann sich der Zustand der Zustandsmaschine nicht ändern und die Synchronisation setzt aus.

Um dieses Problem zu lösen, wurden, wie in @lst:sync-callback-fix zu sehen ist, zwei sich ergänzende Anpassungen im #acr("gPTP")-Stack vorgenommen.
Zum einen wird beim Registrieren eines neuen Callbacks in `gptp_send_sync()` geprüft, ob für den Port bereits ein Callback registriert ist und ob dessen Paket-Pointer vom aktuell zu sendenden Paket abweicht. Nur in diesem Fall, wenn also erkennbar noch ein Eintrag für ein altes, nie zurückgemeldetes Paket existiert, wird dieser verworfen und stattdessen ein neuer Callback für das aktuelle Paket registriert.

#figure(
  diff-listing(
    "void gptp_send_sync(int port, struct net_pkt *pkt){\n"
      + "+ if (sync_cb_registered[port - 1]) {\n"
      + "+    if (sync_timestamp_cb[port - 1].pkt != pkt) {\n"
      + "+         net_if_unregister_timestamp_cb(sync_timestamp_cb[port - 1];\n"
      + "+         sync_cb_registered[port - 1] = false;\n"
      + "+    }\n"
      + "+ }\n"
      + "   if (!sync_cb_registered[port - 1]) {\n"
      + "     net_if_register_timestamp_cb(&sync_timestamp_cb[port - 1], pkt, \n"
      + "        net_pkt_iface(pkt),\n"
      + "        gptp_sync_timestamp_callback);\n"
      + "     sync_cb_registered[port - 1] = true;\n"
      + "   }\n"
      + "}\n",
    width: 100%,
  ),
  caption: [Bugfix in gptp_send_sync],
) <lst:sync-callback-fix>

Zum anderen würde die Zustandsmaschine des Sync-Sendepfads ohne die Änderungen in @lst:sync-send-timeout unbegrenzt auf den TX-Zeitstempel warten. Daher wird beim Versenden der Sync-Nachricht ein zusätzlicher Software-Zeitstempel aufgenommen, der die im Zustand `GPTP_SYNC_SEND_SEND_FUP` verstrichene Zeit misst. Bleibt der TX-Zeitstempel länger als $10m s$ aus, wird der Callback über `gptp_sync_send_abort()` explizit deregistriert und der Zustand zurück auf `GPTP_SYNC_SEND_SEND_SYNC` gesetzt, um den Sync-Mechanismus gezielt neu zu starten, statt auf einen Zeitstempel zu warten, der möglicherweise nie mehr eintrifft.

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
  caption: [Timeout-Mechanismus der Sync-Send-Zustandsmaschine],
) <lst:sync-send-timeout>

Der Timeout von $10m s$ wurde bewusst gewählt. Da im Standardfall alle $125m s$  eine neue Sync-Nachricht versendet wird, bleibt der Zustandsmaschine damit ausreichend Zeit, um auf den TX-Zeitstempel-Callback zu warten, ohne dass ein hängen gebliebener Callback bis zum nächsten Sync-Intervall unbemerkt bliebe.

*Conversion-Bug bei der Berechnung der `rateRatio`:*\
Empfängt eine Bridge eine #emph[Follow\_Up]-Nachricht, so enthält deren #acr-emph("TLV") unter anderem das Feld `cumulativeScaledRateOffset`. Dieses beschreibt, um welchen skalierten Anteil die Taktrate der vorgelagerten Uhr von deren nominaler Rate abweicht, und wird von der Bridge zur lokalen `rateRatio` weiterverarbeitet. Diese `rateRatio` wird anschließend unter anderem dazu verwendet, die gemessene `residenceTime` beim Fortschreiben des `correctionField` korrekt zu skalieren. Da eine Uhr sowohl schneller als auch langsamer als nominal laufen kann, ist `cumulativeScaledRateOffset` im Standard bewusst als vorzeichenbehafteter 32-Bit-Wert (`int32_t`) definiert. Genau bei dessen Konvertierung lag der Fehler.

Da das #acr("TLV")-Feld in Netz-Byte-Order übertragen wird, muss es vor der Weiterverarbeitung mittels `net_ntohl()` konvertiert werden. Das Problem ist, dass `net_ntohl()` einen vorzeichenlosen `uint32_t`-Wert zurückgibt und dass das `rateRatio`-Feld, in das der Rückgabewert geschrieben wird, vom Typ `double` ist. Übergibt man dieser Funktion allerdings einen `int32_t`-Wert aus dem `cumulative_scaled_rate_offset`-Feld und schreibt das Ergebnis ohne weiteren Zwischenschritt in das `rateRatio`-Feld, wird das Bitmuster eines negativen Offsets bei der impliziten Konvertierung als sehr große vorzeichenlose Zahl interpretiert, bevor es in das `rateRatio`-Feld gespeichert wird. Aus einer kleinen, negativen Ratenabweichung wird so ein um viele Größenordnungen zu großer, positiver `double`-Wert.

#figure(
  diff-listing(
    "-sync_rcv->rate_ratio = net_ntohl(fup->
     tlv.cumulative_scaled_rate_offset);\n\n"
      + "+int32_t signed_rate_offset = \n"
      + "+    (int32_t)net_ntohl(fup->tlv.cumulative_scaled_rate_offset);\n"
      + "+sync_rcv->rate_ratio = (double)signed_rate_offset;\n\n"
      + " sync_rcv->rate_ratio /= GPTP_POW2_41;\n"
      + " sync_rcv->rate_ratio += 1;",
    width: 100%,
  ),
  caption: [Fehlender Rück-Cast auf int32_t],
) <lst:rate-ratio-fix>

Um das Problem zu lösen, führt @lst:rate-ratio-fix daher explizit eine Zwischenvariable vom Typ `int32_t` ein, in die der von `net_ntohl()` zurückgegebene Wert zurückgecastet wird. Erst nach diesem Cast wird er der `rateRatio` zugewiesen. Dieser Rück-Cast sorgt dafür, dass das Bitmuster wieder als vorzeichenbehaftete Zahl interpretiert wird und ein kleiner negativer Offset auch als solcher und nicht als riesiger positiver Wert in die `double`-Repräsentation übernommen wird.

Da die `rateRatio` unmittelbar in die Skalierung der `residenceTime` und damit in die Fortschreibung des `correctionField` einfließt, wirkt sich dieser Fehler direkt und ungedämpft auf das Ergebnis aus. Läuft die vorgelagerte Uhr, etwa kurz nach dem Start einer Instanz oder bei einem kurzzeitigen Offset zwischen den Timern, geringfügig langsamer, erhält die Bridge statt einer nahe bei eins liegenden `rateRatio` einen um mehrere Größenordnungen zu großen Wert. Das dadurch berechnete `correctionField` wird um denselben Faktor verfälscht, sodass die Uhr des Slaves bei jeder betroffenen Sync-Nachricht auf einen völlig falschen Wert springt. Eine Synchronisation findet in diesem Fall faktisch nicht mehr statt.


== Implementierung der Bridge-Synchronisation <bridge-sync-impl>
Das im Folgenden beschriebene Verfahren ist keine im Standard 802.1AS vorgesehene Funktion, sondern eine Board-spezifische Ergänzung, um das in @testaufbau beschriebene Problem mit den unabhängigen #acr("PTP")-Clocks zu lösen. Umgesetzt wird sie durch einen eigenen Task, der den Master-Port des Systems zum Slave-Port synchronisiert.

In @board-anpassungen wurde bereits beschrieben, wie die Timer-Instanzen konfiguriert sind. Der Timer der `enet1g`-Instanz vergleicht dabei fortlaufend seinen aktuellen Zählerstand mit dem im Register `ENET_TCCRn` definierten Wert. Sobald es zum Sekundenrollover kommt, speichert dieser Timer seinen aktuellen Zählerstand in einem Register und versendet einen #acr("PPS")-Impuls. Die `enet`-Instanz wiederum speichert ihren aktuellen Zählerstand, sobald sie das #acr("PPS")-Signal per Capture-Event erfasst.
Zusätzlich lösen beide Events einen Interrupt aus. Diese #acr("ISR") ermöglicht es, beide Hardware-Zeitstempel über eine Message-Queue an den Synchronisations-Task zu übergeben.
Dieser Task übernimmt die eigentliche Regelung. Er sorgt dafür, dass sich die Master-Instanz an die Slave-Instanz synchronisiert.

Der Task berechnet aus den beiden Zeitstempeln einen einfachen Phasenfehler (Slave- $minus$ Master-Timestamp). Überschreitet dieser Phasenfehler $500m s$, wird die Clock der Master-Instanz hart auf die von der Slave-Instanz gemeldete Zeit gesetzt, anstatt sie über den #acr("PI")-Regler langsam anzunähern. Das verkürzt die Einschwingzeit erheblich, da die zu korrigierende Uhr in einem Schritt in die Nähe der Zielzeit gebracht wird, ein Vorteil vor allem dann, wenn ein Gerät neu in ein bereits laufendes System integriert wird und der anfängliche Offset dementsprechend groß ist. Liegt der Phasenfehler innerhalb der Schwelle, wird stattdessen die Zählrate des Timers der Master-Instanz über einen #acr("PI")-Regler angepasst:
Aus dem Phasenfehler berechnet der Regler eine Korrektur in #acr-emph("ppb"), mit der sich die Zählrate der Master-Instanz schrittweise an die der Slave-Instanz annähert.


== Priorisierung der #acr("gPTP")-Nachrichten <impl-lastschutz>
Die bisher beschriebenen Änderungen stellen sicher, dass die Synchronisation in einem ansonsten unbelasteten Netz zuverlässig arbeitet. Sobald über denselben physischen Port zusätzlich Best-Effort-Nutzverkehr läuft, konkurriert dieser jedoch mit den #acr("gPTP")-Nachrichten um dieselben Ressourcen. Problematisch ist dabei weniger der Zeitstempel selbst, der auch bei einer verspäteten Nachricht korrekt bliebe, als vielmehr, dass die beteiligten Zustandsmaschinen nur ein enges Zeitfenster für dessen Eintreffen vorsehen. Wird dieses Fenster durch die Last überschritten, behandelt die Implementierung die Nachricht als verloren und verwirft sie. Genau hier entscheidet sich, ob die Bridge die in @normative-leistungsanforderungen geforderte Genauigkeit auch unter Last hält und damit die in @anforderung-netzwerklast beschriebene Vorbedingung der #acr-emph("E2E")-Synchronisationsgenauigkeit erfüllt.

Der in @cbs beschriebene #acr("CBS") ist einer der dafür vorgesehenen Mechanismen. Die von NXP bereitgestellte #acr-emph("HAL") macht ihn über `ENET_AVBConfigure()` zugänglich @nxp_mcuxpresso_enet. Zephyrs ENET-Treiber nutzt diese Funktion allerdings nicht. Dieser betreibt für jede ENET-Instanz ausschließlich den Best-Effort-Ring 0, sodass sämtlicher Verkehr, #acr("gPTP") wie Nutzlast, denselben Ring teilt. Die Anbindung des #acr("CBS") musste daher im Treiber selbst ergänzt werden.

Der Shaper allein genügt jedoch nicht. Er reserviert ausschließlich die Sendebandbreite. Die Last trifft die Bridge in diesem Aufbau aber überwiegend am Eingang, also im Empfangspfad. Dort entscheidet sich vor allem, ob ein #acr("gPTP")-Frame überhaupt bis zum #acr("gPTP")-Stack gelangt und ob im Moment seines Eintreffens noch Platz im Netzwerkpuffer ist. Die folgenden Unterabschnitte beschreiben deshalb drei aufeinander aufbauende Ebenen. Die Kennzeichnung der #acr("gPTP")-Nachrichten als eigene Verkehrsklasse, deren Bevorzugung auf dem Sendepfad durch den #acr("CBS") und deren Absicherung auf dem Empfangspfad.

=== Kennzeichnung der #acr("gPTP")-Nachrichten
Je nach Hardware können die #acr("gPTP")-Nachrichten direkt im #acr("MAC") erkannt und priorisiert werden. Mit der eingesetzten Hardware ist dies nicht möglich, weshalb VLAN-Tags verwendet werden, um die Nachrichten zu kennzeichnen. Wie in @cbs beschrieben, entscheidet darüber der 3-Bit breite Priority-Code-Point im VLAN-Tag. Zephyrs #acr("gPTP")-Subsystem versendet seine Nachrichten jedoch grundsätzlich ungetaggt, was sie für die #acr("MAC")-Schicht ununterscheidbar vom Best-Effort-Verkehr macht.

In der Kconfig wurden daher die beiden Optionen `CONFIG_NET_GPTP_VLAN_TAG` und `CONFIG_NET_GPTP_VLAN_PRIORITY` ergänzt. Ist ein VLAN-Tag konfiguriert, aktiviert `gptp_add_port()` das #acr("VLAN") auf jedem als Port registrierten Interface. `setup_gptp_frame()` versieht alle ausgehenden #acr("gPTP")-Nachrichten mit diesem Tag und dem konfigurierten Priority-Code-Point (im Testaufbau der höchste Wert 7). Der übrige Verkehr auf demselben physischen Interface bleibt davon unberührt und weiterhin ungetaggt.

Das Tagging deckte dabei eine Klasse von Fehlern im Netzwerkstack auf, die ohne #acr("VLAN") nicht auftreten kann. Die #acr("VLAN")-Verarbeitung schreibt das dem Paket zugeordnete Interface zwischen Lese- und Verwendungszeitpunkt still um. Betroffen waren `gptp_prepare_pdelay_resp()`, der an `net_if_register_timestamp_cb()` übergebene Interface-Zeiger sowie `gptp_handle_msg()`. An allen drei Stellen passte das Interface danach nicht mehr zum adressierten Port. Die Folgen waren, dass die Funktion `gptp_prepare_pdelay_resp()` das virtuelle, dauerhaft inaktive Interface erbt. Der Interface-Zeiger löst dadurch den in @lst:sync-callback-fix behandelten TX-Zeitstempel-Callback nicht mehr aus und `gptp_handle_msg()` leitete die Portnummer aus dem falschen Interface ab. Dadurch verwarf `gptp_handle_msg()` jede Nachricht, die über ein #acr("VLAN")-Tag verfügt.

=== Sendepfad: Anbindung des Credit Based Shapers
Die Erweiterung des Treibers ist über `CONFIG_ETH_NXP_ENET_1G_AVB` schaltbar und aktiviert einen zweiten Hardware-Ring (Ring 1) samt zugehöriger #acr-emph("DMA")-Deskriptoren, Sende-Semaphore und Staging-Puffer. Sie wirkt bewusst nur auf die `enet1g`-Instanz, die diese Hardware-Unterstützung besitzt. Die `enet`-Instanz bleibt davon unberührt.

Die eigentliche Konfiguration des Shapers erfolgt beim Zurücksetzen des #acr("MAC"). Der Parameter `idleSlope` legt dabei die für Ring 1 garantierte Bandbreite fest. Die verwendete Konfiguration reserviert dafür rund $20%$ der gesamten Linkbandbreite.

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
  caption: [Credit-Based-Shaper-Konfiguration],
) <lst:avb-configure>

Auf dem Sendepfad wählt `eth_nxp_enet_tx()` anschließend anhand des Frame-Typs den Ring aus. Maßgeblich ist der in `rxClassifyMatch` hinterlegte VLAN-Priority-Wert, hier 7 (siehe @lst:avb-configure). Frames mit dieser Priorität werden dem Ring 1 zugeordnet, der übrige Verkehr verbleibt auf Ring 0. Da beide Ringe eigene Deskriptoren und einen eigenen Staging-Puffer besitzen, kann ein voller Ring 0 den Sendevorgang einer Sync-Nachricht nicht mehr blockieren.

Damit diese Umleitung tatsächlich wirkt, muss zusätzlich eine Anpassung in der NXP-#acr("HAL") berücksichtigt werden: `ENET_TransmitIRQHandler()` prüfte für die Rückgewinnung der Sende-Deskriptoren unabhängig vom bedienten Ring fest das Interrupt-Bit von Ring 0, sodass `ENET_ReclaimTxDescriptor()` für Ring 1 nie aufgerufen wurde und die benötigten Sende-Zeitstempel leer blieben. Auch dieses Bit musste daher ringabhängig ausgewertet werden.


=== Empfangspfad: Ring-Bedienung, Verkehrsklasse und Pufferreservierung
Der #acr("CBS") schützt ausschließlich die Senderichtung. In dem in @tests beschriebenen Lastszenario trifft die Nutzlast die Bridge aber am Eingang. Daher müssen drei weitere Engpässe auf dem Empfangspfad beseitigt werden.

*Verschränkte Bedienung beider Empfangs-Ringe*\
Der Empfangs-Task des Treibers bediente bislang ausschließlich Ring 0. Ring 1 blieb dabei vollständig unberücksichtigt. Mit dem zweiten Ring muss der Task nun sicherstellen, dass auch dessen Frames abgeholt werden. Dies geschieht durch abwechselndes Auslesen. Der Task liest im Wechsel ein Frame aus Ring 1 und eines aus Ring 0, bis beide Ringe leer sind (siehe @lst:rx-ring-interleave). Damit ist die Wartezeit eines #acr("gPTP")-Frames unabhängig von der Last auf höchstens ein Ring-0-Frame begrenzt. Instanzen ohne AVB-Ring verhalten sich unverändert.

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
  caption: [Abarbeitung beider Empfangs-Ringe],
) <lst:rx-ring-interleave>

*Eigene Empfangs-Verkehrsklasse für gPTP*\
Zephyr kann eingehende Pakete anhand einer im Treiber zugewiesenen Priorität auf mehrere getrennte, priorisierte Empfangs-Warteschlangen zum Netzwerkstack verteilen. Der ENET-Treiber setzte diese Priorität jedoch nie, sodass sämtliche Pakete mit der Standardpriorität 0 ankommen. Dadurch landen alle Pakete unabhängig von der Verkehrsklasse in derselben Warteschlange. Die konfigurierten Verkehrsklassen blieben auf der Empfangsseite damit wirkungslos. Behoben wurde dies durch @lst:rx-traffic-class, indem #acr("PTP")-Frames im Treiber vor der Übergabe an den Netzwerkstack die Priorität `NET_PRIORITY_IC` erhalten und damit in einer eigenen Warteschlange landen, derselben Klasse, die das #acr("gPTP")-Subsystem sendeseitig ohnehin bereits setzt. `eth_get_ptp_data()` überprüft dabei, ob es sich bei dem Frame um ein #acr("gPTP")-Frame handelt.

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
  caption: [Zuordnung empfangener #acr("PTP")-Frames zur Verkehrsklasse],
) <lst:rx-traffic-class>

*Reservierung von Empfangspuffern*\
Die beiden vorangegangenen Maßnahmen regeln, in welcher Reihenfolge Frames bedient und eingereiht werden, nicht aber, ob für sie überhaupt Speicher zur Verfügung steht. Genau hier liegt der eigentliche Engpass. Trotz separater Ringe und eigener Verkehrsklasse allokiert der Netzwerkstack eingehende Pakete weiterhin aus einem einzigen, für alle Schnittstellen und Verkehrsklassen gemeinsamen Pool. #acr("gPTP") und Best-Effort-Verkehr konkurrieren dort also unverändert um denselben Speicher, wodurch die Last einer Schnittstelle jede andere blockieren kann.

Ursächlich dafür war die Reihenfolge im Treiber. Der Treiber allokiert den Netzwerkpuffer für ein Paket, bevor das Frame aus dem Ring gelesen wird. Das bedeutet, dass der Treiber beide Verkehrsklassen bei der Allokation gleich behandelt. Weder die Hardware-Klassifizierung noch die zuvor beschriebenen Empfangs-Verkehrsklassen können dadurch beeinflussen, welche Frames einen Puffer erhalten.

Die Reihenfolge wurde deshalb umgekehrt. Das Frame wird zuerst in den ohnehin vorhandenen Staging-Puffer gelesen, anhand der gelesenen Bytes klassifiziert und erst danach aus dem passenden Pool allokiert. Für #acr("PTP")-Frames steht dafür ein eigener, reservierter Pool bereit. Die Klassifizierung selbst wertet dabei das Frame auf der Leitung aus. Zunächst auf ein VLAN-Tag für den Ring und anschließend auf den dahinterliegenden EtherType für die Priority-Queue.

#figure(
  diff-listing(
    "-pkt = net_pkt_rx_alloc_with_buffer(data->iface, frame_length, ...);\n"
      + "-if (!pkt) {\n"
      + "-     goto flush;\n"
      + "-}\n"
      + "\n"
      + " status = ENET_ReadFrame(data->base, &data->enet_handle,\n"
      + "                         data->rx_frame_buf, ...);\n"
      + "\n"
      + "+if (eth_nxp_enet_buf_is_ptp(data->rx_frame_buf, frame_length)) {\n"
      + "+     pkt = eth_nxp_enet_ptp_rx_alloc(data->iface, frame_length);\n"
      + "+} else {\n"
      + "+     pkt = net_pkt_rx_alloc_with_buffer(data->iface, ...);\n"
      + "+}\n"
      + "+if (!pkt) {\n"
      + "+     goto error;\n"
      + "+}\n"
      + "\n"
      + " net_pkt_write(pkt, data->rx_frame_buf, frame_length);",
    width: 100%,
  ),
  caption: [Prioritätsbasierte Allokation der Empfangspuffer],
) <lst:rx-classify-before-alloc>

Bewusst ist dieser Pool nicht an den AVB-Ring gekoppelt, sondern an das Vorhandensein einer #acr("PTP")-Clock. Die `enet`-Instanz besitzt keinen zweiten Ring, trägt im Testaufbau aber den #acr("gPTP")-Verkehr zum Endpoint und benötigt denselben Schutz.

=== Zusammenfassung der Maßnahmen
@tab-lastschutz-massnahmen fasst zusammen, auf welcher Ebene die einzelnen Maßnahmen ansetzen und über welche Option sie jeweils aktiviert werden. Sie greifen an unterschiedlichen Engpässen und lassen sich daher nicht sinnvoll einzeln bewerten. In @netzwerklast-test werden sie deshalb gemeinsam als eine Konfiguration der unveränderten Ausgangskonfiguration gegenübergestellt.

#figure(
  table(
    columns: (1.5fr, 0.9fr, 1.4fr),
    align: (left, left, left),
    stroke: none,
    table.hline(),
    tab-h[Maßnahme], tab-h[Ebene], tab-h[Konfiguration],
    table.hline(stroke: 0.5pt),
    tab-d[Prioritätskennzeichnung über VLAN-Tags],
    tab-d[#acr("gPTP")-Subsystem],
    tab-d[`NET_GPTP_VLAN_TAG`, `NET_GPTP_VLAN_PRIORITY`],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[#acr("CBS") Sende-Ring],
    tab-d[MAC-Hardware, Treiber],
    tab-d[`ETH_NXP_ENET_1G_AVB`, `ETH_NXP_ENET_1G_AVB_IDLE_SLOPE`],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[Abarbeitung beider Empfangs-Ringe],
    tab-d[Treiber],
    tab-d[an `ETH_NXP_ENET_1G_AVB` gekoppelt],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[Eigene Empfangs-Verkehrsklasse für gPTP],
    tab-d[Treiber, Netzwerkstack],
    tab-d[`NET_TC_RX_COUNT`, `NET_PRIORITY_IC`],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[Reservierter Empfangs-Pufferpool für gPTP],
    tab-d[Treiber],
    tab-d[`ETH_NXP_ENET_PTP_RX_PKTS`, `ETH_NXP_ENET_PTP_RX_BUFS`],
    table.hline(),
  ),
  caption: [Maßnahmen zum Schutz der #acr("gPTP")-Verkehrsklasse unter Netzwerklast],
) <tab-lastschutz-massnahmen>
