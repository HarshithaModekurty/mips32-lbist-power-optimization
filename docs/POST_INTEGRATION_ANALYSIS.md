# Post-Integration Analysis

## Scope

The original Member 2 handoff requested toggle-rate characterization,
conventional-versus-modified activity comparison, and scan test-time
measurements. The Member 3 handoff requested coverage versus pattern count,
coverage across the complete scan space, and final fault-analysis reporting.

This repository now contains integrated measurements from the real four-chain
MIPS32 wrapper rather than only the placeholder DUTs:

- Four chains.
- 256 shift cells per chain.
- 1,024 scanned state bits.
- Four LBIST patterns.
- Four scan lanes sampled on every shift edge.

## Integrated scan activity

The activity monitor counts transitions on the actual four-lane MIPS32 scan
input, not on the internal 32-bit PRPG word. Each run includes 4,096 lane-shift
opportunities (4 patterns x 256 shifts x 4 lanes).

| PRPG mode | Nominal target | Measured transitions | Measured rate |
|---|---:|---:|---:|
| 10% | 10% | 182 / 4,096 | 4% |
| 20% | 20% | 405 / 4,096 | 9% |
| 30% | 30% | 610 / 4,096 | 14% |
| 40% | 40% | 811 / 4,096 | 19% |
| 50% | 50% | 995 / 4,096 | 24% |
| 60% | 60% | 1,206 / 4,096 | 29% |
| Bypass | 100% | 2,057 / 4,096 | 50% |

The measured rate is lower than the configured nominal rate because the
integrated adapter selects four lanes (PRPG bits 0, 8, 16, and 24), and the
scan monitor measures transitions between consecutive lane values. The
nominal setting is therefore a modifier budget, not a guarantee of an exact
transition percentage at the selected physical lanes.

Figures:

- [Integrated scan activity PNG](figures/integrated_scan_activity.png)
- [Integrated scan activity PDF](figures/integrated_scan_activity.pdf)
- [Activity data](analysis/integrated_activity.csv)

## Activity-based power proxy (not measured power)

Dynamic switching power follows:

```text
P_dynamic = alpha x C x V^2 x f
```

The RTL results do **not** measure this equation. They measure only transitions
on four scan-input lanes. If capacitance, voltage, and frequency were held
constant, the measured transition ratio would be proportional to only the
scan-flop switching component of dynamic power. It does not represent total
LBIST, core, clock-tree, leakage, or silicon power.

The configured column is an activity budget, not a theoretical watt value. The
measured column is the real integrated scan transition rate normalized to the
bypass run's measured rate of 50%. Both are dimensionless ratios.

| Mode | Activity budget | Measured switching ratio (% bypass) | Budget reduction | Switching reduction |
|---|---:|---:|---:|---:|
| 10% | 10.00% | 8.00% | 90.00% | 92.00% |
| 20% | 20.00% | 18.00% | 80.00% | 82.00% |
| 30% | 30.00% | 28.00% | 70.00% | 72.00% |
| 40% | 40.00% | 38.00% | 60.00% | 62.00% |
| 50% | 50.00% | 48.00% | 50.00% | 52.00% |
| 60% | 60.00% | 58.00% | 40.00% | 42.00% |
| Bypass | 100.00% | 100.00% | 0.00% | 0.00% |

These switching reductions must not be reported as guaranteed chip-level power
savings. They are valid only as scan-lane activity reductions under the stated
simulation conditions.

Files:

- [Power-proxy data](analysis/integrated_power_proxy.csv)
- [Power-proxy plot PNG](figures/integrated_power_proxy.png)
- [Power-proxy plot PDF](figures/integrated_power_proxy.pdf)
- [Power-analysis script](../tools/analyze_power.py)

The measured switching ratio is more useful than the nominal target for the
integrated design because it includes the actual four-lane mapping and
observed transitions. It still excludes clock-tree power, leakage, internal
combinational switching, scan-enable/control overhead, capacitance variation,
and voltage/frequency effects.

## Vivado activity-constrained power estimate

