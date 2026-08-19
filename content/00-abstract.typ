#import "../meta.typ": (
  acr-emph, acrpl-emph, fig-platzhalter-gross, fig-platzhalter-klein, fig-platzhalter-mittel, note, openright, tab-d,
  tab-h,
)
#import "@preview/acrostiche:0.7.0": acr, acrpl

#[
  #v(1.5cm)
  #set text(
    font: "Arial",
    size: 18pt,
  )
  = Zusammenfassung
  #v(0.75em)
]

Zeitkritische Anwendungen in der industriellen Automatisierung und im Fahrzeugbau setzen ein deterministisches Netzwerkverhalten voraus, das durch Time-Sensitive Networking (TSN) und die darin enthaltene Zeitsynchronisation mittels generalized Precision Time Protocol (gPTP) nach IEEE 802.1AS gewährleistet wird. In Netzwerken mit mehr als zwei Knoten müssen Zwischenknoten, sogenannte Time-Aware Bridges, die Zeitinformationen weiterleiten und dabei ihre eigene Verarbeitungszeit (_residenceTime_) kompensieren. Das Echtzeitbetriebssystem Zephyr beinhaltet eine Implementierung dieser Bridge-Funktionalität, die in der offiziellen Dokumentation jedoch als unvalidiert ausgewiesen wird.

Ziel dieser Bachelorarbeit ist die messtechnische Validierung und Optimierung dieser Implementierung. Dazu wurde ein Testaufbau mit bis zu drei kaskadierten Bridges realisiert, was vier Hops entspricht. Dieser Aufbau bestand aus drei phyBOARD-Atlas-Boards als Bridges sowie zwei STM32H7-Boards als Grandmaster Clock und Endpoint. Die Evaluierung der erreichten Genauigkeit erfolgte unabhängig vom Protokollstapel durch den Vergleich der Pulse-per-Second-Signale (PPS) der beteiligten Uhren mittels Oszilloskop. Voraussetzung für den stabilen Betrieb waren Korrekturen am Zephyr-Stack und am Ethernet-Treiber, darunter die Behebung eines Vorzeichenfehlers bei der _rateRatio_-Umrechnung sowie die Entsperrung blockierter Zeitstempel-Callbacks. Zusätzlich wurden Maßnahmen zur Absicherung der gPTP-Nachrichten unter Netzwerklast implementiert und ein board-interner Abgleich der unabhängigen PTP-Clocks ergänzt.

Die Ergebnisse zeigen, dass die vom Standard geforderte Ende-zu-Ende-Genauigkeit von $1mu s$ über alle aufgebauten Kettenlängen zuverlässig eingehalten wird. Der Betrag des Offsets am Endpoint steigt dabei von $114n s$ bei einer Bridge (zwei Hops) auf $428n s$ bei drei kaskadierten Bridges (vier Hops), ohne dass ein überlineares Wachstum erkennbar wäre. Während die Synchronisation im unmodifizierten Zustand bereits bei einer Netzwerklast von $14$Mbit/s zusammenbrach, blieb sie mit den implementierten Optimierungen bis $42$Mbit/s stabil, ohne dass ein einziges gPTP-Frame mangels Puffer verworfen wurde. Etwa die Hälfte des Best-Effort-Verkehrs ging dabei verloren, die Degradation traf somit ausschließlich die unkritische Verkehrsklasse. Die Arbeit weist somit nach, dass die Bridge-Funktionalität des Zephyr-Stacks nach den vorgenommenen Korrekturen praxistauglich einsetzbar ist. Eine belastbare Aussage über die im Standard vorgesehene maximale Kettenlänge von sieben Hops, entsprechend sechs kaskadierten Bridges, lässt sich aus den realisierten drei Ausbaustufen jedoch nicht ableiten.

#openright()

#[
  #v(1.5cm)
  #set text(
    font: "Arial",
    size: 18pt,
  )
  = Abstract
  #v(0.75em)
]

Time-critical applications in industrial automation and automotive engineering require deterministic network behavior, which is realized through Time-Sensitive Networking (TSN) and time synchronization via the generalized Precision Time Protocol (gPTP) according to IEEE 802.1AS. In networks with more than two nodes, intermediate nodes acting as so-called Time-Aware Bridges must forward the time information and compensate for their own processing time (residence time). The real-time operating system Zephyr includes an implementation of this bridge functionality, which is, however, explicitly marked as unvalidated in the official documentation.

The aim of this bachelor's thesis is the measurement-based validation and optimization of this implementation. For this purpose, a test setup with up to three cascaded bridges was realized, corresponding to four hops. This setup consisted of three phyBOARD-Atlas boards acting as bridges, alongside two STM32H7 boards serving as the Grandmaster Clock and endpoint. The achieved accuracy was evaluated independently of the protocol stack by comparing the Pulse-per-Second (PPS) signals of the involved clocks using an oscilloscope. Stable operation required corrections to the Zephyr stack and the Ethernet driver, including resolving a sign error in the _rateRatio_ conversion and unblocking stalled timestamp callbacks. Additionally, measures to protect gPTP messages under network load were implemented, and an internal on-board synchronization of the independent PTP clocks was added.

The results show that the end-to-end accuracy of 1~µs required by the standard is reliably maintained across all established chain lengths. The magnitude of the offset at the endpoint grows from $114n s$ with a single bridge (two hops) to $428n s$ with three cascaded bridges (four hops), with no superlinear growth observable. While synchronization in the unmodified state collapsed at a network load of just $14$Mbit/s, it remained stable up to $42$Mbit/s with the implemented optimizations, without a single gPTP frame being dropped due to buffer exhaustion. About half of the best-effort traffic was discarded in the process, so the degradation affected only the non-critical traffic class. This thesis thus demonstrates that the bridge functionality of the Zephyr stack is practically viable after the applied corrections. However, a reliable conclusion regarding the maximum chain length of seven hops specified by the standard, corresponding to six cascaded bridges, cannot be derived from the three expansion stages implemented.
