# Bakalářská práce — Procedurální generování dungeonů ve 2D hrách

**Autor:** Jesse Sadowý  
**Vedoucí:** doc. RNDr. Jan Konečný, Ph.D.  
**Univerzita:** Katedra informatiky, PřF UP v Olomouci, 2026

## Struktura projektu


- src/ - zdrojový kód (kompletní Godot projekt)
    - README.md - instrukce ke spuštění aplikace
    - results.csv - naměřené hodnoty
- text/ - text bakalářské práce (LaTeX, obrázky, PDF)
- README.md - tento soubor
- README.txt - txt verze Markdown souboru


### `src/`

Obsahuje kompletní projekt v herním enginu Godot 4.4, herními skripty, scény, grafické prostředky, naměřená data z benchmarků a vygenerované grafy. Podrobné instrukce pro spuštění aplikace a ovládání naleznete v `src/README.md`.

### `text/`

Obsahuje text bakalářské práce — zdrojový kód v LaTeXu, bibliografii, obrázky a styl `kidiplom.cls` potřebný pro sestavení PDF dokumentu.

## Spuštění projektu

**Možnost A – spustitelný soubor**

Ve složce `src/executables/` jsou předkompilované spustitelné soubory:
- **macOS** – otevřete `ProceduralGenerationProject_MacOS.dmg` a spusťte aplikaci.
- **Windows** – spusťte `ProceduralGenerationProject_WIN.exe`.

**Možnost B – Godot Engine**

Otevřete Godot Engine 4.4+, zvolte **Import** a vyberte soubor `src/proceduralgenerationproject/project.godot`.

Podrobnější instrukce a popis ovládání naleznete v `src/README.md`.
