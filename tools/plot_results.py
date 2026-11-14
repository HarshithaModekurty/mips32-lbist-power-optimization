"""Export report figures from structural CSVs and an optional Vivado report.

Requires matplotlib. Run analyze_scan.py first; run Vivado for FPGA utilization.
"""
import csv
from pathlib import Path
import re

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/figures'
OUT.mkdir(parents=True, exist_ok=True)
plt.rcParams.update({'font.size': 10, 'axes.spines.top': False,
                     'axes.spines.right': False, 'figure.dpi': 140})


def save(fig, name):
    fig.tight_layout()
    for extension in ('png', 'pdf'):
        fig.savefig(OUT / f'{name}.{extension}', bbox_inches='tight')
    plt.close(fig)


with (ROOT / 'docs/analysis/chain_comparison.csv').open() as stream:
    rows = list(csv.DictReader(stream))
labels = [row['chains'] for row in rows]
x = list(range(len(rows)))
lengths = [int(row['max_length']) for row in rows]
fig, ax = plt.subplots(figsize=(7.6, 4.1))
bars = ax.bar(x, lengths, color=['#48799c' if label != '4' else '#15846b' for label in labels])
ax.bar_label(bars, padding=3)
ax.set(xticks=x, xticklabels=labels, xlabel='Number of parallel scan chains',
       ylabel='Longest chain (bits) / full-shift clocks', ylim=(0, 1150),
       title='Balanced partitioning of 1,024 architectural state bits')
fig.text(.5, -.01, 'Calculated structural results; four-chain default highlighted. Common shift clock assumed.',
         ha='center', fontsize=8)
save(fig, 'scan_chain_lengths')

fig, axes = plt.subplots(1, 2, figsize=(9, 4))
for ax, field, ylabel, title, color in [
    (axes[0], 'shift_plus_capture_clocks', 'Clocks per steady-state pattern',
     'Overlapped shift + one capture', '#15846b'),
    (axes[1], 'scan_data_ports', 'Scan input + output signals',
     'Scan connectivity cost', '#48799c')]:
    values = [int(row[field]) for row in rows]
    bars = ax.bar(x, values, color=color)
    ax.bar_label(bars, padding=3, fontsize=8)
    ax.set(xticks=x, xticklabels=labels, xlabel='Number of chains', ylabel=ylabel,
           title=title, ylim=(0, max(values)*1.17))
fig.text(.5, -.01, 'Calculated counts exclude reset/controller overhead; initial load and final unload are additional.',
         ha='center', fontsize=8)
save(fig, 'scan_latency_connectivity')

# Use archived reports where available so figures remain reproducible after cleanup.
report = ROOT / 'docs/vivado/utilization_routed.rpt'
if not report.exists():
    report = ROOT / 'build/vivado/utilization_routed.rpt'
if report.exists():
    text = report.read_text()
    categories = ['Slice LUTs', 'Slice Registers', 'Block RAM Tile', 'DSPs']
    used, percentages = [], []
    for category in categories:
        match = re.search(r'\|\s*' + re.escape(category) + r'\*?\s*\|\s*(\d+)\s*\|\s*\d+\s*\|\s*\d+\s*\|\s*(\d+)\s*\|\s*([\d.]+)', text)
        if not match:
            raise ValueError(f'Missing resource row: {category}')
        used.append(int(match[1]))
        percentages.append(float(match[3]))
    fig, ax = plt.subplots(figsize=(7.5, 4.1))
    bars = ax.bar(categories, percentages, color='#48799c')
    ax.bar_label(bars, labels=[f'{n:,} used ({p:.2f}%)' for n, p in zip(used, percentages)], padding=4)
    ax.set(ylabel='Device capacity used (%)', ylim=(0, max(percentages)*1.4),
           title='Vivado routed utilization: default four-chain core')
    fig.text(.5, -.01, 'XC7Z020-CLG400-1 | Vivado 2023.2 | Out-of-context IP, excluding external LBIST blocks',
             ha='center', fontsize=8)
    save(fig, 'vivado_utilization')
print(f'Wrote PNG and PDF figures to {OUT}')
