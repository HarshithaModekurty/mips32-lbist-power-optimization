# MIPS32 scan-based LBIST: Member 1

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

Run from the repository root with GHDL and Python 3 installed:

```powershell
.\tools\run_tests.ps1
# Or provide -Ghdl 'C:\path\to\ghdl.exe'
python tools/analyze_scan.py
python tools/build_handoff_docx.py
```

Default configuration: four balanced chains of 256 bits each. The controller,
LFSR, toggle-rate modifier, MISR, and fault injector are integration work for
Members 2 and 3. Structural cycle counts here are not measured power savings or
fault-coverage results.
