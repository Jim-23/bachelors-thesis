Bakalářská práce — Procedurální generování dungeonů ve 2D hrách

Autor: Jesse Sadowý
Vedoucí: doc. RNDr. Jan Konečný, Ph.D.
Univerzita: Katedra informatiky, PřF UP v Olomouci, 2026

Struktura projektu:

    src/            — zdrojový kód (kompletní Godot projekt)
    src/results.csv - naměřené výsledky
    src/README.md   — instrukce ke spuštění projektu
    text/           — text bakalářské práce (LaTeX, PDF)
    README.txt      — tento soubor
    README.md       — Markdown verze txt soubor

src/
----
Obsahuje kompletní projekt v herním enginu Godot 4.4, herními skripty,
scény, grafické prostředky, naměřená data z benchmarků a vygenerované
grafy. Podrobné instrukce pro spuštění aplikace a ovládání naleznete
v src/README.md.

text/
-----
Obsahuje text bakalářské práce — zdrojový kód v LaTeXu, bibliografii,
obrázky a styl kidiplom.cls potřebný pro sestavení PDF dokumentu.

Spuštění projektu
-----------------
Možnost A – spustitelný soubor:
  macOS   — otevřete src/executables/ProceduralGenerationProject_MacOS.dmg
  Windows — spusťte src/executables/ProceduralGenerationProject_WIN.exe

Možnost B – Godot Engine 4.4+:
  Otevřete Godot Engine, zvolte Import a vyberte
  src/proceduralgenerationproject/project.godot

Podrobnější instrukce a popis ovládání viz src/README.md.
