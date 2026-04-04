import pandas as pd
import matplotlib.pyplot as plt
import os

# ── Load and clean data ──────────────────────────────────────────────

df = pd.read_csv("results.csv")

# convert columns to numbers (invalid values become NaN)
df["run"] = pd.to_numeric(df["run"], errors="coerce")
df["gen_time_ms"] = pd.to_numeric(df["gen_time_ms"], errors="coerce")
df["coverage"] = pd.to_numeric(df["coverage"], errors="coerce")

# only keep valid runs (0 to 9)
df = df[df["run"].between(0, 9)].copy()

# add helper columns
df["cells"] = df["width"] * df["height"]
df["size"] = df["width"].astype(str) + "x" + df["height"].astype(str)

# get unique values for looping
algorithms = sorted(df["algorithm"].unique())
sizes = sorted(df["size"].unique(), key=lambda s: int(s.split("x")[0]) * int(s.split("x")[1]))

# ── Summary statistics ───────────────────────────────────────────────

summary = df.groupby(["algorithm", "size", "cells"]).agg(
    n=("gen_time_ms", "count"),
    time_mean=("gen_time_ms", "mean"),
    time_std=("gen_time_ms", "std"),
    time_min=("gen_time_ms", "min"),
    time_max=("gen_time_ms", "max"),
    coverage_mean=("coverage", "mean"),
    coverage_std=("coverage", "std"),
    coverage_min=("coverage", "min"),
    coverage_max=("coverage", "max"),
).reset_index()

summary = summary.sort_values(["algorithm", "cells"])
summary.to_csv("results_summary.csv", index=False)
print("Saved results_summary.csv")

# ── Output folder ────────────────────────────────────────────────────

os.makedirs("plots", exist_ok=True)


# ── Helper function for saving ───────────────────────────────────────

def save(name):
    path = os.path.join("plots", name)
    plt.tight_layout()
    plt.savefig(path, dpi=200)
    plt.close()
    print(f"  Saved {path}")


def annotate_bars(fmt="{:.1f}", yerr=None):
    """Add value labels on top of bar chart bars, above error bars if given."""
    ax = plt.gca()
    if yerr is not None:
        yerr_vals = yerr.values if hasattr(yerr, "values") else list(yerr)
    for i, bar in enumerate(ax.patches):
        h = bar.get_height()
        top = h + (yerr_vals[i] if yerr is not None and i < len(yerr_vals) else 0)
        ax.text(bar.get_x() + bar.get_width() / 2, top, fmt.format(h),
                ha="center", va="bottom", fontsize=8)


# =====================================================================
# COMPARISON GRAPHS (all algorithms together)
# =====================================================================

print("\nGenerating comparison graphs...")

# 1) Bar chart - average generation time per algorithm (overall)
avg_time = df.groupby("algorithm")["gen_time_ms"].mean().reindex(algorithms)
plt.figure(figsize=(8, 5))
plt.bar(algorithms, avg_time, color=["#4C72B0", "#DD8452", "#55A868", "#C44E52", "#8172B3"])
annotate_bars()
plt.xlabel("Algorithm")
plt.ylabel("Average generation time [ms]")
plt.title("Average Generation Time - All Algorithms\n(across all map sizes, 10 runs each)")
save("comparison_avg_time.png")

# 2) Bar chart - average coverage per algorithm (overall)
avg_cov = df.groupby("algorithm")["coverage"].mean().reindex(algorithms)
plt.figure(figsize=(8, 5))
plt.bar(algorithms, avg_cov, color=["#4C72B0", "#DD8452", "#55A868", "#C44E52", "#8172B3"])
annotate_bars()
plt.xlabel("Algorithm")
plt.ylabel("Average coverage [%]")
plt.title("Average Coverage - All Algorithms\n(across all map sizes, 10 runs each)")
save("comparison_avg_coverage.png")

# 3) Generation time vs map size (line chart with error bars)
plt.figure(figsize=(10, 6))
for alg in algorithms:
    alg_data = summary[summary["algorithm"] == alg].sort_values("cells")
    plt.errorbar(
        alg_data["cells"], alg_data["time_mean"], yerr=alg_data["time_std"],
        marker="o", capsize=4, label=alg
    )
    last = alg_data.iloc[-1]
    plt.annotate(f"{last['time_mean']:.1f}", (last["cells"], last["time_mean"]),
                 textcoords="offset points", xytext=(5, 5), fontsize=7)
