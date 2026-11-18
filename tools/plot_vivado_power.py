"""Plot Vivado activity-constrained power estimates."""
import csv
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "docs" / "analysis" / "vivado_activity_power.csv"
OUT = ROOT / "docs" / "figures"
OUT.mkdir(parents=True, exist_ok=True)

plt.rcParams.update({
    "font.size": 10,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "figure.dpi": 140,
})

with DATA.open(newline="") as stream:
    rows = list(csv.DictReader(stream))

rates = [int(row["toggle_rate_percent"]) for row in rows]
dynamic = [float(row["dynamic_power_mw"]) for row in rows]
static = [float(row["static_power_mw"]) for row in rows]
total = [float(row["total_power_mw"]) for row in rows]
reduction = [float(row["dynamic_reduction_percent_vs_bypass"]) for row in rows]

fig, ax = plt.subplots(figsize=(7.6, 4.3))
ax.plot(rates, dynamic, marker="o", linewidth=2.2, color="#15846b",
        label="Dynamic power")
ax.plot(rates, total, marker="s", linewidth=2.0, color="#48799c",
        label="Total estimated power")
ax.axhline(static[0], linestyle="--", linewidth=1.5, color="#9a6b32",
           label="Static power")
ax.set(xlim=(105, 5), xlabel="Toggle-rate activity (%)", ylabel="Power (mW)",
       title="Vivado activity-constrained power estimate")
ax.set_xticks(rates)
ax.legend(frameon=False)
ax.grid(axis="y", alpha=0.20)
fig.text(0.5, -0.02,
         "One integrated lbist_mips32_top netlist; 100% is the bypass/baseline case. Not measured hardware power.",
         ha="center", fontsize=8)
fig.tight_layout()
fig.savefig(OUT / "vivado_activity_power.png", bbox_inches="tight")
fig.savefig(OUT / "vivado_activity_power.pdf", bbox_inches="tight")
plt.close(fig)

fig, ax = plt.subplots(figsize=(7.4, 4.2))
ax.plot(rates, reduction, marker="o", linewidth=2.2, color="#c95c5c")
ax.fill_between(rates, 0, reduction, color="#c95c5c", alpha=0.15)
ax.set(xlim=(105, 5), xlabel="Toggle-rate activity (%)",
       ylabel="Dynamic-power reduction vs. 100% (%)",
       ylim=(0, 32),
       title="Estimated dynamic-power reduction")
ax.set_xticks(rates)
ax.grid(axis="y", alpha=0.20)
for rate, value in zip(rates, reduction):
    if rate in (100, 60, 30, 10):
        ax.annotate(f"{value:.1f}%", (rate, value), textcoords="offset points",
                    xytext=(0, 7), ha="center", fontsize=8)
fig.text(0.5, -0.02,
         "Relative reduction = (P_dynamic,bypass - P_dynamic,mode) / P_dynamic,bypass × 100.",
         ha="center", fontsize=8)
fig.tight_layout()
fig.savefig(OUT / "vivado_dynamic_power_reduction.png", bbox_inches="tight")
fig.savefig(OUT / "vivado_dynamic_power_reduction.pdf", bbox_inches="tight")
plt.close(fig)

print(f"Wrote Vivado power figures to {OUT}")
