import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import os

# load results
df = pd.read_csv("results.csv")

# convert columns to numbers (invalid values become NaN)
df["run"] = pd.to_numeric(df["run"], errors="coerce")
df["gen_time_ms"] = pd.to_numeric(df["gen_time_ms"], errors="coerce")
df["coverage"] = pd.to_numeric(df["coverage"], errors="coerce")

# only keep valid runs
df = df[df["run"].notna()].copy()

# add helper columns
df["cells"] = df["width"] * df["height"]
df["size"] = df["width"].astype(str) + "x" + df["height"].astype(str)

# compute runs per config for plot labels
n_runs = int(df.groupby(["algorithm", "size"])["run"].count().median())

# get unique values for looping
algorithms = sorted(df["algorithm"].unique())
sizes = sorted(df["size"].unique(), key=lambda s: int(s.split("x")[0]) * int(s.split("x")[1]))

# sum up stats
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

# output folder
os.makedirs("plots", exist_ok=True)


# save the data
def save(name):
    path = os.path.join("plots", name)
    plt.tight_layout()
    plt.savefig(path, dpi=200)
    plt.close()
    print(f"  Saved {path}")


def make_boxplot(box_data, labels, xlabel, ylabel, title, colors=None):
    #Boxplot with jittered points, mean marker, colored boxes, and grid.
    _default = ["#4C72B0", "#DD8452", "#55A868", "#C44E52", "#8172B3"]
    if colors is None:
        colors = (_default * ((len(labels) // len(_default)) + 1))[:len(labels)]
    _fig, ax = plt.subplots(figsize=(8, 5))
    bplot = ax.boxplot(
        box_data, tick_labels=labels, patch_artist=True,
        medianprops=dict(color="black", linewidth=2, zorder=5),
        meanprops=dict(marker="D", markerfacecolor="crimson",
                       markeredgecolor="white", markeredgewidth=0.8,
                       markersize=8, zorder=6),
        showmeans=True,
    )
    for patch, color in zip(bplot["boxes"], colors):
        patch.set_facecolor(color)
        patch.set_alpha(0.55)
    for i, d in enumerate(box_data):
        jitter = np.random.normal(i + 1, 0.07, size=len(d))
        ax.scatter(jitter, d, alpha=0.35, s=16, color=colors[i], zorder=3, linewidths=0)
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.set_title(title)
    ax.yaxis.grid(True, alpha=0.35)
    ax.set_axisbelow(True)
    from matplotlib.lines import Line2D
    ax.legend(
        handles=[Line2D([0], [0], marker="D", color="w",
                        markerfacecolor="crimson", markersize=7, label="mean")],
        loc="upper right", framealpha=0.7,
    )


def annotate_bars(fmt="{:.1f}", yerr=None):
    # add value labels on top of bar chart bars
    ax = plt.gca()
    if yerr is not None:
        yerr_vals = yerr.values if hasattr(yerr, "values") else list(yerr)
    for i, bar in enumerate(ax.patches):
        h = bar.get_height()
        top = h + (yerr_vals[i] if yerr is not None and i < len(yerr_vals) else 0)
        ax.text(bar.get_x() + bar.get_width() / 2, top, fmt.format(h),
                ha="center", va="bottom", fontsize=8)

# COMPARISON GRAPHS (all algorithms together)

print("\nGenerating comparison graphs...")

# 1. bar chart - average generation time per algorithm 
avg_time = df.groupby("algorithm")["gen_time_ms"].mean().reindex(algorithms)
plt.figure(figsize=(8, 5))
plt.bar(algorithms, avg_time, color=["#4C72B0", "#DD8452", "#55A868", "#C44E52", "#8172B3"])

annotate_bars()

plt.xlabel("Algorithm")
plt.ylabel("Average generation time [ms]")
plt.title(f"Average Generation Time - All Algorithms\n(across all map sizes, {n_runs} runs each)")
save("comparison_avg_time.png")

# 2. bar chart  - average coverage per algorithm
avg_cov = df.groupby("algorithm")["coverage"].mean().reindex(algorithms)
plt.figure(figsize=(8, 5))
plt.bar(algorithms, avg_cov, color=["#4C72B0", "#DD8452", "#55A868", "#C44E52", "#8172B3"])
annotate_bars()
plt.xlabel("Algorithm")
plt.ylabel("Average coverage [%]")
plt.title(f"Average Coverage - All Algorithms\n(across all map sizes, {n_runs} runs each)")
save("comparison_avg_coverage.png")

# 3. eneration time vs map size
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
plt.title(f"Generation Time Scaling\n(mean ± std, {n_runs} runs per size)")
plt.legend()
save("comparison_time_scaling.png")

# 4. coverage vs map size
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
plt.title(f"Coverage Scaling\n(mean ± std, {n_runs} runs per size)")
plt.legend()
save("comparison_coverage_scaling.png")

# 5. grouped bar chart - generation time per size, grouped by algorithm
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
    plt.title(f"Generation Time Comparison - Map {size_label}\n(mean ± std, {n_runs} runs)")
    save(f"comparison_time_{size_label}.png")

# 6. grouped bar chart - coverage per size, grouped by algorithm
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
    plt.title(f"Coverage Comparison - Map {size_label}\n(mean ± std, {n_runs} runs)")
    save(f"comparison_coverage_{size_label}.png")

# 7. trade-off scatter: time vs coverage
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
plt.title(f"Trade-off: Speed vs Coverage\n(across all map sizes, {n_runs} runs each)")
plt.legend()
plt.grid(True, alpha=0.3)
save("comparison_tradeoff.png")


print("\nGenerating per-algorithm graphs...")

for alg in algorithms:
    alg_df = df[df["algorithm"] == alg]
    alg_summary = summary[summary["algorithm"] == alg].sort_values("cells")

    # time across sizes 
    plt.figure(figsize=(8, 5))
    plt.bar(alg_summary["size"], alg_summary["time_mean"],
            yerr=alg_summary["time_std"], capsize=4, color="#4C72B0")

    annotate_bars(yerr=alg_summary["time_std"])
    plt.xlabel("Map size")
    plt.ylabel("Generation time [ms]")
    plt.title(f"{alg} - Generation Time by Map Size\n(mean ± std, {n_runs} runs)")

    save(f"{alg.lower()}_time_by_size.png")

    # coverage across sizes
    plt.figure(figsize=(8, 5))
    plt.bar(alg_summary["size"], alg_summary["coverage_mean"],
            yerr=alg_summary["coverage_std"], capsize=4, color="#55A868")
        
    annotate_bars(yerr=alg_summary["coverage_std"])

    plt.xlabel("Map size")
    plt.ylabel("Coverage [%]")
    plt.title(f"{alg} - Coverage by Map Size\n(mean ± std, {n_runs} runs)")
    save(f"{alg.lower()}_coverage_by_size.png")

    # individual runs - time
    plt.figure(figsize=(10, 5))
    for size_label in sizes:
        runs = alg_df[alg_df["size"] == size_label]
        plt.scatter(runs["run"], runs["gen_time_ms"], label=size_label, alpha=0.7)
    plt.xlabel("Run number")
    plt.ylabel("Generation time [ms]")
    plt.title(f"{alg} - Generation Time per Run")
    plt.legend(title="Map size")
    plt.xticks(range(0, n_runs, max(1, n_runs // 10)))
    save(f"{alg.lower()}_time_per_run.png")

    # individual runs - coverage 
    plt.figure(figsize=(10, 5))
    for size_label in sizes:
        runs = alg_df[alg_df["size"] == size_label]
        plt.scatter(runs["run"], runs["coverage"], label=size_label, alpha=0.7)
    plt.xlabel("Run number")
    plt.ylabel("Coverage [%]")
    plt.title(f"{alg} - Coverage per Run")
    plt.legend(title="Map size")
    plt.xticks(range(0, n_runs, max(1, n_runs // 10)))
    save(f"{alg.lower()}_coverage_per_run.png")

    # boxplot - time distribution per size
    box_data = [alg_df[alg_df["size"] == s]["gen_time_ms"].values for s in sizes]
    make_boxplot(box_data, sizes, "Map size", "Generation time [ms]",
                 f"{alg} - Time Distribution by Map Size")
    save(f"{alg.lower()}_time_boxplot.png")

    # boxplot - coverage distribution per size
    box_data = [alg_df[alg_df["size"] == s]["coverage"].values for s in sizes]
    make_boxplot(box_data, sizes, "Map size", "Coverage [%]",
                 f"{alg} - Coverage Distribution by Map Size")
    save(f"{alg.lower()}_coverage_boxplot.png")


print("\nGenerating per-size comparison graphs...")

for size_label in sizes:
    size_df = df[df["size"] == size_label]

    # boxplot - time for all algorithms at this size
    box_data = [size_df[size_df["algorithm"] == a]["gen_time_ms"].values for a in algorithms]
    make_boxplot(box_data, algorithms, "Algorithm", "Generation time [ms]",
                 f"Time Distribution - Map {size_label}")
    save(f"size_{size_label}_time_boxplot.png")

    # boxplot - coverage for all algorithms at this size
    box_data = [size_df[size_df["algorithm"] == a]["coverage"].values for a in algorithms]
    make_boxplot(box_data, algorithms, "Algorithm", "Coverage [%]",
                 f"Coverage Distribution - Map {size_label}")
    save(f"size_{size_label}_coverage_boxplot.png")


print("All graphs saved in /plots folder.")