// Aggregator module: metadata (from config.toml) + all helpers.
// Content files should only import from this file.

#import "lib/acronyms.typ": *
#import "lib/captions.typ": *
#import "lib/figures.typ": *
#import "lib/tables.typ": *
#import "themes/code.typ": *

// Read metadata centrally from config.toml.
#let _cfg = toml("config.toml")
#let _opt(value) = if value == none or value == "" { none } else { value }

#let isDraft = _cfg.is-draft
#let isTwoSided = _cfg.is-two-sided
#let author = _cfg.author
#let title = _cfg.title
#let thesisType = _cfg.thesis-type
#let keywords = _cfg.keywords

#let reviewerOne = _cfg.reviewer-one
#let reviewerTwo = _opt(_cfg.reviewer-two)
#let advisorOne = _cfg.advisor-one
#let advisorTwo = _opt(_cfg.advisor-two)

#let department = _cfg.department
#let institute = _cfg.institute
#let university = _cfg.university
#let company = _cfg.company

#let statutoryDeclarationPlaceAndDate = _cfg.statutory-declaration-place-and-date
#let completionPeriod = _cfg.completion-period

// Note box (only visible in draft mode).
#let note(body) = if isDraft {
  block(
    fill: yellow.lighten(60%),
    stroke: 1pt + orange,
    inset: 8pt,
    radius: 4pt,
    width: 100%,
  )[*Anmerkung:* #body]
}

// --- One-sided / two-sided layout ------------------------------------------

// Page margins with a binding offset (gutter) for two-sided printing.
// The total horizontal margin (inside + outside) stays the same as for
// single-sided printing (2 * pageMargin); the binding offset is merely shifted
// from the outer to the inner margin. Odd (right-hand) pages move right and
// even (left-hand) pages move left, without changing the text block width.
#let pageMargin = 30mm
#let bindingOffset = 10mm
#let bodyMargin = if isTwoSided {
  (inside: pageMargin + bindingOffset / 2, outside: pageMargin - bindingOffset / 2, y: pageMargin)
} else {
  pageMargin
}

// Page break to the next right-hand (odd) page. In two-sided mode Typst inserts
// a blank page if needed; such blank (verso) pages are rendered without a header
// and without a page number (see is-blank-page below).
#let openright(weak: false) = pagebreak(weak: weak, to: if isTwoSided { "odd" } else { none })

// Marker used to tell content pages apart from inserted blank pages. Every page
// with visible body text carries at least one such marker; an inserted blank
// page carries none.
#let content-marker = [#metadata(none)#label("content-marker")]

// Reports (read-only, therefore stable) whether the current page is an inserted
// blank page: no body-text marker, no heading, no figure/table and no outline
// entry lie on it.
#let is-blank-page() = {
  let p = here().page()
  let on-page(el) = el.location().page() == p
  let has-marker = query(label("content-marker")).any(on-page)
  let has-heading = query(heading).any(on-page)
  let has-figure = query(figure).any(on-page)
  let has-entry = query(outline.entry).any(on-page)
  not has-marker and not has-heading and not has-figure and not has-entry
}

// Footer with a page number that is suppressed on inserted blank pages.
#let page-footer(pattern) = context {
  if not is-blank-page() {
    align(center)[#numbering(pattern, ..counter(page).at(here()))]
  }
}
