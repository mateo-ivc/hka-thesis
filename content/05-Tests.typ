= Tests

*Tests*:
//https://www2.informatik.uni-stuttgart.de/bibliothek/ftp/ncstrl.ustuttgart_fi/TR-2021-02/TR-2021-02.pdf
- Testaufbau wo die Clock mehrere Stunden läuft -> Um eine Langzeitstabilität analysieren zukönnen.
  - gemessen wird: PPS-Signal üebr 6H, es werden logs aufgezeichnet, dabei wird der

- Simulierte Systemlast -> Um zu zeigen, dass die Synchronisierung auch unter Last funktioniert.
  - Ein task der ständig etwas berechnet und somit die CPU last hochzieht.
  - Die Clocks sollten weiterhin Synchron bleiben, da Zephyr die Tasks geschickt scheduled

- Simulierte Netzwerklast -> Um zu zeigen, dass die Synchronisierung auch unter Netzwerklast funktioniert.
  - Große Datei hin und her senden um so eine möglichst hohe last auf das Netzwerk zu generieren.
  -

- Auseinanderlaufen von Clocks zeigen durch Zeitsynchronisierung (keine Syntonisierung)

== Basis PPS-Messung


