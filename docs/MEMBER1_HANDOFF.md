# Member 1 implementation and handoff

Prepared: 14 November 2026. Source requirements: project assignment (1).pdf
(one-page VL405 project brief) and the supplied team allocation screenshot.

## Scope and requirement interpretation

The assignment asks for scan-based LBIST for a MIPS32 architecture, controllable
scan-shift toggle rate, VHDL hardware, simulation, performance analysis, and a
report. Member 1 owns the core, scan chains, scan-chain partitioning, architecture
optimization, and chain-length analysis. Members 2 and 3 own the remaining LBIST
blocks. This contribution is the Member 1 subsystem, not a complete LBIST system.

The starting repository contained the PDF only. There was no existing core to
reuse. An original educational MIPS32 subset is therefore supplied, with explicit
ISA limits below. The team should confirm that this subset meets its required
benchmark before extending instruction coverage or substituting another core.

## Files and architecture

- rtl/mips32_scan_pkg.vhd: 32-bit words, register-file type, 1,024-bit state and chain-length helper.
- rtl/scan_register_bank.vhd: reusable parameterized scan storage and balanced wiring.
- rtl/mips32_core.vhd: combinational instruction execution and scan-accessible architectural storage.
- tb/tb_mips32_core.vhd: self-checking functional and integrated scan tests.
- tb/tb_scan_register_bank.vhd: independent scan mapping, shift, capture, hold, and priority checks.
- tools/run_tests.ps1: repeatable GHDL regression and waveform generation.
- tools/analyze_scan.py: partition comparison and complete four-chain bit map.
- docs/analysis/: generated CSV analysis artifacts.

The core is single-cycle with separate external instruction and data interfaces.
Instruction and load data must be available combinationally before the active
rising edge. A store is committed by external memory on the rising edge when
data_write_enable is high. External memory is not supplied or scanned here.
Synchronous block RAM requires an adapter or a multicycle core redesign.

## Implemented instruction behavior

R-type: SLL (including NOP), SRL, SRA, JR, ADDU, SUBU, AND, OR, XOR,
NOR, SLT, SLTU. Immediate: ADDIU, SLTI, SLTIU, ANDI, ORI, XORI, LUI.
Memory: aligned LW and SW. Control flow: BEQ, BNE, J, JAL.

ADDU, SUBU, and ADDIU wrap modulo 2^32. Signed comparisons use two's-complement
values. SLTIU compares against the sign-extended immediate as unsigned; logical
immediates are zero-extended. Branch offsets are sign-extended and shifted by two.
Jump targets use PC+4's upper four bits. There are no delay slots: JAL links PC+4.
Register r0 always reads zero and ignores writes; it has no scan storage.

Unsupported opcodes/functions assert illegal_instruction, preserve registers, and
advance PC by four. Unaligned LW/SW assert misaligned_access and suppress the
load/store; an unaligned JR falls through to PC+4. These outputs are diagnostics,
not architectural exception handling. The core has no ADD/SUB overflow traps,
HI/LO, multiply/divide, byte/halfword accesses, privileged state, interrupt logic,
pipeline, caches, or full MIPS32 compliance. Memory byte ordering belongs to the
external word-oriented memory adapter.

## State layout and scan mapping

Exactly 1,024 state bits are scanned: 32 PC bits plus 31 writable 32-bit registers.
Bits 31:0 hold PC. Register r occupies bits (32*r+31):(32*r) for r=1..31.
There is no hidden pipeline or retained flag state in this implementation.
debug_state exposes the same vector for simulation and can be left open in a
production wrapper. Synthesis may remove unnecessary debug output wiring.

For N chains, chain c contains state bits c, c+N, c+2N, etc. Scan input enters
the lowest indexed member; each rising shift edge moves toward the highest
indexed member. scan_out(c) continuously exposes the final member before the
edge. Sample scan_out before shifting, or in a synchronous MISR at that edge.
This direct interleaving requires no padding flops or cross-chain state transfer.
The length difference is at most one, the minimum possible for a fixed bit count.
The generic requires 1 <= SCAN_CHAINS <= 1024.

For four chains every length is 256. To load desired vector V, send V(1020+c)
first on chain c, then V(1016+c), and finish with V(c). After capture, unload
in that same descending index order. docs/analysis/scan_map_4chains.csv lists every
state bit, register, chain, position, and unload cycle.

For unequal chains, use L=max(chain lengths) shift edges. On chain c of length
Lc, the first L-Lc load inputs are don't-care and the final Lc inputs must be the
desired chain contents in descending order. During unload, only the first Lc
samples belong to the captured response. Mask later samples per chain at the
MISR input. Short chains keep shifting; they do not automatically hold. During
overlapped unload/load, the outgoing response mask and incoming load alignment
are separate obligations of the controller and pattern generator.

## Integration contract for Members 2 and 3

All controls and inputs must meet setup/hold timing at the common rising clock.
There is no internally gated clock or clock-domain crossing.

1. Assert reset for at least one rising edge. Reset is synchronous, active high,
   and has priority over every other control; PC and writable registers clear.
2. Set test_mode=1, scan_enable=1. Drive one modified LFSR bit per chain per edge.
   Shift exactly L edges for a full load and sample any outgoing response before
   each edge. scan_enable takes priority over capture_enable.
