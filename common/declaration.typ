#import "../meta.typ": *

#let _months = (
  "Januar",
  "Februar",
  "März",
  "April",
  "Mai",
  "Juni",
  "Juli",
  "August",
  "September",
  "Oktober",
  "November",
  "Dezember",
)
#let _today = datetime.today()
#let _currentDate = [Karlsruhe, #_today.day(). #_months.at(_today.month() - 1) #_today.year()]

#align(center)[*Erklärung zur Nutzung generativer KI*]

#v(0.4em)
#line(length: 100%, stroke: (thickness: 0.5pt))
#v(0.6em)

Im Rahmen der Erstellung dieser Arbeit wurden generative KI-Werkzeuge in dem unten beschriebenen Umfang eingesetzt. Bei der Analyse und Eingrenzung einzelner Fehler wurden KI-Werkzeuge unterstützend hinzugezogen. Sämtliche mit Unterstützung generativer KI überarbeiteten Inhalte wurden vor der Übernahme inhaltlich geprüft und, wo erforderlich, angepasst. Die Verantwortung für den Inhalt der Arbeit liegt vollständig beim Verfasser.

#v(0.8em)
*Verwendete Hilfsmittel:*
#v(0.3em)

#pad(x: 1em)[
  - Claude (Anthropic) — eingesetzt für:
    - die Unterstützung bei der Analyse und Eingrenzung von Fehlern im Zephyr-Netzwerkstack und im Ethernet-Treiber,
    - die Unterstützung bei der Erstellung der Python-Skripte zur Auswertung der Mess- und Logdaten,
    - die Formulierung und sprachliche Überarbeitung des Fließtextes.
]

#v(1fr)

#align(center)[*Eigenständigkeitserklärung*]

#v(0.4em)
#line(length: 100%, stroke: (thickness: 0.5pt))
#v(0.6em)

Ich erkläre hiermit, dass ich die vorliegende Arbeit eigenständig und ohne unzulässige fremde Hilfe verfasst habe.
Es wurden keine anderen als die von mir angegebenen Hilfsmittel verwendet.
Sämtliche Stellen der Arbeit, die aus der zitierten Literatur wörtlich übernommen oder sinngemäß entnommen wurden, sind entsprechend kenntlich gemacht.

#v(1em)
#pad(x: 1em, [*#_currentDate*])

#v(2cm)

#box(
  width: 175pt,
  [
    #line(length: 100%, stroke: (thickness: 1pt, dash: "dotted"))
    #align(center)[(#author)]
  ],
)