cells_list = sorted(df["cells"].unique())
size_map = {c: df[df["cells"] == c]["size"].iloc[0] for c in cells_list}
plt.xticks(cells_list, [size_map[c] for c in cells_list], rotation=20)
plt.xlabel("Map size (width × height)")
plt.ylabel("Generation time [ms]")
plt.title("Generation Time Scaling\n(mean ± std, 10 runs per size)")
plt.legend()
save("comparison_time_scaling.png")

# 4) Coverage vs map size (line chart with error bars)
plt.figure(figsize=(10, 6))
for alg in algorithms:
    alg_data = summary[summary["algorithm"] == alg].sort_values("cells")
    plt.errorbar(
        alg_data["cells"], alg_data["coverage_mean"], yerr=alg_data["coverage_std"],
        marker="o", capsize=4, label=alg
    )
    last = alg_data.iloc[-1]
    plt.annotate(f"{last['coverage_mean']:.1f}%", (last["cells"], last["coverage_mean"]),
                 textcoords="offset points", xytext=(5, 5), fontsize=7)
cells_list = sorted(df["cells"].unique())
size_map = {c: df[df["cells"] == c]["size"].iloc[0] for c in cells_list}
plt.xticks(cells_list, [size_map[c] for c in cells_list], rotation=20)
plt.xlabel("Map size (width × height)")
plt.ylabel("Coverage [%]")
plt.title("Coverage Scaling\n(mean ± std, 10 runs per size)")
plt.legend()
save("comparison_coverage_scaling.png")

# 5) Grouped bar chart - generation time per size, grouped by algorithm
for size_label in sizes:
    size_data = df[df["size"] == size_label]
    means = size_data.groupby("algorithm")["gen_time_ms"].mean().reindex(algorithms)
    stds = size_data.groupby("algorithm")["gen_time_ms"].std().reindex(algorithms)

    plt.figure(figsize=(8, 5))
    plt.bar(algorithms, means, yerr=stds, capsize=4,
            color=["#4C72B0", "#DD8452", "#55A868", "#C44E52", "#8172B3"])
    annotate_bars(yerr=stds)
    plt.xlabel("Algorithm")
    plt.ylabel("Generation time [ms]")
    plt.title(f"Generation Time Comparison - Map {size_label}\n(mean ± std, 10 runs)")
    save(f"comparison_time_{size_label}.png")

# 6) Grouped bar chart - coverage per size, grouped by algorithm
for size_label in sizes:
    size_data = df[df["size"] == size_label]
    means = size_data.groupby("algorithm")["coverage"].mean().reindex(algorithms)
    stds = size_data.groupby("algorithm")["coverage"].std().reindex(algorithms)

    plt.figure(figsize=(8, 5))
    plt.bar(algorithms, means, yerr=stds, capsize=4,
            color=["#4C72B0", "#DD8452", "#55A868", "#C44E52", "#8172B3"])
    annotate_bars(yerr=stds)
    plt.xlabel("Algorithm")
    plt.ylabel("Coverage [%]")
    plt.title(f"Coverage Comparison - Map {size_label}\n(mean ± std, 10 runs)")
    save(f"comparison_coverage_{size_label}.png")

# 7) Trade-off scatter: time vs coverage (one point per algorithm)
trade = df.groupby("algorithm").agg(
    time_mean=("gen_time_ms", "mean"),
    cov_mean=("coverage", "mean")
).reindex(algorithms)

plt.figure(figsize=(8, 6))
colors = ["#4C72B0", "#DD8452", "#55A868", "#C44E52", "#8172B3"]
for i, alg in enumerate(algorithms):
    t = trade.loc[alg, "time_mean"]
    c = trade.loc[alg, "cov_mean"]
    plt.scatter(t, c, s=120, color=colors[i], label=alg, zorder=5)
    plt.annotate(f"{alg}\n({t:.1f} ms, {c:.1f}%)", (t, c),
                 textcoords="offset points", xytext=(8, 5), fontsize=8)
plt.xlabel("Average generation time [ms]")
plt.ylabel("Average coverage [%]")
plt.title("Trade-off: Speed vs Coverage\n(across all map sizes, 10 runs each)")
plt.legend()
plt.grid(True, alpha=0.3)
save("comparison_tradeoff.png")


# =====================================================================
# PER-ALGORITHM GRAPHS
# =====================================================================

print("\nGenerating per-algorithm graphs...")

