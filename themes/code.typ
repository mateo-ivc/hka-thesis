// Code listings with syntax highlighting. The Sublime syntax and tmTheme files
// are located in this folder; paths are relative to themes/.

// ARM assembly listing with line numbers and custom syntax highlighting.
#let asm-code(code) = raw(
  code,
  lang: "armasm",
  block: true,
  syntaxes: "armasm.sublime-syntax",
  theme: "armasm.tmTheme",
)

#let listing-numbers(numbers) = block(
  inset: (
    top: 6pt,
    bottom: 6pt,
    left: 0pt,
    right: 0pt,
  ),
)[
  #text(
    fill: rgb("#6A737D"),
  )[
    #raw(
      numbers,
      block: true,
    )
  ]
]

#let asm-listing(numbers, code, width: 70%) = align(center)[
  #grid(
    columns: (1.6em, width),
    column-gutter: 0.8em,
    align: (right + top, left + top),

    listing-numbers(numbers),

    block(
      width: 100%,
      fill: rgb("#F8F9FB"),
      stroke: rgb("#D0D7DE"),
      radius: 4pt,
      inset: (
        top: 6pt,
        bottom: 6pt,
        left: 8pt,
        right: 8pt,
      ),
      breakable: true,
    )[
      #asm-code(code)
    ],
  )
]

// C listing with line numbers and custom syntax highlighting.
#let c-code(code) = raw(
  code,
  lang: "cthesis",
  block: true,
  syntaxes: "c-thesis.sublime-syntax",
  theme: "c-thesis.tmTheme",
)

#let c-listing-numbers(numbers) = block(
  inset: (
    top: 6pt,
    bottom: 6pt,
    left: 0pt,
    right: 0pt,
  ),
)[
  #text(
    fill: rgb("#6A737D"),
  )[
    #raw(
      numbers,
      block: true,
    )
  ]
]

#let c-listing(numbers, code, width: 70%) = align(center)[
  #grid(
    columns: (1.6em, width),
    column-gutter: 0.8em,
    align: (right + top, left + top),

    c-listing-numbers(numbers),

    block(
      width: 100%,
      fill: rgb("#F8F9FB"),
      stroke: rgb("#D0D7DE"),
      radius: 4pt,
      inset: (
        top: 6pt,
        bottom: 6pt,
        left: 8pt,
        right: 8pt,
      ),
      breakable: true,
    )[
      #c-code(code)
    ],
  )
]

// Diff-style listing: renders code line-by-line like a git diff. Lines are
// classified by their first character - "+" for additions (green), "-" for
// removals (red), everything else stays unchanged (a leading " " context
// marker, as in real diff output, is stripped if present). Only the marker
// itself is colored; the code stays with its normal syntax highlighting.
#let diff-line-style(kind) = if kind == "add" {
  (marker: "+", marker-fill: rgb("#1A7F37"))
} else if kind == "del" {
  (marker: "-", marker-fill: rgb("#CF222E"))
} else {
  (marker: " ", marker-fill: rgb("#6A737D"))
}

// The code (with its +/- markers stripped) is rendered as a single raw()
// block, and a `show raw.line` rule prepends the colored marker to each line
// - since this only adds inline content rather than a block, the line pitch
// stays exactly that of a plain raw block. That's what lets the numbers
// gutter (a separate, plain raw() block, same as in c-listing) stay aligned
// with it row for row.
#let diff-code(
  code,
  lang: "cthesis",
  syntaxes: "c-thesis.sublime-syntax",
  theme: "c-thesis.tmTheme",
) = {
  let lines = code.split("\n")
  if lines.len() > 0 and lines.last() == "" {
    lines = lines.slice(0, -1)
  }

  let parsed = lines.map(line => {
    if line.starts-with("+") {
      ("add", line.slice(1))
    } else if line.starts-with("-") {
      ("del", line.slice(1))
    } else if line.starts-with(" ") {
      ("same", line.slice(1))
    } else {
      ("same", line)
    }
  })
  let kinds = parsed.map(p => p.at(0))
  let stripped-code = parsed.map(p => p.at(1)).join("\n")

  show raw.line: line => {
    let kind = kinds.at(line.number - 1, default: "same")
    let style = diff-line-style(kind)
    [#box(width: 1em)[#text(fill: style.marker-fill, weight: "bold")[#style.marker]]#h(4pt)#line.body]
  }

  raw(stripped-code, block: true, lang: lang, syntaxes: syntaxes, theme: theme)
}

#let diff-listing(
  code,
  width: 70%,
  lang: "cthesis",
  syntaxes: "c-thesis.sublime-syntax",
  theme: "c-thesis.tmTheme",
) = {
  let line-count = code.split("\n").len()
  let line-count = if code.ends-with("\n") { line-count - 1 } else { line-count }
  let numbers = range(1, line-count + 1).map(str).join("\n")

  align(center)[
    #grid(
      columns: (1.6em, width),
      column-gutter: 0.8em,
      align: (right + top, left + top),

      c-listing-numbers(numbers),

      block(
        width: 100%,
        fill: rgb("#F8F9FB"),
        stroke: rgb("#D0D7DE"),
        radius: 4pt,
        inset: (
          top: 6pt,
          bottom: 6pt,
          left: 8pt,
          right: 8pt,
        ),
        breakable: true,
      )[
        #diff-code(code, lang: lang, syntaxes: syntaxes, theme: theme)
      ],
    )
  ]
}