3. Set scan_enable=0, capture_enable=1 for one edge to capture one combinational
   execution response into all architectural flops. Drive deterministic instruction
   and data_read values. These primary inputs are external to the scan state and
   must be controlled by the LBIST wrapper; otherwise X values spoil signatures.
4. Set capture_enable=0 to hold. Shift out the response with scan_enable=1 while
   optionally loading the next pattern. Apply per-chain output masks if unequal.
5. After LBIST, reset before normal execution because scanned state is arbitrary.
   Set test_mode=0 and run_enable=1 for normal instruction execution.

In test mode run_enable is ignored; only scan/capture controls change the state.
In functional mode scan_enable and capture_enable are ignored; run_enable advances
the core. External data writes are suppressed throughout reset and test mode and
while run_enable=0. A test capture can load data_read into a register, but cannot
write external memory. The controller must independently mask initial unloads
before any captured response exists and any reset/idle cycles in the MISR.

Member 2 connects the LFSR and modifier to scan_in(N-1:0). Define whether target
toggle rate is per input stream, averaged across streams, or measured inside all
scan flops; these are different metrics. Member 3 supplies test_mode, scan_enable,
capture_enable, pattern counts and MISR enables. Connect scan_out to the MISR,
with the sampling and mask rules above. A scalar generator needs a deliberate
fanout/phase-shift strategy for parallel chains; duplicated bits reduce diversity.

## Partitioning and performance analysis

Generated comparison assumes a common clock, one bit per chain per shift edge,
all 1,024 flops, and one capture edge per pattern. It excludes controller overhead.
One-chain length is 1,024; two chains are 512 each; four are 256; eight are 128;
16 are 64; 32 are 32. Three chains have lengths 342,341,341 and require two
masked output slots over a 342-edge unload.

The default four-chain design reduces shift latency from 1,024 to 256 clocks
(ideal 4x shift speedup), and overlapped load/unload plus capture is 257 clocks
per steady-state pattern instead of 1,025. It uses four scan input and four output
signals instead of one each. For P patterns with overlapped load/unload, total
clocks are (P+1)*L+P, including the initial load and final response unload.
Without overlap they are P*(2*L+1). Reset/controller cycles are additional.

Balancing minimizes maximum chain length; excluding r0 avoids 32 unneeded scan
flops. Parallelism trades shorter test time for more generator/MISR connectivity
and potentially greater simultaneous switching. Four chains are a starting
configuration, not a measured optimum. No claim is made that parallelism alone
reduces power. A subsequent Vivado run implemented the four-chain core on an
assumed XC7Z020 at 50 MHz: 2,430 LUTs, 1,024 flip-flops and +7.291 ns internal
setup slack. See docs/VIVADO_RESULTS.md for archived reports, plots, and limits.
Measured power, coverage and toggle targets remain pending.
Run activity-based power analysis and fault simulation
with the full Members 2/3 system before making those claims.

## Validation and reproduction

Run tools/run_tests.ps1 with GHDL supporting VHDL-2008; specify -Ghdl if the
executable is not on PATH. The script stops on any compilation or assertion error.
It produces build/core.ghw and a default-core GHDL synthesis netlist at
build/mips32_core_synth.vhd. Synthesis elaboration passed; this does not establish
FPGA implementation, area, maximum clock rate, or timing closure.
Run python tools/analyze_scan.py for the CSV outputs
and python tools/build_handoff_docx.py to regenerate the Word handoff using only
Python's standard library. docs/validation.txt records the actual verification.
The recorded run passes all ten simulation configurations and synthesis. GHDL
emits one numeric_std metavalue warning at time zero while connected signals
settle in delta cycles, before reset; no warning persists during execution.

The core regression exercises every supported instruction kind, hardwired r0,
signed/unsigned comparisons, immediate extension, taken/untaken branches, jumps,
load/store buses, misalignment suppression, unsupported opcode/function detection,
run hold, test hold, complete arbitrary scan loading, functional capture, serial
response unloading and reset during scan. The scan regression checks 1,024 bits
with 1,2,3,4,8,16,32 chains, 17 bits/3 chains, and the 1-bit/1-chain boundary.
It independently predicts the entire shifted vector and serial outputs on every
edge and checks reset/shift/capture priority. These are directed RTL simulations,
not exhaustive ISA equivalence, timing closure, or fault-coverage evidence.

## Continuation checklist

Report figures are available as PNG and PDF under docs/figures/: balanced scan
lengths, latency versus connectivity, and actual Vivado routed utilization.
Regenerate them with tools/plot_results.py (requires matplotlib); their sources
and interpretation are documented in docs/VIVADO_RESULTS.md.

- Confirm subset suitability and the absence of delay slots with the team; expand ISA if needed.
- Integrate Members 2/3 blocks with the protocol and deterministic primary inputs above.
- Add an end-to-end known-good signature test and reproducible seeded pattern experiments.
- Sweep toggle targets and chain counts using identical seeds, pattern budgets and faults.
- Measure internal scan transitions, capture transitions, fault coverage, area, timing and power separately.
- Compare equal coverage/test time against unmodified LFSR patterns before claiming the assignment's full objective.
- Choose the final chain count from measurements; preserve scan mapping/version information with every signature.
