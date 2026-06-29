# HKA-Thesis-Template (Typst)

Typst-Template für Abschlussarbeiten an der Hochschule Karlsruhe (HKA), optional in Kooperation mit einem Unternehmen.

## Voraussetzungen

- Typst ab Version 0.12: https://github.com/typst/typst (oder VS-Code-Erweiterung Tinymist)
- Schriften: Cambria, Arial, Liberation Sans (sonst werden Ersatzschriften genutzt)
- Internetverbindung beim ersten Build für die Pakete `acrostiche` und `outrageous`

## Verzeichnisstruktur

- `thesis.typ` - Einstiegspunkt: Reihenfolge, Verzeichnisse, Layout, Akronyme
- `config.toml` - Metadaten (Autor, Titel, Prüfer, Betreuer, Modi)
- `meta.typ` - liest config.toml und bündelt alle Helfer
- `typst.toml` - Paket-Manifest
- `bibliography.bib` - Beispiel-Literatur (ersetzen)
- `lib/` - Helfer: acronyms.typ, figures.typ, tables.typ
- `themes/` - Syntaxhervorhebung für C und ARM-Assembler
- `common/` - Titelseite (cover.typ) und Erklärungsseite (declaration.typ)
- `content/` - Zusammenfassung und 6 Kapitel mit Lorem-Ipsum-Platzhaltern
- `assets/` - hkalogo.svg, firmenlogo.svg, aufgabenstellung.svg

## Kompilieren

```powershell
typst compile thesis.typ   # erzeugt thesis.pdf
typst watch thesis.typ     # baut bei jeder Änderung neu
```

## Anpassen

1. Metadaten in `config.toml` setzen (`reviewer-two` und `advisor-two` leer lassen zum Ausblenden)
2. Logos in `assets/` ersetzen
3. Aufgabenstellung in `thesis.typ` eintragen oder den Block entfernen
4. Erklärungen in `common/declaration.typ` an die eigene KI-Nutzung anpassen
5. Kapitel in `content/` schreiben
6. Abkürzungen in `thesis.typ` in `init-acronyms` eintragen
7. Quellen in `bibliography.bib` pflegen und mit `@schluessel` zitieren

## Modi (config.toml)

- `isDraft`: DRAFT-Wasserzeichen und `#note`-Anmerkungen werden angezeigt
- `isTwoSided`: doppelseitiges Layout, Kapitel beginnen auf ungeraden Seiten

## Helfer

- `fig-platzhalter-klein/mittel/gross`: Grafik-Platzhalter
- `tab-h` / `tab-d`: Tabellenzellen für akademische Tabellen
- `c-listing` / `asm-listing`: Code mit Zeilennummern
- `req("FR-1")`: Querverweis auf Anforderung
- `acr-emph` / `acrpl-emph`: Akronym-Erstnennung; `acr-cap`: Kurzform für Beschriftungen
