# MIPS32 scan-based LBIST: Member 1

The final combined IEEE-style submission is in [docs/report](docs/report/README.md),
including the [compiled report](docs/report/DFT_PROJECT_REPORT.pdf), final LaTeX
sources, updated figures, MIPS core waveform, and the complete code appendix.
This is the current submission version; member handoffs below are retained as
development documentation.

VHDL-2008 implementation of the Member 1 responsibilities in the supplied
VL405 assignment and team allocation: MIPS32 circuit under test, scan chains,
balanced partitioning, and scan-length analysis.

The repository initially contained only `project assignment (1).pdf`, so this
contribution supplies an original educational single-cycle MIPS32 subset.
It is not a complete MIPS32 ISA implementation. No external core is vendored.

- `rtl/`: synthesizable core, scan register bank, shared state definitions.
- `tb/`: self-checking instruction and scan simulations.
- `tools/run_tests.ps1`: GHDL regression; produces `build/core.ghw`.
- `tools/analyze_scan.py`: structural analysis and exact scan-bit mapping.
- [Member 1 handoff](docs/MEMBER1_HANDOFF.md): architecture, integration protocol,
  results, limitations, and next-member tasks.
- `docs/MEMBER1_HANDOFF.docx`: portable Word version of the handoff.
- `docs/validation.txt`: recorded simulator results.
- [Vivado results and plots](docs/VIVADO_RESULTS.md): XSim, routed utilization,
  internal timing, assumptions, and PNG/PDF figures.
- [Post-integration analysis](docs/POST_INTEGRATION_ANALYSIS.md): real-MIPS32
  scan activity, normalized theoretical-versus-measured switching-activity
  proxy,
  2,048-fault coverage, structural scan plots, and reproduction commands.
- `tools/run_vivado.tcl`: reproducible out-of-context Vivado validation flow.

Run from the repository root with GHDL and Python 3 installed:

```powershell
.\tools\run_tests.ps1
# Or provide -Ghdl 'C:\path\to\ghdl.exe'
python tools/analyze_scan.py
python tools/build_handoff_docx.py
```

Default configuration: four balanced chains of 256 bits each. The integrated
four-pattern campaign detects 2,048/2,048 modeled stuck-at faults (100%
coverage). The real-MIPS32 scan activity sweep is reported in
`docs/POST_INTEGRATION_ANALYSIS.md`; it is simulation activity, not a physical
silicon power measurement.

Vivado 2023.2 also passed the core and two scan simulations and completed routing
on an assumed XC7Z020 at 50 MHz: 2,430 LUTs, 1,024 flip-flops, +7.291 ns internal
setup slack. See the linked results for external timing and OOC limitations.
