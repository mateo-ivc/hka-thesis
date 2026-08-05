// Long/short captions: figures and tables often want a citation or other
// detail in the caption next to the figure, but that detail is unwanted
// clutter in the list of figures/tables/listings. Wrap the part that should
// be dropped there in #cap-long-only[...]; wrap the whole list of X block
// in #short-captions[...] so that content is hidden inside it.
//
// Usage:
//   caption: [Vergleich NTP, PTPv2 und gPTP#cap-long-only[ @ieee8021as2025[8.5]]]
//   -> shown at the figure:   Vergleich NTP, PTPv2 und gPTP @ieee8021as2025[8.5]
//   -> shown in the list:     Vergleich NTP, PTPv2 und gPTP

#let _in-caption-list = state("in-caption-list", false)

#let cap-long-only(body) = context if not _in-caption-list.get() { body }

#let short-captions(body) = {
  _in-caption-list.update(true)
  body
  _in-caption-list.update(false)
}