The project was also synthesized with `lbist_mips32_top` as the Vivado top and
analyzed while changing the toggle-rate activity assumption from 100% to 10%
without changing the netlist. This is an FPGA power estimate, not a physical
board measurement or SAIF-backed result.

| Toggle activity | Dynamic power | Static power | Total estimated power | Dynamic reduction vs. 100% |
|---:|---:|---:|---:|---:|
| 100% | 83 mW | 92 mW | 175 mW | 0.0% |
| 90% | 82 mW | 92 mW | 174 mW | 1.2% |
| 80% | 80 mW | 92 mW | 172 mW | 3.6% |
| 70% | 78 mW | 92 mW | 170 mW | 6.0% |
| 60% | 76 mW | 92 mW | 168 mW | 8.4% |
| 50% | 74 mW | 92 mW | 166 mW | 10.8% |
| 40% | 71 mW | 92 mW | 163 mW | 14.5% |
| 30% | 68 mW | 92 mW | 160 mW | 18.1% |
| 20% | 64 mW | 92 mW | 156 mW | 22.9% |
| 10% | 59 mW | 92 mW | 151 mW | 28.9% |

The relative dynamic-power reduction is calculated as
`(bypass_dynamic - mode_dynamic) / bypass_dynamic × 100`. The 92 mW static
power is unchanged because the synthesized/routed implementation is unchanged.

Figures:

- [Vivado power variation PNG](figures/vivado_activity_power.png)
- [Vivado power variation PDF](figures/vivado_activity_power.pdf)
- [Vivado dynamic-power reduction PNG](figures/vivado_dynamic_power_reduction.png)
- [Vivado dynamic-power reduction PDF](figures/vivado_dynamic_power_reduction.pdf)

Data and plotting tools:

- [Vivado activity-power data](analysis/vivado_activity_power.csv)
- [Vivado power plot script](../tools/plot_vivado_power.py)

To obtain measured power in watts, the next required flow is gate-level
synthesis and activity-driven power estimation using a target technology
library, clock constraints, and SAIF/VCD activity. The current GHDL RTL flow
does not contain those technology inputs, so physical watts here would be
unsupported.

## Fault coverage

The final campaign covers every modeled stuck-at fault in the integrated scan
space:

```text
4 chains x 256 cells x 2 polarities = 2,048 faults
```

The first four-pattern run detected 1,762 faults (86.0%). Alias analysis
showed that the injector interpreted `fault_site` as a shift-cycle number
instead of a physical scan-cell position. The injector was corrected to model
the cell-to-output propagation latency and hold the stuck value through
observation.

Final result:

| Metric | Result |
|---|---:|
| Modeled faults | 2,048 |
| Detected | 2,048 |
| Aliased | 0 |
| Coverage | 100.0% |

Figure: [Integrated fault coverage PNG](figures/integrated_fault_coverage.png)

## Structural scan analysis

The four-chain partition is balanced:

- 1,024 state bits.
- 256 cells per chain.
- 256 shift clocks per pattern.
- One capture clock per pattern.

The structural plots are generated by `tools/analyze_scan.py` and
`tools/plot_results.py`:

- [Chain lengths](figures/scan_chain_lengths.png)
- [Latency and connectivity](figures/scan_latency_connectivity.png)
- [Four-chain mapping](analysis/scan_map_4chains.csv)

These are structural or simulation results. They are not silicon power
measurements. Physical power claims require post-synthesis or post-route
activity-driven power analysis.

## Reproduction

From the repository root:

```bash
python3 tools/analyze_scan.py
python3 tools/analyze_power.py
python3 tools/plot_results.py
python3 tools/plot_integrated_results.py
```

The integrated activity sweep is run with the configurable testbench generic:

```bash
ghdl -r --std=08 --workdir=work tb_lbist_mips32_top \
  -gPATTERN_COUNT=4 -gRUN_FAULT_CAMPAIGN=false -gTARGET_RATE_CODE=6
```

The final fault campaign is run with:

```bash
ghdl -r --std=08 --workdir=work tb_lbist_mips32_top \
  -gPATTERN_COUNT=4 -gRUN_FAULT_CAMPAIGN=true
```
