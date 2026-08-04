#import "../meta.typ": (
  acr-emph, acrpl-emph, fig-platzhalter-gross, fig-platzhalter-klein, fig-platzhalter-mittel, note, openright, tab-d,
  tab-h,
)
#import "@preview/acrostiche:0.7.0": acr, acrpl

#[
  #v(1.5cm)
  #set text(
    font: "Arial",
    size: 18pt,
  )
  = Zusammenfassung
  #v(0.75em)
]

Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Ein Beispiel-Akronym bei Erstnennung: #acr-emph("ECU"), danach kurz: #acr("ECU").

Duis autem vel eum iriure dolor in hendrerit in vulputate velit esse molestie consequat, vel illum dolore eu feugiat nulla facilisis at vero eros et accumsan et iusto odio dignissim qui blandit praesent luptatum zzril delenit augue duis dolore te feugait nulla facilisi. Diese Zusammenfassung fasst Motivation, Ziel, Vorgehen und Ergebnis der Arbeit in wenigen Absätzen zusammen.

#openright()

#[
  #v(1.5cm)
  #set text(
    font: "Arial",
    size: 18pt,
  )
  = Abstract
  #v(0.75em)
]

Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. This is the English counterpart of the German summary. Replace it with a concise abstract that states problem, approach, and result.

At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. The abstract should be understandable without reading the full thesis.
