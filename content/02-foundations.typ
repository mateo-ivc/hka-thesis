#import "../meta.typ": note, fig-platzhalter-mittel, tab-h, tab-d, acr-emph, acrpl-emph
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Grundlagen

Dieses Kapitel legt die für das Verständnis notwendigen Grundlagen.
Erklärt werden soll hier wie:
- Time-Sensitive Networking -> fokussiert auf gPTP
- Echtzeitbetriebssysteme ZephyrRTOS
- notwendige Informationen, die später in den Testsetups benötigt werden.
  - Time-stamps, MAC vs Phy Timestamping, 
  - Sync, pDelay, ...

== Time-Sensitive Networking
Warum reicht normales Ethernet für Echtzeitanwendungen?
- Best-Effort-Prinzip, fehlende Determinismus

Welche Rolle spielt die Zeitsynchronisation:
- TSN besteht aus mehreren Rollen, als Grundbaustein steht gPTP im vordergrund um nachfolgende Protokolle wie Time-Aware Shaper (802.1Qbv) erst zu ermöglichen.


== Das Zeitsynchronisationsprotokoll IEEE 802.1AS 

- Abgrenzung zwischen NTP und PTPv2. Was sind die unterschiede und wieso wurde gPTP entwicklet?

NTP-> ist zu ungenau, gPTP zielt auf eine Genauigkeit im sub Mikrosekunden bereich während NTP im Milliskeundenbereich genau ist.

PTPv2 ist zwar auch ein Protkoll für die Clocksynchornisierung, hat allerdigns einen andern Nutzen. Es Zielt nur auf die synchronisierung in einem Netzwerk während gPTP größere und mehrer Netzwerke abdecken kann. 
Zudem ist gPTP stärker definiert, was es ermöglicht Systeme verschiedener hersteller ohnen Probleme zu kombinieren.



=== Der Synchronisationsmachanismus
Was wird eigentlich genau Synchronisiert?\
Letztendlich hat jeder Mikrocontroller einen Timer der hochzählt. Diese ist durch eine Hardware Clock angetribene. 
Der Sync Mechanismus definiert letzendlich wie schnell das hochzählen erfolgen soll. Damit die frequenz mit der Master-Clock übereinstimmt wurde sich folgendes Prinzip überlegt:

#figure(
  image("../assets/Sync/gPTP-sync-mechanism.png", width: 80%),
  caption: [Darstellung des Sync-mechanismus]
) <sync-mechanism>

@sync-mechanism Sieht man 2 verfahren wie die Synchronisierung erfolgen kann. \ Link das two-step verfahren:

Hier wird werden 2 aufeinander Folgenden Nachirchten versendet. 1. die Sync Nachricht. Diese Dient dazu die Zeit zwischen Master und Slave herauszufinden. Dabei wird der egress timestamp t1 und der ingress timestamp t2 aufgenommen. t1 wird anschließend mit zwei weiteren Infromationen, dem correctionField und der rateRatio durch die Follow_UP Nachricht zum Slave gesendet.
Diese berechnen im anschluss wie genau die Lokale Clock zum Master Synchronisiert ist. 

Beeim single-step verfahren ist der einzige Unterschied, dass die Sync-Nachircht bereits alle werte enthält die die Follow_UP Nachricht somit nicht benötigt wird. Das Funktioniert dadruch, dass der Timestamp t1 beim verlassen der Nachricht in das Ethernet-Frame geschrieben wird.
=== Messund der Leitungsverzögerung

=== Hardware-Timestamping (MAC vs PHY)

== Funktionsweise einer gPTP Bridge
    residence time erklären. Einaml -> single und multiphy verfahren.

== Das Echtzeitbetriebssystem ZephyrRTOS
Erklärung was ein Echtzeitbetribssystem ist.\
Wo es Verwendet wird\
welche vorteile es hat\
