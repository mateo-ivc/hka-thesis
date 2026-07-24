#import "../meta.typ": (
  acr-cap, acr-emph, acrpl-emph, fig-platzhalter-gross, fig-platzhalter-klein, fig-platzhalter-mittel, note,
)
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Einleitung

// Trichter: Ethernet -> TSN -> gPTP -> Embedded/RTOS -> diese Arbeit

== Motivation
Mit dem Aufkommen von Industrie 4.0 und dem autonomen Fahren steigen die Anforderungen an die Echtzeitfähigkeit industrieller Netzwerke. Standard-Ethernet arbeitet nach dem Best-Effort-Prinzip und kann den dafür nötigen Determinismus nicht gewährleisten. Time-Sensitive Networking (TSN) adressiert dieses Problem durch eine Reihe von IEEE-Standards, deren Grundbaustein die präzise Zeitsynchronisation mittels IEEE 802.1AS (gPTP) bildet.

Gleichzeitig gewinnen ressourcenbeschränkte Embedded-Systeme in diesen Anwendungsbereichen an Bedeutung. Sie sind kostengünstiger und energieeffizienter als herkömmliche Industrierechner. Echtzeitbetriebssysteme wie ZephyrRTOS ermöglichen dabei eine plattformunabhängige Entwicklung mit deterministischem Zeitverhalten.

#fig-platzhalter-mittel(
  caption: [Mittlerer Grafik-Platzhalter (80 %)],
  label: <fig:mittel>,
)[Beispiel für einen mittelgroßen Platzhalter, vgl. @fig:mittel.]

== Problemstellung

Um ZephyrRTOS effektiv in TSN-Netzwerken einzusetzen, muss die Synchronisierung nicht nur zwischen Endknoten funktionieren, sondern auch zuverlässig innerhalb von Bridges erfolgen, um die Zeitinformationen präzise weiterzuleiten.

Aktuell existiert im Quellcode von Zephyr eine Implementierung des IEEE 802.1AS-Protokolls, welche auch das Bridging implementiert, allerdings wurde diese nie in der Praxis validiert.

Dadurch ist es unklar, ob diese Implementierung auf den verschiedenen Systemen die strikten Genauigkeitsanforderungen des Standards erfüllt.

#fig-platzhalter-klein(
  caption: [Kleiner Grafik-Platzhalter (50 %)],
  label: <fig:klein>,
)[Beispiel für einen kleinen Platzhalter, vgl. @fig:klein.]

== Zielsetzung

Das Hauptziel der Arbeit besteht darin, die bisher unvalidierte Bridge-Funktionalität des IEEE 802.1AS-Protokolls in ZephyrRTOS zu validieren. Um eine präzise Aussage über die Synchronisationsfähigkeit im Bridge-Betrieb treffen zu können, wird im Rahmen dieser Arbeit ein dediziertes Hardware-Test-Setup aufgebaut. Die experimentelle Validierung erfolgt über die messtechnische Erfassung und Analyse von Pulse-Per-Second-Signalen mittels eines Oszilloskops. Die daraus gewonnenen Daten dienen als Grundlage, um die Eignung des aktuellen Zephyr-Protokollstapels zu bewerten.
