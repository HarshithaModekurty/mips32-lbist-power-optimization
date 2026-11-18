"""Generate reproducible post-integration LBIST figures."""
import csv
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "docs" / "analysis"
OUT = ROOT / "docs" / "figures"
OUT.mkdir(parents=True, exist_ok=True)

plt.rcParams.update({
    "font.size": 10,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "figure.dpi": 140,
})


def save(fig, name):
    fig.tight_layout()
    fig.savefig(OUT / f"{name}.png", bbox_inches="tight")
    fig.savefig(OUT / f"{name}.pdf", bbox_inches="tight")
    plt.close(fig)


with (DATA / "integrated_activity.csv").open(newline="") as stream:
    rows = list(csv.DictReader(stream))

labels = [row["mode"] for row in rows]
targets = [float(row["nominal_percent"]) for row in rows]
measured = [float(row["measured_percent"]) for row in rows]

fig, ax = plt.subplots(figsize=(7.4, 4.2))
x = list(range(len(rows)))
width = 0.36
ax.bar([v - width / 2 for v in x], targets, width, label="Configured target",
       color="#9bbbd4")
ax.bar([v + width / 2 for v in x], measured, width, label="Measured on MIPS32 scan lanes",
       color="#15846b")
ax.set(
    xticks=x,
    xticklabels=labels,
    xlabel="PRPG mode",
    ylabel="Toggle rate (%)",
    ylim=(0, 110),
    title="Integrated four-lane scan activity by target mode",
)
ax.legend(frameon=False)
fig.text(
    0.5,
    -0.01,
    "Measured over 4 patterns and 4,096 lane-shift opportunities; rates are integer percentages.",
    ha="center",
    fontsize=8,
)
save(fig, "integrated_scan_activity")

with (DATA / "integrated_power_proxy.csv").open(newline="") as stream:
    power_rows = list(csv.DictReader(stream))

configured_activity = [
    float(row["configured_activity_budget_percent"]) for row in power_rows
]
measured_switching = [
    float(row["measured_switching_ratio_percent_of_bypass"]) for row in power_rows
]

fig, ax = plt.subplots(figsize=(7.4, 4.2))
ax.plot(labels, configured_activity, marker="o", linewidth=2,
        label="Configured activity budget", color="#48799c")
ax.plot(labels, measured_switching, marker="s", linewidth=2,
        label="Measured switching ratio", color="#15846b")
ax.set(
    xlabel="PRPG mode",
    ylabel="Normalized scan switching (% of bypass)",
    ylim=(0, 110),
    title="Configured activity versus measured scan switching",
)
ax.legend(frameon=False)
fig.text(
    0.5,
    -0.01,
    "Switching activity is a power-related proxy; no watts or total-chip power are claimed.",
    ha="center",
    fontsize=8,
)
save(fig, "integrated_power_proxy")

fig, ax = plt.subplots(figsize=(6.6, 4.0))
ax.bar(["Detected", "Aliased"], [2048, 0], color=["#15846b", "#c95c5c"])
ax.set_ylim(0, 2200)
ax.set_ylabel("Fault count")
ax.set_title("Integrated four-pattern stuck-at fault campaign")
ax.text(0, 2048 + 30, "2,048", ha="center")
ax.text(1, 30, "0", ha="center")
fig.text(
    0.5,
    -0.01,
    "Four chains × 256 cells × SA0/SA1; corrected physical-cell fault model.",
    ha="center",
    fontsize=8,
)
save(fig, "integrated_fault_coverage")

print(f"Wrote integrated figures to {OUT}")
