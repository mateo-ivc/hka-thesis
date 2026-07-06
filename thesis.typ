#import "@preview/outrageous:0.4.0"
#import "@preview/acrostiche:0.7.0": *
#import "meta.typ": *

#set document(title: title, author: author, keywords: keywords)

// Document language (also drives smart quotes „…" and correct German
// hyphenation patterns for justified paragraphs, see #set par(justify: true)
// below). Without this, Typst falls back to English hyphenation rules,
// which is the generic cause of incorrect line breaks throughout the text.
#set text(lang: "de", region: "DE")

// Acronyms (first use = long form + abbreviation, afterwards abbreviation only)
// Examples: replace or extend with your own acronyms.
#init-acronyms((
  "ECU": ("Steuergerät", "Steuergeräte"),
  "CAN": ("Controller Area Network",),
  "API": ("Application Programming Interface",),
))

// Short forms only in the list of abbreviations (body text stays with short/short-pl)
#let abk-index-short = (:)

#set text(font: "Cambria")

// Place an invisible marker on every page that carries body text, so that
// inserted blank (verso) pages can be told apart reliably (see is-blank-page).
// The marker sits at the end of each paragraph, i.e. on the page where the
// paragraph actually ends (not in the leftover space of the previous page).
#show par: it => it + content-marker

#set page("a4",
  background: if isDraft { rotate(24deg, text(150pt, fill: rgb("dedede66"))[*DRAFT*]) },
)

// First page: task assignment (placeholder). For multi-page PDFs add further
// #image(...) with page: 2, page: 3 ... or remove this block entirely.
#[
  #set page("a4", margin: 0pt, background: none)
  #image("assets/aufgabenstellung.svg", width: 100%, height: 100%)
]

#openright()

#set page("a4", margin: bodyMargin)
#set text(size: 12pt)

// Declaration of independence and AI usage
#include "common/declaration.typ"
#openright()

// Cover page
#include "common/cover.typ"
#openright()

// Start page numbering
#set page(numbering: "i", margin: bodyMargin, footer: page-footer("i"))
#counter(page).update(1)

#set par(justify: true)

// Abstract
#include "content/00-abstract.typ"
#openright()

// Table of contents
#show outline.entry: outrageous.show-entry.with(
  ..outrageous.presets.outrageous-toc,
  fill: (none, line(length: 100%, stroke: (thickness: 1pt, dash: "loosely-dotted"))),
)

#text(size: 21pt, font: "Arial")[*Inhaltsverzeichnis*]
#v(20pt)

#outline(title: none, indent: auto)
#openright()

// List of figures
#show outline.entry: outrageous.show-entry.with(
  ..outrageous.presets.outrageous-figures,
)

#text(size: 21pt)[*Abbildungsverzeichnis*]
#v(0pt)

#outline(title: "", target: figure.where(kind: image))

#v(40pt)

// List of tables and listings
#text(size: 21pt)[*Tabellenverzeichnis*]
#v(0pt)

#outline(title: "", target: figure.where(kind: table))

#v(40pt)

#text(size: 21pt)[*Listingverzeichnis*]
#v(0pt)

#outline(title: "", target: figure.where(kind: raw))

#openright()

// List of abbreviations (own page, after list of tables and listings)
#text(size: 21pt)[*Abkürzungsverzeichnis*]
#v(0pt)

#print-abk-verzeichnis(index-short: abk-index-short)

#openright()

// Start of main body

#let ht-first = state("page-first-section", [])
#let ht-last  = state("page-last-section", [])

#set page(
  numbering: "1",
  footer: page-footer("1"),
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

      // one or more headings on this page: no header
      text = none
    } else {
      text = ht-last.get()
      // no heading on this page, use last heading
    }

    #if text != none and not is-blank-page() [
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

// Per-chapter numbering: <chapter number>.<running number per type>
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
    // Reset figure, table and listing counters per chapter
    counter(figure.where(kind: image)).update(0)
    counter(figure.where(kind: table)).update(0)
    counter(figure.where(kind: raw)).update(0)
    openright(weak: true)
    v(2.5cm)
  } else if it.level == 3 {v(0.5em)}
  #block(it)
  #if it.level == 1 {v(0.75em)} else if it.level == 2 {v(0.5em)} else {v(0.25em)}
]

#include "content/01-introduction.typ"
#include "content/02-foundations.typ"
#include "content/03-analysis-and-design.typ"
#include "content/04-implementation.typ"
#include "content/05-Evaluation.typ"
#include "content/06-conclusion-and-outlook.typ"

#openright()
// In the bibliography the entries are neither body-text paragraphs (with a
// content-marker) nor headings/figures/outline entries. Therefore is-blank-page()
// would wrongly treat the follow-up pages as blank pages and suppress the page
// number as well as the header. That is why the bibliography uses its own
// header/footer:
//  - a page number on every page of the bibliography,
//  - a "Literaturverzeichnis" header on every page except the first, and
//    without a leading chapter number.
// Comparing against the page of the (last) level-1 heading — which is the
// bibliography heading — also excludes any blank page inserted beforehand from
// the page number and header.

#set page(
  footer: context {
    let loc = here()
    let bib-heading = query(heading.where(level: 1)).last()
    if bib-heading != none and bib-heading.location().page() <= loc.page() {
      align(center)[#numbering("1", ..counter(page).at(loc))]
    }
  },
  header: context {
    let loc = here()
    let bib-heading = query(heading.where(level: 1)).last()
    if bib-heading != none and bib-heading.location().page() < loc.page() {
      stack(
        spacing: 0.5em,
        if not isTwoSided or calc.even(loc.page()) {
          align(left)[Literaturverzeichnis]
        } else {
          align(right)[Literaturverzeichnis]
        },
        line(length: 100%, stroke: 0.5pt),
      )
    }
  },
)
// Do not break a single source across page boundaries: each source lives in a
// grid cell; set as a non-breakable block, an entry moves to the next page as a
// whole instead of being split.
#show bibliography: it => {
  show grid.cell: cell => block(breakable: false, cell)
  it
}
#bibliography("bibliography.bib", title: "Literaturverzeichnis", style: "ieee", full: false)
