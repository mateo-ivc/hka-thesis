// List of abbreviations and acronym helpers.
#import "@preview/acrostiche:0.7.0": _acronyms, _acrostiche-index, acr, acrpl, display-def, display-short, mark-acr-used

// First mention with italic long form in body text; long form stays upright in the list of abbreviations.
#let acr-emph(acronym, plural: false) = {
  context {
    let acronyms = _acronyms.get()
    if acronym not in acronyms {
      panic("Cannot reference an undefined acronym: " + acronym)
    }
    let already-used = acronyms.at(acronym).at(1)
    if already-used {
      acr(acronym, plural: plural)
    } else {
      [#emph(display-def(acronym, plural: plural)) (#display-short(acronym, plural: plural))]
      mark-acr-used(acronym)
    }
  }
}

#let acrpl-emph(acronym) = acr-emph(acronym, plural: true)

// Short form only, without first-use expansion and without marking as "used".
// For figure, table, and listing captions so that the first mention
// remains in body text (lists are evaluated before the main text).
#let acr-cap(acronym, plural: false) = {
  context {
    let acronyms = _acronyms.get()
    if acronym not in acronyms {
      panic("Cannot reference an undefined acronym: " + acronym)
    }
    let short = display-short(acronym, plural: plural)
    if _acrostiche-index.final() {
      link(label("acrostiche-" + acronym), short)
    } else {
      short
    }
  }
}

#let acrpl-cap(acronym) = acr-cap(acronym, plural: true)

// Additional case forms for German plural endings (e.g. dative: Steuergeräten).
// Example: add your own acronyms with non-standard dative plural here.
#let acr-case-forms = (
  "ECU": (
    long-pl-dat: "Steuergeräten",
    short-pl-dat: "Steuergeräten",
  ),
)

#let acrpl-dat(acronym) = {
  context {
    if acronym not in acr-case-forms {
      panic("No dative plural form defined for acronym: " + acronym)
    }
    let acronyms = _acronyms.get()
    if acronym not in acronyms {
      panic("Cannot reference an undefined acronym: " + acronym)
    }
    let forms = acr-case-forms.at(acronym)
    let already-used = acronyms.at(acronym).at(1)
    if already-used {
      forms.short-pl-dat
    } else {
      [#forms.long-pl-dat (#display-short(acronym, plural: true))]
    }
  }
  mark-acr-used(acronym)
}

#let acrpl-dat-emph(acronym) = {
  context {
    if acronym not in acr-case-forms {
      panic("No dative plural form defined for acronym: " + acronym)
    }
    let acronyms = _acronyms.get()
    if acronym not in acronyms {
      panic("Cannot reference an undefined acronym: " + acronym)
    }
    let forms = acr-case-forms.at(acronym)
    let already-used = acronyms.at(acronym).at(1)
    if already-used {
      forms.short-pl-dat
    } else {
      [#emph(forms.long-pl-dat) (#display-short(acronym, plural: true))]
    }
  }
  mark-acr-used(acronym)
}

// List of abbreviations with optional custom short form in the index column
// (e.g. "E/E" instead of "E/E-Architektur", while body text stays unchanged).
#let print-abk-verzeichnis(
  index-short: (:),
  title: "",
  sorted: "up",
  case-sensitive: true,
  delimiter: ":",
  row-gutter: 0.5em,
  used-only: true,
  column-ratio: 0.3,
  clickable: true,
) = {
  assert(sorted in (none, "up", "down"))
  assert(column-ratio >= 0)

  context {
    let acr-list = if used-only {
      _acronyms.final().pairs().filter(((_, state)) => state.at(2)).map(((acr, _)) => acr)
    } else {
      _acronyms.get().keys()
    }

    let sort-key = if case-sensitive { x => x } else { lower }
    if sorted == "down" {
      acr-list = acr-list.sorted(key: sort-key).rev()
    } else if sorted == "up" {
      acr-list = acr-list.sorted(key: sort-key)
    }

    let col1 = column-ratio / (1 + column-ratio)
    let col2 = 1 - col1
    grid(
      columns: (col1 * 100%, col2 * 100%),
      row-gutter: row-gutter,
      ..for acr in acr-list {
        let short-text = if acr in index-short {
          index-short.at(acr)
        } else {
          display-short(acr, plural: false)
        }
        let short = [*#short-text#delimiter*]
        if clickable and (not _acrostiche-index.get()) {
          short = [#short#label("acrostiche-" + acr)]
        }
        (short, display-def(acr, plural: false))
      },
    )
    if clickable {
      _acrostiche-index.update(true)
    }
  }
}
