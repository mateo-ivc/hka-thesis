# HKA-Thesis-Template (Typst)

Typst template for bachelor/master theses at Hochschule Karlsruhe (HKA) in the field of embedded software engineering, optionally in cooperation with a company.

## Requirements

- Typst version 0.12 or later: https://github.com/typst/typst (or the VS Code extension Tinymist)
- Fonts: Cambria, Arial, Liberation Sans (fallback fonts are used if unavailable)
- Internet connection on first build to download the `acrostiche` and `outrageous` packages

## Directory structure

- `thesis.typ` - entry point: chapter order, lists, layout, acronyms
- `config.toml` - metadata (author, title, reviewers, advisors, modes)
- `meta.typ` - reads config.toml and bundles all helpers
- `typst.toml` - package manifest
- `bibliography.bib` - example bibliography (replace with your own)
- `lib/` - helpers: acronyms.typ, figures.typ, tables.typ
- `themes/` - syntax highlighting for C and ARM assembly
- `common/` - cover page (cover.typ) and declarations (declaration.typ)
- `content/` - abstract and 6 chapters with Lorem Ipsum placeholders
- `assets/` - hkalogo.svg, firmenlogo.svg, aufgabenstellung.svg

## Building

```powershell
typst compile thesis.typ   # produces thesis.pdf
typst watch thesis.typ     # rebuilds on every change
```

## Customization

1. Set metadata in `config.toml` (leave `reviewer-two` and `advisor-two` empty to hide them)
2. Replace logos in `assets/`
3. Add your task assignment in `thesis.typ` or remove that block entirely
4. Fill in `common/declaration.typ` with your actual AI usage and acknowledgements
5. Write your chapters in `content/`
6. Register acronyms in `thesis.typ` via `init-acronyms`
7. Add sources to `bibliography.bib` and cite with `@key`

## Modes (config.toml)

- `isDraft`: shows DRAFT watermark and `#note` annotations
- `isTwoSided`: two-sided layout, chapters start on odd pages

## Helpers

- `fig-platzhalter-klein/mittel/gross`: figure placeholders
- `tab-h` / `tab-d`: table cells for academic tables
- `c-listing` / `asm-listing`: code with line numbers
- `req("FR-1")`: cross-reference to a requirement
- `acr-emph` / `acrpl-emph`: acronym first mention; `acr-cap`: short form for captions
