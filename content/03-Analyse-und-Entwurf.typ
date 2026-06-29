#import "../meta.typ": note, fig-platzhalter-mittel, tab-h, tab-d, req, acr-emph
#import "@preview/acrostiche:0.7.0": acr, acrpl

= Analyse und Entwurf

Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat.

== Analyse der Anforderungen

Aus der Problemstellung werden die Anforderungen abgeleitet. Verweise erfolgen über #req("FR-1").

#figure(
  table(
    columns: (1fr, 5fr),
    tab-h[ID], tab-h[Anforderung],
    table.cell(inset: (x: 6pt, y: 4pt))[FR-1 #label("fr-1")], tab-d[Lorem ipsum dolor sit amet, consetetur sadipscing elitr.],
    table.cell(inset: (x: 6pt, y: 4pt))[FR-2 #label("fr-2")], tab-d[Sed diam nonumy eirmod tempor invidunt ut labore.],
  ),
  caption: [Funktionale Anforderungen],
) <tab:anforderungen>

== Entwurf der Lösung

At vero eos et accusam et justo duo dolores et ea rebum. Beschreiben Sie hier Architektur und Konzepte der Lösung.
