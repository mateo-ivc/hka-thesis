// Grafik-Platzhalter (ersetzen später durch #figure(image(...), ...))
// Nutzung: #fig-platzhalter-mittel(caption: [Kurztext], label: <meine-abb>)[Was die Grafik zeigen soll]

#let _fig-platzhalter-box(width, height, body) = box(
  width: width,
  height: height,
  fill: luma(245),
  stroke: (thickness: 0.75pt, paint: luma(175), dash: "dashed"),
  inset: 12pt,
  radius: 3pt,
)[
  #align(center + horizon)[
    #stack(spacing: 0.65em)[
      #text(size: 8pt, fill: luma(120), style: "italic")[Grafik folgt, Inhalt unten beschreiben]
      #par(justify: false, leading: 0.45em)[
        #text(size: 10pt)[#body]
      ]
    ]
  ]
]

#let _fig-platzhalter(
  width,
  height,
  body,
  caption: none,
  label: none,
) = {
  let fig = figure(
    _fig-platzhalter-box(width, height, body),
    caption: caption,
    kind: image,
    supplement: [Abbildung],
  )
  if label != none {
    [#fig#label]
  } else {
    fig
  }
}

#let fig-platzhalter-klein(body, caption: none, label: none) = _fig-platzhalter(
  50%,
  3.5cm,
  body,
  caption: caption,
  label: label,
)

#let fig-platzhalter-mittel(body, caption: none, label: none) = _fig-platzhalter(
  80%,
  5.5cm,
  body,
  caption: caption,
  label: label,
)

#let fig-platzhalter-gross(body, caption: none, label: none) = _fig-platzhalter(
  100%,
  8.5cm,
  body,
  caption: caption,
  label: label,
)
