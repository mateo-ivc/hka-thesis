#import "@preview/outrageous:0.4.0"
#import "@preview/acrostiche:0.7.0": *
#import "meta.typ": *

#set document(title: title, author: author, keywords: keywords)

// Abkürzungen (Erstverwendung = Langform + Abkürzung, danach nur Abkürzung)
// Beispiele: durch eigene Abkürzungen ersetzen oder ergänzen.
#init-acronyms((
  "ECU": ("Steuergerät", "Steuergeräte"),
  "CAN": ("Controller Area Network",),
  "API": ("Application Programming Interface",),
))

// Kurzformen nur im Abkürzungsverzeichnis (Fließtext bleibt bei short/short-pl)
#let abk-index-short = (:)

#set text(font: "Cambria")

#set page("a4",
  background: if isDraft { rotate(24deg, text(150pt, fill: rgb("dedede66"))[*DRAFT*]) },
)

// Erste Seite: Aufgabenstellung (Platzhalter). Bei mehrseitigem PDF weitere
// #image(...) mit page: 2, page: 3 ... ergänzen oder diesen Block entfernen.
#[
  #set page("a4", margin: 0pt, background: none)
  #image("assets/aufgabenstellung.svg", width: 100%, height: 100%)
]

#set page("a4", margin: 30mm)
#set text(size: 12pt)

// Eigenständigkeits- und KI-Erklärung
#include "common/declaration.typ"
#pagebreak(to: if isTwoSided { "odd" } else { none })

// Titelseite
#include "common/cover.typ"
#pagebreak()

// Seitennummerierung beginnen
#set page(numbering: "i")
#counter(page).update(1)

#set par(justify: true)

// Zusammenfassung / Abstract
#include "content/00-Zusammenfassung.typ"
#pagebreak(to: if isTwoSided { "odd" } else { none })

// Inhaltsverzeichnis
#show outline.entry: outrageous.show-entry.with(
  ..outrageous.presets.outrageous-toc,
  fill: (none, line(length: 100%, stroke: (thickness: 1pt, dash: "loosely-dotted"))),
)

#text(size: 21pt, font: "Arial")[*Inhaltsverzeichnis*]
#v(20pt)

#outline(title: none, indent: auto)
#pagebreak(to: if isTwoSided { "odd" } else { none })

// Abbildungsverzeichnis
#show outline.entry: outrageous.show-entry.with(
  ..outrageous.presets.outrageous-figures,
)

#text(size: 21pt)[*Abbildungsverzeichnis*]
#v(0pt)

#outline(title: "", target: figure.where(kind: image))

#pagebreak(to: if isTwoSided { "odd" } else { none })

// Tabellen- und Listingverzeichnis
#text(size: 21pt)[*Tabellenverzeichnis*]
#v(0pt)

#outline(title: "", target: figure.where(kind: table))

#v(40pt)

#text(size: 21pt)[*Listingverzeichnis*]
#v(0pt)

#outline(title: "", target: figure.where(kind: raw))

#pagebreak(to: if isTwoSided { "odd" } else { none })

// Abkürzungsverzeichnis (eigene Seite, nach Tabellen- und Listingverzeichnis)
#text(size: 21pt)[*Abkürzungsverzeichnis*]
#v(0pt)

#print-abk-verzeichnis(index-short: abk-index-short)

#pagebreak(to: if isTwoSided { "odd" } else { none })

// Beginn Hauptteil

#let ht-first = state("page-first-section", [])
#let ht-last  = state("page-last-section", [])

#set page(
  numbering: "1",
  header: context [
    #let loc = here()
    #let text = ""
    #let first-heading = query(heading.where(level: 1)).find(h => h.location().page() == loc.page())
    #let last-heading  = query(heading.where(level: 1)).rev().find(h => h.location().page() == loc.page())

    #if not first-heading == none {
      ht-first.update([
        #counter(heading).at(first-heading.location()).at(0) #first-heading.body
      ])

      ht-last.update([
        #counter(heading).at(last-heading.location()).at(0) #last-heading.body
      ])

      // bei einer oder mehreren Überschriften auf der Seite: kein Header
      text = none
    } else {
      text = ht-last.get()
      // keine Überschrift auf der Seite, letzte Überschrift verwenden
    }

    #if text != none [
      #stack(
        spacing: 0.5em,
        if not isTwoSided or calc.even(loc.page()) {
          align(left)[#text]
        } else {
          align(right)[#text]
        },
        line(length: 100%, stroke: 0.5pt)
      )
    ] else []
  ]
)

#set text(size: 11pt)
#set par(justify: true)
#show heading.where(level: 1): set heading(supplement: [Kapitel])
#show heading.where(level: 2): set heading(supplement: [Abschnitt])
#show heading.where(level: 3): set heading(supplement: [Unterabschnitt])

#show figure.where(kind: image): set figure(supplement: [Abbildung])
#show figure.where(kind: table): set figure(supplement: [Tabelle])
#show figure.where(kind: raw): set figure(supplement: [Listing])

// Kapitelweise Nummerierung: <Kapitelnummer>.<laufende Nummer je Art>
#set figure(numbering: n => {
  let chapters = counter(heading).get()
  if chapters.len() > 0 {
    numbering("1.1", chapters.first(), n)
  } else {
    numbering("1", n)
  }
})

#set figure(gap: 1em)
#show figure.caption: c => [
  #text(weight: "bold")[
    #c.supplement #c.counter.display(c.numbering)
  ]
  #c.separator#c.body
]

#set heading(numbering: "1.1")
#show heading: it => [
  #set text(
    weight: if it.level == 1 {"bold"} else if it.level == 2 {"bold"} else {"semibold"},
    font: "Arial",
    size: if it.level == 1 {18pt} else if it.level == 2 {16pt} else {14pt}
  )
  
  #if it.level == 1 {
    // Zähler von Abbildungen, Tabellen und Listings je Kapitel zurücksetzen
    counter(figure.where(kind: image)).update(0)
    counter(figure.where(kind: table)).update(0)
    counter(figure.where(kind: raw)).update(0)
    pagebreak(weak: true, to: if isTwoSided { "odd" } else { none })
    v(2.5cm)
  } else if it.level == 3 {v(0.5em)}
  #block(it)
  #if it.level == 1 {v(0.75em)} else if it.level == 2 {v(0.5em)} else {v(0.25em)}
]

#include "content/01-Einleitung.typ"
#include "content/02-Grundlagen.typ"
#include "content/03-Analyse-und-Entwurf.typ"
#include "content/04-Implementierung.typ"
#include "content/05-Evaluation.typ"
#include "content/06-Fazit-und-Ausblick.typ"

#pagebreak(to: if isTwoSided { "odd" } else { none })
#bibliography("bibliography.bib", title: "Literaturverzeichnis", style: "ieee", full: false)
