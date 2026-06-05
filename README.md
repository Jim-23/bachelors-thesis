# Bachelor's Thesis — Procedural Dungeon Generation in 2D Games

**Author:** Jesse Sadowý  
**Supervisor:** Jan Konečný, Ph.D.  
**University:** Department of Computer Science, Faculty of Science, Palacký University Olomouc, 2026

## Project Structure

- `src/` - source code (complete Godot project)
  - `README.md` - application setup and usage instructions
  - `results.csv` - benchmark results
- `text/` - thesis source files (LaTeX, figures, PDF)
- `README.md` - this file
- `README.txt` - plain text version of this README

### `src/`

Contains the complete Godot 4.4 project, including game scripts, scenes, graphical assets, benchmark data, and generated plots. Detailed instructions for running the application and using its features can be found in `src/README.md`.

### `text/`

Contains the bachelor's thesis source files, including the LaTeX document, bibliography, figures, and the `kidiplom.cls` class file required to build the final PDF.

## Running the Project

### Option A – Prebuilt Executables

Precompiled executables are available in the `src/executables/` directory:

- **macOS** – open `ProceduralGenerationProject_MacOS.dmg` and launch the application.
- **Windows** – run `ProceduralGenerationProject_WIN.exe`.

### Option B – Godot Engine

- Open Godot Engine 4.4 or newer, select **Import**, and choose the file:
`src/proceduralgenerationproject/project.godot`
- For detailed setup instructions and a complete description of the controls, see `src/README.md`.


---


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

- Otevřete Godot Engine 4.4+, zvolte **Import** a vyberte soubor `src/proceduralgenerationproject/project.godot`.
- Podrobnější instrukce a popis ovládání naleznete v `src/README.md`.
