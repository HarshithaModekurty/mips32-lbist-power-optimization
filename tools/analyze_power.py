"""Create a normalized scan-switching proxy from integrated scan activity.

This is not a power measurement. It reports activity ratios only. Converting
these ratios into watts requires technology-aware parasitic and power data.
"""
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
analysis = ROOT / "docs" / "analysis"

with (analysis / "integrated_activity.csv").open(newline="") as stream:
    rows = list(csv.DictReader(stream))

bypass_activity = float(next(row["measured_percent"] for row in rows
                             if row["mode"] == "Bypass"))

output = []
for row in rows:
    nominal = float(row["nominal_percent"])
    measured = float(row["measured_percent"])
    output.append({
        "mode": row["mode"],
        "nominal_activity_percent": f"{nominal:.2f}",
        "measured_activity_percent": f"{measured:.2f}",
        "configured_activity_budget_percent": f"{nominal:.2f}",
        "measured_switching_ratio_percent_of_bypass":
            f"{100 * measured / bypass_activity:.2f}",
        "configured_budget_reduction_percent": f"{100 - nominal:.2f}",
        "measured_switching_reduction_percent":
            f"{100 * (bypass_activity - measured) / bypass_activity:.2f}",
    })

with (analysis / "integrated_power_proxy.csv").open("w", newline="") as stream:
    fields = list(output[0])
    writer = csv.DictWriter(stream, fieldnames=fields)
    writer.writeheader()
    writer.writerows(output)

print("Wrote docs/analysis/integrated_power_proxy.csv")
