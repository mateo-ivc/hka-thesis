#import "../meta.typ": (
  acr-cap, acr-emph, acrpl-emph, fig-platzhalter-gross, fig-platzhalter-klein, fig-platzhalter-mittel, note,
)
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Einleitung

// Trichter: Ethernet -> TSN -> gPTP -> Embedded/RTOS -> diese Arbeit

== Motivation
Mit dem Aufkommen von Industrie 4.0 und dem autonomen Fahren steigen die Anforderungen an die Echtzeitfähigkeit industrieller und automobiler Netzwerke. Standard-Ethernet arbeitet nach dem Best-Effort-Prinzip und kann den dafür nötigen Determinismus nicht gewährleisten@ethernetDefinitiveGuide. #acr-emph("TSN") adressiert dieses Problem durch eine Reihe von #acr-emph("IEEE")-Standards. Deren Grundbaustein die präzise Zeitsynchronisation mittels #acr("IEEE") 802.1AS bildet@ieee8021as2025. Dieses Protokoll wird in der Praxis auch als #acr-emph("gPTP") bezeichnet.

Gleichzeitig gewinnen ressourcenbeschränkte Embedded-Systeme in diesen Anwendungsbereichen an Bedeutung. Sie sind kostengünstiger und energieeffizienter als herkömmliche Industrierechner. #acr-emph("RTOS") wie Zephyr@zephyr_home ermöglichen dabei eine plattformunabhängige Entwicklung mit deterministischem Zeitverhalten@hohee2021embeddedos.

== Problemstellung

#acr("gPTP") synchronisiert im einfachsten Fall zwei direkt verbundene Geräte. Sobald ein Netzwerk aus mehr als zwei Geräten besteht, müssen Zwischenknoten die Zeitinformationen aktiv weiterleiten. Diese Rolle übernehmen Time-Aware Bridges. Um Zephyr effektiv in #acr("TSN")-Netzwerken einzusetzen, muss die Synchronisierung nicht nur zwischen Endknoten funktionieren, sondern auch zuverlässig über mehrere Bridges hinweg erfolgen, um die Zeitinformationen präzise weiterzuleiten.

Aktuell existiert im Quellcode von Zephyr eine Implementierung des IEEE 802.1AS-Protokolls, welche auch das Bridging implementiert, allerdings wurde diese nie in der Praxis validiert@zephyr_gptp.

Dadurch ist es unklar, ob diese Implementierung auf den verschiedenen Systemen die strikten Genauigkeitsanforderungen des Standards erfüllt.

== Zielsetzung

Das Hauptziel der Arbeit besteht darin, die bisher unvalidierte Bridge-Funktionalität des IEEE 802.1AS-Protokolls in Zephyr zu validieren. Um eine präzise Aussage über die Synchronisationsfähigkeit im Bridge-Betrieb treffen zu können, wird im Rahmen dieser Arbeit ein dediziertes Hardware-Test-Setup aufgebaut. Die experimentelle Validierung erfolgt über die messtechnische Erfassung und Analyse von #acr-emph("PPS")-Signalen mittels eines Oszilloskops. Die daraus gewonnenen Daten dienen als Grundlage, um die Eignung des aktuellen Zephyr-Protokollstapels zu bewerten.
