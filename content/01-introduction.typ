#import "../meta.typ": note, fig-platzhalter-gross, fig-platzhalter-mittel, fig-platzhalter-klein, acr-emph, acrpl-emph, acr-cap
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Einleitung

Kurze beschreibung was  802.1AS ist und wo es verwendet wird:

"Trichter-Prinzip" \ 
Wieso wird Echtzeitkommunikation immer relevanter? Normales Ethernet an seine grenzen und was sind die folgenden Probleme. TSN als Lösung. Grundbaustein davon ist 802.1AS (Zeitsynchronisation) \
Wie relevant ist das auf embedded Systemen? Und wieso braucht man ein RTOS dafür?


#note[Anmerkungen erscheinen nur, solange `isDraft` in `config.toml` aktiv ist.]


== Motivation
Was ist die Motivation hinter dem Thema. Wieso sollten sich andere Personen/Industrien damit beschäftigen?\ 
Generell arbeitet Etherent nach dem best effort Prinzip und kommt damit mit gewisser Zeit an seine Grenzen. Problematisch wird es dann bei Systemen die eine Gewisse Echtzeitanfoderung haben. Damit diese kritischen System trotzdem ohne Probleme Funktionieren wurden eine reihe and Standards entwickelt die man unter den Namen Time-Sensitive-Networking kennt. Der grundbaustein dafür Bildet das Synchronisieren der Clocks zwischen den Verschiedenen Systemen. 
Jede Clock im System muss über ein Grundverständniss über Zeit besitzen.

Wieso spielen Embedded Systeme hier auch eine große Rolle?
Das Linux von Mikrokontrollern
Hat den vorteil, dass der Code Plattfromunabhängig ist. 
Embedded Systeme sind meist Kostengünstiger und Energieeffizienter. 

#fig-platzhalter-mittel(
  caption: [Mittlerer Grafik-Platzhalter (80 %)],
  label: <fig:mittel>,
)[Beispiel für einen mittelgroßen Platzhalter, vgl. @fig:mittel.]

== Problemstellung

Um ZephyrRTOS effektiv in TSN-Netzwerken einzusetzen, muss das Synchronisieren nicht nur zwischen Endknoten funktionieren, sondern auch zuverlässig als Bridge, um die Zeitinformationen präzise weeiterzuleiten.

Aktuell existier im Quellcode von Zephyr eine Implementierung von des IEEE802.1AS protokolls welches auch das Bridging implementiert, allerdings wurde diese nie in der Praxis validiert.

Dadurch ist es unklar ob diese Implementierung auf den verschiedenen Systemen den strikten Genauigkeitsanforderungen des Standards erfüllen.

#fig-platzhalter-klein(
  caption: [Kleiner Grafik-Platzhalter (50 %)],
  label: <fig:klein>,
)[Beispiel für einen kleinen Platzhalter, vgl. @fig:klein.]

== Zielsetzung

Das Hauptziel der Arbeit besteht darin, die bisher unvalidierte Bridge-Funkitonalität des IEEE 802.1AS-Protokolls in ZephyrRTOS zu validieren. Um eine präzise aussage über die Synchronisationsfähigkeit im Bridge-Betrieb treffen zukönnen, wird im Rahem dieser Arbeit ein dediziertes Hadrware-Test-Setup aufgebaut. Die experimentelle Validerung erfolgt über die messtechnische Erfassung und Analyse von Pulse-Per-Second Signalen mittels eines Oszilloskops. Die daraus geweonnen Daten dienen als Grundlage, um die Eignung des aktuellen Zephyr-Protokolltapels zu bewerten.