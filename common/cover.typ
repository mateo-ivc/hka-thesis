#import "../meta.typ": *

#set page(
  margin: if isTwoSided {
    (inside: 30pt + bindingOffset / 2, outside: 30pt - bindingOffset / 2, y: 30pt)
  } else {
    30pt
  },
)

#rect(
  width: 100%,
  height: 95%,
  radius: (
    top-right: 15pt,
    bottom-left: 15pt,
  ), 
  stroke: rgb("#ffffff") + 1pt,
  inset: 1cm, [
    #grid(
      columns: (1fr, 1fr),
      rows: (auto),
      align: (left + horizon, right + horizon),
      [#image("../assets/hkalogo.svg", width: 180pt)],
      [#image("../assets/inovex_logo.svg", width: 120pt)],
    )

    #pad(top: 75pt)[
      #align(center)[
        #block(width: 75%)[
          #text(font: "Liberation Sans", weight: "bold", size: 24pt)[#title]
        ]
      ]
    ]

    #pad(top: 45pt)[
      #align(center)[
        #block(width: 50%)[
            #text(size: 14pt)[#thesisType #linebreak() von]
          ]
      ]
    ]

    #pad(top: 5pt)[
      #align(center)[
        #text(font: "Liberation Sans", weight: "bold", size: 18pt)[#author]
      ]
    ]

    #pad(top: 60pt)[
      #align(center)[
        #text(size: 14pt)[
          An der #university #linebreak()
          #institute #linebreak()
          In Kooperation mit #company
        ]
      ]
    ]

    #pad(top: 30pt)[
      #align(center,
        [#grid(
          columns: (auto, auto),
          rows: (auto),
          align: (left, left),
          column-gutter: 1em,
          row-gutter: 1em,
          [#text(size: 14pt)[Erstprüfer:]],
          [#text(size: 14pt)[#reviewerOne]],

          { if reviewerTwo != none [#text(size: 14pt)[Zweitprüfer:]] },
          { if reviewerTwo != none [#text(size: 14pt)[#reviewerTwo]] },

          grid.cell(colspan: 2, v(0em)),

          {if advisorTwo == none [#text(size: 14pt)[Betreuer:]] else [#text(size: 14pt)[Erster Betreuer:]]},
          [#text(size: 14pt)[#advisorOne]],

          { if advisorTwo != none [#text(size: 14pt)[Zweiter Betreuer:]] },
          { if advisorTwo != none [#text(size: 14pt)[#advisorTwo]] },
        )]
      )
    ]
    #pad(top: 40pt)[
      #align(center)[
        #grid(
          columns: (auto),
          rows: (auto),
          align: (center),
          text(size: 12pt)[#completionPeriod],
        )
      ]
    ]
  ]
)