for alg in algorithms:
    alg_df = df[df["algorithm"] == alg]
    alg_summary = summary[summary["algorithm"] == alg].sort_values("cells")

    # ── Time across sizes (bar chart with error bars) ──
    plt.figure(figsize=(8, 5))
    plt.bar(alg_summary["size"], alg_summary["time_mean"],
            yerr=alg_summary["time_std"], capsize=4, color="#4C72B0")
    annotate_bars(yerr=alg_summary["time_std"])
    plt.xlabel("Map size")
    plt.ylabel("Generation time [ms]")
    plt.title(f"{alg} - Generation Time by Map Size\n(mean ± std, 10 runs)")
    save(f"{alg.lower()}_time_by_size.png")

    # ── Coverage across sizes (bar chart with error bars) ──
    plt.figure(figsize=(8, 5))
    plt.bar(alg_summary["size"], alg_summary["coverage_mean"],
            yerr=alg_summary["coverage_std"], capsize=4, color="#55A868")
    annotate_bars(yerr=alg_summary["coverage_std"])
    plt.xlabel("Map size")
    plt.ylabel("Coverage [%]")
    plt.title(f"{alg} - Coverage by Map Size\n(mean ± std, 10 runs)")
    save(f"{alg.lower()}_coverage_by_size.png")

    # ── Individual runs - time (scatter per size) ──
    plt.figure(figsize=(10, 5))
    for size_label in sizes:
        runs = alg_df[alg_df["size"] == size_label]
        plt.scatter(runs["run"], runs["gen_time_ms"], label=size_label, alpha=0.7)
    plt.xlabel("Run number")
    plt.ylabel("Generation time [ms]")
    plt.title(f"{alg} - Generation Time per Run")
    plt.legend(title="Map size")
    plt.xticks(range(10))
    save(f"{alg.lower()}_time_per_run.png")

    # ── Individual runs - coverage (scatter per size) ──
    plt.figure(figsize=(10, 5))
    for size_label in sizes:
        runs = alg_df[alg_df["size"] == size_label]
        plt.scatter(runs["run"], runs["coverage"], label=size_label, alpha=0.7)
    plt.xlabel("Run number")
    plt.ylabel("Coverage [%]")
    plt.title(f"{alg} - Coverage per Run")
    plt.legend(title="Map size")
    plt.xticks(range(10))
    save(f"{alg.lower()}_coverage_per_run.png")

    # ── Boxplot - time distribution per size ──
    plt.figure(figsize=(8, 5))
    box_data = [alg_df[alg_df["size"] == s]["gen_time_ms"].values for s in sizes]
    plt.boxplot(box_data, tick_labels=sizes)
    plt.xlabel("Map size")
    plt.ylabel("Generation time [ms]")
    plt.title(f"{alg} - Time Distribution by Map Size")
    save(f"{alg.lower()}_time_boxplot.png")

    # ── Boxplot - coverage distribution per size ──
    plt.figure(figsize=(8, 5))
    box_data = [alg_df[alg_df["size"] == s]["coverage"].values for s in sizes]
    plt.boxplot(box_data, tick_labels=sizes)
    plt.xlabel("Map size")
    plt.ylabel("Coverage [%]")
    plt.title(f"{alg} - Coverage Distribution by Map Size")
    save(f"{alg.lower()}_coverage_boxplot.png")


# =====================================================================
# PER-SIZE COMPARISON GRAPHS
# =====================================================================

print("\nGenerating per-size comparison graphs...")

for size_label in sizes:
    size_df = df[df["size"] == size_label]

    # ── Boxplot - time for all algorithms at this size ──
    plt.figure(figsize=(8, 5))
    box_data = [size_df[size_df["algorithm"] == a]["gen_time_ms"].values for a in algorithms]
    plt.boxplot(box_data, tick_labels=algorithms)
    plt.xlabel("Algorithm")
    plt.ylabel("Generation time [ms]")
    plt.title(f"Time Distribution - Map {size_label}")
    save(f"size_{size_label}_time_boxplot.png")

    # ── Boxplot - coverage for all algorithms at this size ──
    plt.figure(figsize=(8, 5))
    box_data = [size_df[size_df["algorithm"] == a]["coverage"].values for a in algorithms]
    plt.boxplot(box_data, tick_labels=algorithms)
    plt.xlabel("Algorithm")
    plt.ylabel("Coverage [%]")
    plt.title(f"Coverage Distribution - Map {size_label}")
    save(f"size_{size_label}_coverage_boxplot.png")


print("\nDone! All graphs saved in /plots folder.")