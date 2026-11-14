# Member 1 Vivado results and report plots

Completed 14 November 2026 with Vivado 2023.2. No board was specified, so this
run assumes XC7Z020-CLG400-1, a 20 ns (50 MHz) clock, and out-of-context IP mode.
The RTL required no changes for Vivado compatibility.

| Check | Observed result |
| --- | --- |
| XSim core and integrated scan regression | PASS at 5,536 ns |
| XSim 1,024-bit bank, four chains | PASS at 5,186 ns |
| XSim 1,024-bit bank, three chains | PASS at 6,906 ns |
| Synthesis, optimization, placement, routing | Completed |
| Routed LUTs | 2,430 / 53,200 (4.57%) |
| Routed flip-flops | 1,024 / 106,400 (0.96%) |
| Latches / block RAM / DSP | 0 / 0 / 0 |
| Worst setup slack / total negative setup slack | +7.291 ns / 0.000 ns |
| Worst hold slack | +0.119 ns |
| Failing setup / hold endpoints | 0 / 0 |
| Routed DRC | No errors; one ZPS7-1 warning |

## Figures for the project report

- [Chain lengths](figures/scan_chain_lengths.png): calculated longest chain and
  full-shift clocks versus chain count. Four chains require 256 shift clocks;
  one requires 1,024. Four-chain default is highlighted.
- [Latency and connectivity](figures/scan_latency_connectivity.png): calculated
  overlapped shift-plus-capture clocks and scan signal count. Four chains take
  257 steady-state clocks and eight scan data signals; one takes 1,025 clocks
  and two signals. Initial load/final unload and controller cycles are additional.
- [Vivado utilization](figures/vivado_utilization.png): actual routed resource
  usage for the default four-chain core. Other chain counts were not physically
  implemented in this run; this is not a synthesized chain-count resource sweep.

Every figure also has a PDF version with the same filename stem. Structural
sources are docs/analysis/chain_comparison.csv. Archived Vivado reports and
XSim PASS logs are in docs/vivado/. These plots belong to Member 1's performance
analysis. Power-versus-toggle-target and fault-coverage plots need the integrated
Members 2/3 system and suitable experiments.

## Interpretation and limits

The reported passing timing covers constrained internal paths. There are 73
inputs without input-delay constraints and 1,126 outputs without output-delay
constraints. The future external memory/board interface is not timing-closed.
Vivado also warns that HD.CLK_SRC is unset, so the top-level clock-buffer
delay/skew is not modeled. The DRC warning ZPS7-1 reports the missing Zynq PS7
block, expected for this standalone IP rather than a complete Zynq board design.
No board pin assignments or bitstream are supplied.

Vivado's vectorless baseline estimate is 0.116 W total, 0.013 W dynamic, and
0.103 W device static, with medium confidence and no simulation activity file.
It is not measured scan-shift power, a toggle-target experiment, or evidence of
power savings. Representative switching activity and the complete LBIST blocks
are needed before drawing those conclusions.

## Reproduce

Run from the repository root, adjusting the executable path for your installation:

```powershell
New-Item -ItemType Directory -Force build | Out-Null
& 'F:\Xilinx\Vivado\2023.2\bin\vivado.bat' -mode batch -source tools/run_vivado.tcl -log build/vivado_run.log -journal build/vivado_run.jou
```

Optional environment variables MIPS_FPGA_PART and MIPS_CLOCK_NS override the
target and clock period. Generated project files, waveforms, synthesis/routed
checkpoints and reports are under build/vivado/. The script explicitly adds
its generated simulation directory to the process PATH on Windows, so Vivado
can locate its batch scripts when implicit current-directory lookup is disabled.

To regenerate plots, use Python 3 with matplotlib installed:

```powershell
python tools/analyze_scan.py
python tools/plot_results.py
```

The plotting script prefers the archived routed utilization report under
docs/vivado/, falling back to build/vivado/. After a new run, update the archived
report before generating new figures and keep this summary's assumptions current.
