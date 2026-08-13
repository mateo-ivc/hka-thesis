// Glossary of domain-specific terms (as opposed to the list of abbreviations,
// which only covers acronyms). Mirrors the abbreviation list's grid layout
// and "used-only" filtering, but instead of expanding short/long forms it
// links each in-text mention directly to its definition on the glossary page.

#let _glossary-terms = state("glossary-terms", (:))
#let _glossary-used = state("glossary-used", (:))

// terms: dictionary of key -> (display name, definition content)
#let init-glossary(terms) = {
  _glossary-terms.update(terms)
}

// Marks a term as used and links the shown text to its glossary entry, e.g.
// #gls("pdelay")[pDelay-Nachrichten]. body is positional (not a named
// parameter) so it can be passed via the trailing #gls(..)[..] bracket
// syntax. Label targets resolve globally in Typst, so this works regardless
// of whether the glossary page or the in-text mention comes first in the
// document.
#let gls(key, body) = context {
  let terms = _glossary-terms.get()
  if key not in terms {
    panic("Cannot reference an undefined glossary term: " + key)
  }
  _glossary-used.update(u => {
    u.insert(key, true)
    u
  })
  link(label("gls-" + key))[#body]
}

#let print-glossary(
  sorted: "up",
  case-sensitive: true,
  row-gutter: 0.5em,
  column-ratio: 0.5,
  used-only: true,
) = {
  assert(sorted in (none, "up", "down"))
  assert(column-ratio >= 0)

  context {
    let terms = _glossary-terms.get()
    let keys = if used-only {
      _glossary-used.final().keys()
    } else {
      terms.keys()
    }

    let sort-key = if case-sensitive { name => name } else { lower }
    if sorted == "down" {
      keys = keys.sorted(key: k => sort-key(terms.at(k).at(0))).rev()
    } else if sorted == "up" {
      keys = keys.sorted(key: k => sort-key(terms.at(k).at(0)))
    }

    let col1 = column-ratio
    let col2 = 1 - col1
    grid(
      columns: (col1 * 100%, col2 * 100%),
      row-gutter: row-gutter,
      ..for k in keys {
        let entry = terms.at(k)
        ([*#entry.at(0)*#label("gls-" + k)], entry.at(1))
      },
    )
  }
}
