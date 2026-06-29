#import "../meta.typ": *

#let _months = ("Januar", "Februar", "März", "April", "Mai", "Juni",
                 "Juli", "August", "September", "Oktober", "November", "Dezember")
#let _today = datetime.today()
#let _currentDate = [Karlsruhe, #_today.day(). #_months.at(_today.month() - 1) #_today.year()]

#align(center)[*Erklärung zur Nutzung generativer KI*]

#v(0.4em)
#line(length: 100%, stroke: (thickness: 0.5pt))
#v(0.6em)

// PLATZHALTER: Beschreibung der KI-Nutzung an die eigene Arbeit anpassen.
Im Rahmen der Erstellung dieser Arbeit wurden generative KI-Werkzeuge in dem unten beschriebenen Umfang eingesetzt. Beschreiben Sie hier konkret, wofür und in welchem Umfang KI verwendet wurde sowie welche Inhalte ausschließlich eigenständig erarbeitet wurden.

#v(0.8em)
*Verwendete Hilfsmittel:*
#v(0.3em)

#pad(x: 1em)[
  - Werkzeug 1 — Zweck der Nutzung \
  - Werkzeug 2 — Zweck der Nutzung
  - Werkzeug 3 — Zweck der Nutzung
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
  ]
)
