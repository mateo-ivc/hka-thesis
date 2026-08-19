#import "../meta.typ": (
  acr-cap, acr-emph, acrpl-emph, fig-platzhalter-gross, fig-platzhalter-klein, fig-platzhalter-mittel, note,
)
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Einleitung

// Trichter: Ethernet -> TSN -> gPTP -> Embedded/RTOS -> diese Arbeit

== Motivation
Mit dem Aufkommen von Industrie 4.0 und dem autonomen Fahren steigen die Anforderungen an die Echtzeitfähigkeit industrieller und automobiler Netzwerke. Standard-Ethernet arbeitet nach dem Best-Effort-Prinzip und kann den hierfür erforderlichen Determinismus nicht gewährleisten @ethernetDefinitiveGuide. #acr-emph("TSN") begegnet diesem Problem mit einer Reihe von #acr-emph("IEEE")-Standards. Deren Grundlage bildet die präzise Zeitsynchronisation nach #acr("IEEE") 802.1AS @ieee8021as2025, die in der Praxis auch als #acr-emph("gPTP") bezeichnet wird.

Gleichzeitig gewinnen ressourcenbeschränkte Embedded-Systeme in diesen Anwendungsbereichen an Bedeutung. Sie sind kostengünstiger und energieeffizienter als herkömmliche Industrierechner. #acr-emph("RTOS", plural: true) wie Zephyr @zephyr_home ermöglichen eine plattformunabhängige Entwicklung mit deterministischem Zeitverhalten @hohee2021embeddedos.

== Problemstellung

#acr("gPTP") synchronisiert im einfachsten Fall zwei direkt verbundene Geräte. Sobald ein Netzwerk aus mehr als zwei Geräten besteht, müssen Zwischenknoten die Zeitinformationen aktiv weiterleiten. Diese Rolle übernehmen Time-Aware Bridges. Ein Einsatz von Zephyr in #acr("TSN")-Netzwerken setzt daher voraus, dass die Synchronisation nicht allein zwischen zwei Endknoten, sondern ebenso zuverlässig über mehrere kaskadierte Bridges hinweg funktioniert.

Der Quellcode von Zephyr enthält bereits eine Implementierung des IEEE 802.1AS-Protokolls, die auch die Bridge-Funktionalität abdeckt. In der Praxis validiert wurde diese jedoch nie @zephyr_gptp. Ob sie die strikten Genauigkeitsanforderungen des Standards auf den eingesetzten Zielplattformen erfüllt, ist somit ungeklärt.

== Zielsetzung <zielsetzung>

Ziel dieser Arbeit ist es, die bislang nicht überprüfte Bridge-Funktionalität des IEEE 802.1AS-Protokolls in Zephyr messtechnisch zu validieren. Um eine belastbare Aussage über die Synchronisationsfähigkeit im Bridge-Betrieb treffen zu können, wird eigens ein Versuchsaufbau aus realer Hardware errichtet. Die experimentelle Validierung erfolgt durch die Erfassung und Auswertung der #acr-emph("PPS")-Signale mit einem Oszilloskop. Die gewonnenen Messdaten bilden die Grundlage für die Bewertung des aktuellen Zephyr-Protokollstapels.

Gegenstand der Validierung ist dabei die im Standard als PTP Relay Instance bezeichnete Zeitsynchronisationsfunktion einer Time-Aware Bridge: das Empfangen, Korrigieren und Weitersenden der #acr("gPTP")-Nachrichten unter Kompensation der eigenen Verarbeitungszeit. Die Vermittlung des übrigen Ethernet-Verkehrs zwischen den Ports ist nicht Teil der Untersuchung.
