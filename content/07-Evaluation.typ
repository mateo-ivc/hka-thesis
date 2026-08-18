
#import "../meta.typ": acr-emph, fig-platzhalter-mittel, note, req, tab-d, tab-h
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Evaluation <evaluation>

@tests hat die einzelnen Testszenarien jeweils für sich ausgewertet. Dieses Kapitel führt die Ergebnisse szenarioübergreifend zusammen. Es prüft dabei, welche der in @analyse-und-entwurf abgeleiteten Anforderungen tatsächlich nachgewiesen sind, ordnet die Ergebnisse gegenüber den in @stand-der-technik vorgestellten verwandten Arbeiten ein und benennt abschließend die methodischen Grenzen, in denen sie zu interpretieren sind.

== Anforderungs-Erfüllungsmatrix <erfuellungsmatrix>
@tab-erfuellungsmatrix stellt jede in @tab-anforderungen abgeleitete Anforderung ihrem jeweiligen Nachweis aus @tests gegenüber.

#figure(
  table(
    columns: (0.3fr, 1.7fr, 2.3fr, 1.1fr),
    align: (left, left, left, left),
    stroke: none,
    table.hline(),
    tab-h[ID], tab-h[Anforderung], tab-h[Nachweis], tab-h[Status],
    table.hline(stroke: 0.5pt),

    tab-d[#req("A1")],
    tab-d[`asCapable`-Vorbedingung (meanLinkDelay $<=800n s$)],
    tab-d[Ohne erfülltes `asCapable` fände in keinem Szenario eine Synchronisation statt.],
    tab-d[Indirekt erfüllt],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[#req("A2")],
    tab-d[LocalClock-Granularität $<=40n s$],
    tab-d[Durch Clock-Konfiguration erzwungen: $125"MHz"$-Timer $=> 8n s$ (@board-anpassungen)],
    tab-d[Erfüllt],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[#req("A3")],
    tab-d[Messgenauigkeit der `neighborRateRatio` $<=0,1$#acr("ppm") je Port],
    tab-d[$sigma_y (tau_0) = 46,2$#acr("ppb") am Master- und $82,1$#acr("ppb") am Slave-Port (@tab-basisvalidierung-rateratio)],
    tab-d[Erfüllt],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[#req("A4")],
    tab-d[#acr-emph("E2E")-Synchronisationsgenauigkeit $<=1mu s$, bis zu 7 Hops],
    tab-d[Für 2 bis 4 Hops (@basisvalidierung, @mehrhop-validierung, @langzeitmessung)],
    tab-d[Erfüllt für 2--4 Hops],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[#req("A5")],
    tab-d[`residenceTime` $<=10"ms"$ je Bridge],
    tab-d[Maximalwert von $8,68"ms"$ (Mittel $5,19"ms"$) (@basisvalidierung)],
    tab-d[Erfüllt, $86,8%$ des Budgets],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[#req("A6")],
    tab-d[Robustheit unter Netzwerklast],
    tab-d[Konfiguration A bricht bei $14"Mbit/s"$ zusammen, Konfiguration B bleibt bis $42"Mbit/s"$ stabil (@netzwerklast-test)],
    tab-d[Nur mit Konfiguration B erfüllt],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[#req("A7")],
    tab-d[Hardwareanforderungen (#acr("MAC")-Timestamping, $>=2$ Ports, $>=$100BASE-TX)],
    tab-d[Durch Auswahl der Testhardware sichergestellt (@testaufbau)],
    tab-d[Erfüllt],
    table.hline(stroke: 0.2pt + luma(80)),

    tab-d[#req("A8")],
    tab-d[Verbleibende Frequenzabweichung des bridge-internen Zeitabgleichs $<=0,1$#acr("ppm")],
    tab-d[$sigma_y (tau_0) = 28,5$#acr("ppb") (@tab-basisvalidierung-rateratio)],
    tab-d[Erfüllt],
    table.hline(),
  ),
  caption: [Anforderungs-Erfüllungsmatrix],
) <tab-erfuellungsmatrix>

== Einordnung in verwandte Arbeiten <einordnung-verwandte-arbeiten>
Die in @basisvalidierung und @mehrhop-validierung gemessenen Offsets liegen ein bis zwei Größenordnungen über den Werten, die Bailleul et al. an dedizierter #acr("TSN")-Hardware erreichen: Dort bleiben die Offsets mit vier #acr("TSN")-Switches über drei Hops durchgehend im niedrigen Nanosekundenbereich @bailleul2022erts, während sie hier zwischen $-114$ und $-428"ns"$ liegen. Beide Aufbauten unterschreiten die normative Grenze von $1mu s$ damit deutlich, der hier vermessene Software-Stack jedoch mit erheblich geringerer Reserve. Gegenüber Riep @riep2025 markiert diese Arbeit vor allem einen Rollenwechsel. Riep validiert den Zephyr-Stack auf derselben NXP-i.MX-RT-Plattformfamilie ausschließlich als Endpunkt, während der Stack in der Rolle der Time-Aware Bridge laut der Zephyr-Projektdokumentation unvalidiert bleibt @zephyr_gptp. Die vorliegenden Ergebnisse zeigen, dass sich diese Lücke schließen lässt, vorausgesetzt, die in @implementierung beschriebenen Korrekturen werden angewendet. Ohne sie wäre keine Synchronisation über mehr als einen Hop zustande gekommen.

Diese Fehlerdichte in einer einzelnen, homogenen Implementierung fügt sich in den von Brunner et al. beschriebenen Befund ein, dass die Einhaltung eines Standards auf dem Papier keine Funktion im Gesamtsystem garantiert @brunner2025crossvendor. Während Brunner et al. dies an einem herstellerübergreifenden Aufbau mit abweichenden Auslegungen desselben Standards zeigen, tritt derselbe Effekt hier bereits innerhalb einer einzigen Implementierung auf. Auch ein vollständig konformer Funktionsumfang schützt nicht davor, dass einzelne, in der Praxis nie erprobte Codepfade die Kernfunktion vollständig verhindern. Beide Beobachtungen stützen damit dieselbe, bereits in @stand-der-technik formulierte These dieser Arbeit: Standardkonformität auf dem Papier lässt sich nur durch tatsächliche messtechnische Validierung in eine belastbare Aussage über die Funktion übersetzen.

== Methodische Grenzen <limitationen>
Die vorstehenden Ergebnisse gelten innerhalb eines klar umrissenen Rahmens, dessen Grenzen dieser Abschnitt nach ihrem Gewicht für die Kernaussage der Arbeit geordnet benennt.

*Kettenlänge.* Der Nachweis der #acr-emph("E2E")-Synchronisationsgenauigkeit (#req("A4")) stützt sich auf zwei, drei und vier Hops, während der Standard eine maximale Kettenlänge von sieben Hops vorsieht. Da der Betrag des beobachteten Offsets mit jeder Bridge in dieselbe Richtung wächst, ist die Hochrechnung nicht zu ignorieren. Die lineare Fortschreibung in @mehrhop-validierung führt bei sieben Hops auf rund $88%$ des Toleranzbands. Die Arbeit weist die Anforderung damit für die realisierten Ausbaustufen nach, nicht für den vom Standard adressierten Maximalfall.

*Aussagekraft des Lastszenarios.* Da von den eingesetzten Ethernet-Instanzen nur `enet1g` die benötigten #acr("TSN")-Mechanismen bereitstellt (@testaufbau), ließ sich die Last ausschließlich in eine Richtung und nur an einem einzelnen Port erzeugen. Der Nachweis der Robustheit (#req("A6")) gilt damit für diesen einen Betriebspunkt, nicht für beidseitige Last über die gesamte Kette.

*Betriebspunkt der `residenceTime`.* Der Nachweis von #req("A5") stützt sich ausschließlich auf den unbelasteten Einzelbridge-Lauf aus @basisvalidierung. Da die Weiterleitung rein in Software erfolgt, ist unter CPU- und Pufferlast eine Zunahme der Verweilzeit zu erwarten, zumal der gemessene Maximalwert bereits $86,8%$ des zulässigen Budgets ausschöpft. Ob die Obergrenze von $10"ms"$ auch unter der in @netzwerklast-test erzeugten Last eingehalten wird, ist damit nicht nachgewiesen.

*Nicht quantifizierte Fehlerquelle.* Die in @Ungenauigkeiten beschriebene #acr-emph("PHY")-Asymmetrie erklärt den beobachteten Offset am plausibelsten. Solange sie nicht durch eine eigene Messreihe der Ein- und Ausgangslatenzen beider #acrpl("PHY") beziffert ist, bleibt die Erklärung des Mehrhop-Verhaltens qualitativ.
