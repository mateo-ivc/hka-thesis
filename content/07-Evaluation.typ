
#import "../meta.typ": acr-emph, fig-platzhalter-mittel, note, tab-d, tab-h
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Evaluation <evaluation>

Kapitel 6 hat die einzelnen Testszenarien jeweils für sich ausgewertet. Dieses Kapitel führt die Ergebnisse stattdessen szenarioübergreifend zusammen: Zunächst wird geprüft, welche der in Kapitel 4 abgeleiteten Anforderungen tatsächlich nachgewiesen sind und welche offen bleiben. Anschließend werden die über mehrere Testszenarien verteilt ermittelten Fehlerbeiträge zu einem Budget zusammengeführt, um die in Kapitel 6 beobachtete Offset-Entwicklung zu erklären. Danach werden die Ergebnisse gegenüber den in Kapitel 2 vorgestellten verwandten Arbeiten eingeordnet. Abschließend werden die methodischen Grenzen benannt, innerhalb derer die Ergebnisse dieser Arbeit zu interpretieren sind.

== Anforderungs-Erfüllungsmatrix <erfuellungsmatrix>
@tab-erfuellungsmatrix stellt jede in Kapitel 4 abgeleitete Anforderung ihrem jeweiligen Nachweis aus Kapitel 6 gegenüber.

