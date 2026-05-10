# BP - Procedurální generování dungeonů ve 2D hrách

**Autor:** Jesse Sadowý  
**Vedoucí:** doc. RNDr. Jan Konečný, Ph.D.  
**Univerzita:** Katedra informatiky, PřF UP v Olomouci, 2026

## Implementované algoritmy

- **Rooms** - náhodné umístění místností a propojení chodbami
- **BSP** - Binary Space Partitioning (rekurzivní dělení prostoru)
- **Drunken Walk** - náhodná procházka s cílovým pokrytím 50 %
- **Cellular** - buněčné automaty (jeskynní struktury)
- **Maze** - generování bludiště (recursive backtracker / DFS)

## Požadavky

- [Godot Engine 4.6.X](https://godotengine.org/download/) (volitelné, pouze pokud nechcete využít připravený spustitelný soubor)
- Python 3.10+ (volitelné, pouze pro analýzu výsledků)

## Spuštění aplikace

### Možnost A – spustitelný soubor (doporučeno)

Ve složce `executables/` jsou připraveny předkompilované spustitelné soubory:

- **macOS** – otevřete `ProceduralGenerationProject_MacOS.dmg` a spusťte aplikaci.
- **Windows** – spusťte `ProceduralGenerationProject_WIN.exe`.

> **Poznámka:** Výsledky benchmarku (`results.csv`) se uloží do systémové složky aplikace:
> - **macOS:** `~/Library/Application Support/Godot/app_userdata/<název projektu>/results.csv`
> - **Windows:** `C:\Users\<uživatel>\AppData\Roaming\Godot\app_userdata\<název projektu>\results.csv`
>
> Přesná cesta se zobrazí ve statusovém řádku po dokončení benchmarku.

### Možnost B – spuštění v Godot Engine

1. Stáhněte nebo naklonujte repozitář:
   ```
   git clone https://github.com/Jim-23/ProceduralGenerationBP.git
   ```
2. Otevřete Godot Engine a zvolte **Import** → vyberte soubor `project.godot` ve složce `proceduralgenerationproject/`.
3. Spusťte projekt.

## Ovládání

- **W A S D** - pohyb hráče
- **Kolečko myši** - přiblížení / oddálení
- **Pravé tlačítko myši** - pohybování po mapě nezávisle na hráči
- **R** nebo klávesy pro pohyb hráře - focus zpět na hráče
- **Generate** - vygeneruje mapu na základě zvoleného algoritmu a rozměrů
- **Benchmark** - spustí automatizované měření všech algoritmů na pěti velikostech map (každou kombinaci 10x, výsledky se uloží do `results.csv`) - počet průchodů lze nastavit
- **Seed** a checkbox - lze nastavit vlastní číselný seed pro reprodukovatelnsot výsledků, musí se zaškrnout checkbox, aby byl seed aplikován


## Analýza výsledků

Po spuštění benchmarku lze vygenerovat grafy pomocí skriptu `result_analyser.py`:

```
pip install -r requirements.txt
python result_analyser.py
```

Grafy budou uloženy do složky `plots/`.

## Struktura projektu

```
dungeons/algorithms/   - generovací algoritmy
scripts/               - herní logika (main, player, coin, camera_2D)
scenes/                - Godot scény
assets/                - grafické prostředky pro hru
plots/                 - grafy z analyzátoru
result_analyser.py     - Python skript pro analýzu dat
results.csv            - naměřená data z benchmarku
result_summary.csv     - zpracovaná data, pokud byl spuštěn result_analyser.py
requirements.txt       - Požadované knihovny pro spuštění skriptu result_analyser.py
```