#figure(
  table(
    columns: (1.9fr, 2.3fr, 1.1fr),
    align: (left, left, left),
    stroke: none,
    table.hline(),
    tab-h[Anforderung], tab-h[Nachweis], tab-h[Status],
    table.hline(stroke: 0.5pt),

    tab-d[`asCapable`-Vorbedingung (meanLinkDelay $<=800n s$, @normative-leistungsanforderungen)],
    tab-d[Indirekt: Ohne erfülltes `asCapable` fände in keinem Szenario überhaupt eine Synchronisierung statt. Kein eigener numerischer Nachweis.],
    tab-d[Indirekt erfüllt],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[LocalClock-Granularität $<=40n s$ (@normative-leistungsanforderungen)],
    tab-d[Durch Clock-Konfiguration erzwungen: $125"MHz"$-Timer $=> 8n s$ (@board-anpassungen)],
    tab-d[Erfüllt],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[rateRatio-Genauigkeit $<=0,1$#acr("ppm") (@normative-leistungsanforderungen)],
    tab-d[$sigma_y (tau=1"s") = 23,32$#acr("ppb") (@nachweis-rateratio, @basisvalidierung)],
    tab-d[Erfüllt],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[#acr-emph("E2E")-Synchronisationsgenauigkeit $<=1mu s$, bis zu 7 Hops (@normative-leistungsanforderungen)],
    tab-d[Für 2 bis 4 Hops in allen drei Kettenlängen sowie über rund 6,5 h eingehalten (@basisvalidierung, @mehrhop-validierung, @langzeitmessung)],
    tab-d[Erfüllt für 2-4 Hops, keine Aussage für 5-7 Hops],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[Robustheit unter Netzwerklast (@anforderung-netzwerklast)],
    tab-d[Konfiguration A bricht bei $14"Mbit/s"$ zusammen, Konfiguration B bleibt bis $42"Mbit/s"$ ohne gPTP-Frame-Verlust stabil (@netzwerklast-test)],
    tab-d[Nur mit Konfiguration B erfüllt],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[Ressourcenstabilität (@anforderung-ressourcenstabilitaet)],
    tab-d[Methodik in @nachweis-ressourcenstabilitaet definiert, `alloc_fail_ptp` und MAC-Zähler jedoch nicht mehr im Rahmen dieser Arbeit ausgewertet],
    tab-d[Nicht nachgewiesen],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[Hardwareanforderungen (#acr("MAC")-Timestamping, $>=2$ Ports, $>=$100BASE-TX)],
    tab-d[Durch Auswahl der Testhardware sichergestellt (@testaufbau)],
    tab-d[Erfüllt],
    table.hline(),
  ),
  caption: [Anforderungs-Erfüllungsmatrix],
) <tab-erfuellungsmatrix>

#note[Ressourcenstabilität nachträglich auswerten (siehe Platzhalter in @langzeitmessung), damit diese Zeile in der Matrix auf „Erfüllt" oder „Nicht erfüllt" korrigiert werden kann.]

Zwei Zeilen verdienen eine genauere Einordnung, da sich hinter dem knappen Status jeweils ein differenzierteres Bild verbirgt. Die Robustheit unter Netzwerklast ist bewusst als Vorher-Nachher-Vergleich angelegt: Erst die in @impl-lastschutz beschriebenen Maßnahmen versetzen die Implementierung in die Lage, die Anforderung einzuhalten; im unveränderten Zephyr-Stack (Konfiguration A) ist sie dagegen bereits bei einem Bruchteil der Portbandbreite verletzt. Beide Ergebnisse sind Teil desselben Nachweises, denn erst der Kontrast zeigt, dass die Erfüllung der Anforderung keine Eigenschaft des Protokolls, sondern der konkreten Implementierung ist. Die Ressourcenstabilität ist demgegenüber die einzige Anforderung, für die im Rahmen dieser Arbeit kein Ergebnis vorliegt: Die Messmethodik über `alloc_fail_ptp` und die MAC-Zähler ist in @nachweis-ressourcenstabilitaet festgelegt und wurde parallel zur Langzeitmessung mitgeloggt, die Auswertung selbst steht jedoch noch aus.

== Fehlerbudget <fehlerbudget>
Über die einzelnen Testszenarien verteilt lassen sich vier Fehlerquellen benennen, die zum Gesamtoffset innerhalb des $1mu s$-Budgets aus @normative-leistungsanforderungen beitragen. Für eine einzelne Bridge lassen sich drei davon direkt quantifizieren:

- *Quantisierung:* Die LocalClock-Granularität von $8n s$ (@board-anpassungen) begrenzt die Auflösung jedes einzelnen Zeitstempels und liegt damit deutlich unterhalb der geforderten $40n s$ aus @normative-leistungsanforderungen.
- *Servo-Restfehler / residence-time-Messfehler:* Wie in @basisvalidierung hergeleitet, wird die Genauigkeit der `residence time`-Messung durch den Phasen- und Frequenzfehler des bridge-internen Servos begrenzt. Der Phasenfehler dominiert dabei deutlich gegenüber dem Frequenzfehler ($113n s$ gegenüber $0,15n s$ im ungünstigsten Fall) und beide zusammen belegen maximal $113,1n s$, also $11,3%$ des zulässigen Budgets pro Bridge.
- *Auflösung der Messkette:* Der Abtastabstand des Oszilloskops von $200p s$ (siehe "Messaufbau und Datenerfassung") liegt gegenüber den übrigen Beiträgen um mehr als zwei Größenordnungen niedriger und ist damit vernachlässigbar.

In Summe ergibt sich daraus für eine einzelne Bridge ein quantifizierter, oberer Fehlerbeitrag von rund $121n s$, also etwa $12,1%$ des zulässigen Budgets - deutlich unterhalb der Grenze und konsistent mit dem in @basisvalidierung tatsächlich gemessenen Endpoint-Offset von $-114n s$ nach einer Bridge.


== Einordnung in verwandte Arbeiten <einordnung-verwandte-arbeiten>
Die in @basisvalidierung und @mehrhop-validierung gemessenen Offsets von $-114n s$ nach einem Hop bis $-428n s$ nach drei kaskadierten Bridges liegen deutlich innerhalb der von Bailleul et al. an dedizierter #acr("TSN")-Hardware gemessenen Größenordnung @bailleul2022erts, bewegen sich aber näher an deren oberem Rand. Bailleul et al. vermessen vier #acr("TSN")-Switches mit reiner ASIC-Verarbeitung und erreichen über drei Hops durchgehend Offsets im niedrigen Nanosekundenbereich. Die in dieser Arbeit erreichten einstelligen bis dreistelligen Nanosekundenwerte auf demselben Kettenlängen-Niveau erfüllen die normative $1mu s$-Grenze zwar ebenso zuverlässig, liegen aber sichtbar höher - ein plausibler Effekt des in @fehlerbudget diskutierten Servo-Restfehlers, der bei einer reinen Hardware-Switching-Fabric ohne separate PTP-Timer pro Port in dieser Form gar nicht erst entsteht (siehe @board-anpassungen).

Gegenüber Riep @riep2025 markiert diese Arbeit vor allem einen Rollenwechsel. Riep validiert den Zephyr-Stack auf derselben NXP-i.MX-RT-Plattformfamilie ausschließlich in der Rolle des Endpunkts und erreicht dabei bereits Sub-Mikrosekunden-Genauigkeit, wenn auch mit spürbarem Rückstand gegenüber der Referenzimplementierung LinuxPTP in Stabilität und Genauigkeit. Genau diese Lücke - der Zephyr-Stack als Endpunkt validiert, als Time-Aware Bridge jedoch laut eigener Projektdokumentation unvalidiert @zephyr_gptp - ist der in Kapitel 2 begründete Ausgangspunkt dieser Arbeit. Die vorliegenden Ergebnisse zeigen, dass sich diese Lücke schließen lässt: Der Zephyr-Stack hält die geforderte #acr-emph("E2E")-Genauigkeit auch als Bridge über mehrere Hops ein - vorausgesetzt, die in Kapitel 5 beschriebenen Korrekturen werden angewendet. Ohne sie wäre eine belastbare Aussage nicht möglich gewesen: Der in @lst:sync-callback-fix behandelte blockierte Zeitstempel-Callback und der in @lst:rate-ratio-fix behandelte Vorzeichenfehler bei der rateRatio-Konvertierung hätten je für sich bereits jede Synchronisierung über mehr als einen Hop verhindert.

Diese Bug-Dichte in einer einzelnen, homogenen Implementierung fügt sich in den von Brunner et al. beschriebenen Befund ein, dass die Einhaltung eines Standards auf dem Papier keine Funktion im Gesamtsystem garantiert @brunner2025crossvendor. Während Brunner et al. dies an einem herstellerübergreifenden Aufbau mit abweichenden Auslegungen desselben Standards zeigen, zeigt diese Arbeit denselben Effekt bereits innerhalb einer einzigen Implementierung: Auch ein vollständig konformes Feature-Set schützt nicht davor, dass einzelne, in der Praxis nie erprobte Codepfade die Kernfunktion vollständig verhindern. Beide Beobachtungen stützen damit dieselbe, bereits in Kapitel 2 formulierte These dieser Arbeit: Standardkonformität auf dem Papier lässt sich nur durch tatsächliche messtechnische Validierung in eine belastbare Aussage über die Funktion übersetzen.

== Threats to Validity <threats-to-validity>
Die vorangegangenen Abschnitte stützen sich auf einen konkreten Testaufbau. Die folgenden methodischen Einschränkungen grenzen ein, wie weit sich die Ergebnisse verallgemeinern lassen.

- *#acr-emph("PPS")-Sekundenmehrdeutigkeit:* Wie in @netzwerklast-test hergeleitet, trägt ein #acr-emph("PPS")-Impuls keine Information darüber, zu welcher Sekunde er gehört. Das Oszilloskop misst deshalb ausschließlich die Phasenlage zweier Flanken zueinander, nicht die absolute Differenz der zugrundeliegenden Clocks. Formal weisen alle #acr-emph("PPS")-basierten Messungen dieser Arbeit deshalb strenggenommen nur einen Offset modulo einer Sekunde nach, nicht den tatsächlichen Absolutoffset. Im Netzwerklast-Test unter Konfiguration A wird dieser Effekt sichtbar (@netzwerklast-test); für die übrigen, kompakteren Messreihen ist er zwar aufgrund der durchgehend kleinen Offsets unwahrscheinlich, aber nicht durch einen unabhängigen Sekundenabgleich (z. B. per UART-Log) explizit ausgeschlossen.
- *Debug-Build:* Sämtliche Messungen dieser Arbeit liefen mit `CONFIG_DEBUG=y` und damit unter geringerer Compiler-Optimierung (`-Og`) sowie mit Paket-Logging auf dem #acr-emph("PTP")-Pfad. Dass die Synchronisierung im unmodifizierten Zustand bereits bei rund $14"Mbit/s"$ ($1,4%$ der Portbandbreite) zusammenbricht, ist dadurch möglicherweise beeinflusst. Der relative Vorher-Nachher-Vergleich zwischen Konfiguration A und B bleibt davon jedoch unberührt, da beide unter identischen Build-Einstellungen liefen.
- *Deaktivierter #acr-emph("BTCA"):* Wie in "Rollen und Netzwerktopologie" sowie @testaufbau beschrieben, ist der #acr-emph("BTCA") im gesamten Testaufbau abgeschaltet; die Rollen sind den Geräten statisch zugewiesen. Dynamische Grandmaster-Wahl, Redundanzverhalten und Reaktion auf Topologieänderungen sind damit nicht Teil dieser Validierung.
- *Nur drei Bridges:* Wie bereits in @mehrhop-validierung diskutiert, deckt der Testaufbau mit maximal vier Hops nur einen Teil der vom Standard vorgesehenen sieben Hops ab. Der beobachtete sublineare Zuwachs lässt keine Extrapolation auf die volle Kettenlänge zu, insbesondere nicht deren Aussage zur $1mu s$-Grenze.
- *Nur eine Lastrichtung:* Wie in @netzwerklast-test ausgeführt, verfügt nur der `enet1g`-Port über #acr-emph("CBS")-Unterstützung. Last ließ sich deshalb nur in eine Richtung erzeugen, und die Wirkung der in @impl-lastschutz beschriebenen Maßnahmen wurde nur an diesem einen Port beobachtet.
