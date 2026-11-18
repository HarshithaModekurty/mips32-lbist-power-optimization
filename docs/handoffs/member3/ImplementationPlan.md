# Implementation Plan — VL405 DFT Lab Project
**Member 3 — LBIST Controller & Fault Analysis**
**Deadline: Nov 19 2025 | Presentation: Nov 20 2025**

---

## Deliverable Summary
> LBIST controller, response compactor (MISR), and fault-analysis framework — all in VHDL, with simulation results.

---

## Step-by-Step Status

### Phase 1 — RTL Design (DONE ✅)

| Step | File | Status |
|------|------|--------|
| 1.1 Shared package (constants, state codes) | `src/lbist_pkg.vhd` | ✅ Done |
| 1.2 MISR response compactor (Galois-form, x³²+x²²+x²+x+1) | `src/misr.vhd` | ✅ Done |
| 1.3 LBIST Controller FSM (8-state Moore machine) | `src/lbist_controller.vhd` | ✅ Done |
| 1.4 Fault injector (serial stuck-at SA0/SA1) | `src/fault_injector.vhd` | ✅ Done |
| 1.5 Top-level integration (`lbist_top`) | `src/lbist_top.vhd` | ✅ Done |

### Phase 2 — Simulation Infrastructure (DONE ✅)

| Step | File | Status |
|------|------|--------|
| 2.1 Placeholder DUT scan chain (N-FF, XOR comb logic) | `tb/dut_scan_chain.vhd` | ✅ Done |
| 2.2 Placeholder PRPG (32-bit Galois LFSR, seed=0xDEADBEEF) | `tb/prpg_placeholder.vhd` | ✅ Done |
| 2.3 MISR unit testbench (TC1–TC4) | `tb/tb_misr.vhd` | ✅ Done |
| 2.4 Controller unit testbench (PASS/FAIL/timing checks) | `tb/tb_lbist_controller.vhd` | ✅ Done |
| 2.5 Full-system fault coverage testbench | `tb/tb_lbist_top.vhd` | ✅ Done |
| 2.6 GHDL compilation & simulation script | `sim/run_ghdl.sh` | ✅ Done |

### Phase 3 — Simulation Results (DONE ✅)

| Test | Result |
|------|--------|
| `tb_misr` — TC1 Reset seed | ✅ PASS |
| `tb_misr` — TC2 Hold without enable | ✅ PASS |
| `tb_misr` — TC3 4-channel pattern compression | ✅ PASS |
| `tb_misr` — TC4 Aliasing check (two sequences → distinct sigs) | ✅ PASS |
| `tb_lbist_controller` — TC1 PASS scenario | ✅ PASS |
| `tb_lbist_controller` — TC2 FAIL scenario | ✅ PASS |
| `tb_lbist_controller` — TC3 Control sequencing (test_mode, scan_enable, capture_enable) | ✅ PASS |
| `tb_lbist_top` — 4-channel fault coverage (128 SA faults) | ✅ **100% (128/128 faults detected, 0 aliased)** |

### Phase 3B — 4-Channel Parallel Scan Adaptation (DONE ✅)
* Aligned with Member 1 MIPS32 scan architecture:
  * 4 parallel chains × 256 shift cycles = 1,024 flip-flops.
  * True 4-input 32-bit Galois MISR ($x^{32} + x^{22} + x^2 + x + 1$).
  * Test controls added: `test_mode`, `scan_enable`, `capture_enable`, `dut_rst_sync`.
  * 4-channel fault injector supporting chain selection (0–3) and bit position (0–255).
  * 4-channel decorrelated PRPG placeholder.
  * All tests compile and pass with 100% fault coverage.

### Phase 4 — Performance Analysis (REMAINING ⬜)

| Step | Description | Status |
|------|-------------|--------|
| 4.1 Test-time comparison | Compare cycles: conventional LBIST (1000 patterns, chain=32) vs power-modified LBIST from Member 2 | ⬜ Pending Member 2 handoff |
| 4.2 Toggle-rate measurement | Count bit transitions per pattern in SHIFT phase for conventional vs modified PRPG | ⬜ Pending Member 2 handoff |
| 4.3 Fault coverage vs pattern count table | Run with N = 5,10,20,50,100,200,500,1000 — all 100% (placeholder DUT); re-run after MIPS32 handoff | ✅ Done |
| 4.4 Fault coverage vs chain length | Verified design scales to 32-FF chain (64 SA0/SA1 faults): 100% detected (64/64), 0 aliasing | ✅ Done |
| 4.5 Aliasing probability discussion | Theoretical: 2⁻³² ≈ 2.3×10⁻¹⁰ per fault | ⬜ Write-up only |

### Phase 5 — Integration with Member 1 & 2 (REMAINING ⬜)

| Step | Description | Status |
|------|-------------|--------|
| 5.1 Swap `dut_scan_chain` for real MIPS32 core | Replace placeholder DUT with Member 1's scan-chain output | ⬜ Needs Member 1 handoff |
| 5.2 Swap `prpg_placeholder` for real PRPG | Replace placeholder with Member 2's toggle-rate-controlled PRPG | ⬜ Needs Member 2 handoff |
| 5.3 Re-run full fault simulation with MIPS32 DUT | Measure real fault coverage on MIPS32 scan chain | ⬜ After 5.1, 5.2 |
| 5.4 Obtain golden signature for real DUT | Run fault-free LBIST with MIPS32, capture MISR output | ⬜ After 5.1 |

### Phase 6 — Report & Documentation (REMAINING ⬜)

| Step | Description | Status |
|------|-------------|--------|
| 6.1 README written | Project overview | ✅ Done (this session) |
| 6.2 Write report section: LBIST architecture | FSM diagram, state table, block diagram | ⬜ To do |
| 6.3 Write report section: MISR design | Polynomial justification, aliasing analysis | ⬜ To do |
| 6.4 Write report section: Fault injection methodology | SA0/SA1 model, serial injection mechanism | ⬜ To do |
| 6.5 Write report section: Simulation results | Paste waveform screenshots + coverage table | ⬜ To do |
| 6.6 Write report section: Comparison (conventional vs modified) | Test time, toggle rate, coverage tradeoffs | ⬜ Needs Member 2 data |

---

## Interface Contracts (for team integration)

### My outputs → other members
| Signal | Direction | Description |
|--------|-----------|-------------|
| `scan_en` | Member 3 → Member 1 | Scan enable; Member 1 DUT must respect this |
| `dut_scan_in` | Member 3 → Member 1 | Serial scan input (wired from PRPG) |
| `prpg_advance` | Member 3 → Member 2 | Tells PRPG to advance/reload for next pattern |

### My inputs ← other members
| Signal | Direction | Description |
|--------|-----------|-------------|
| `dut_scan_out` | Member 1 → Member 3 | Serial scan output fed into MISR |
| `prpg_scan_in` | Member 2 → Member 3 | 1-bit pseudorandom serial pattern |

---

## Next Immediate Actions
1. **Run coverage-vs-pattern-count sweep** (Step 4.3) — can be done now independently.
2. **Collect Member 1's scan-chain entity name/ports** to do integration (Step 5.1).
3. **Collect Member 2's PRPG entity name/ports** (Step 5.2).
4. Start writing report sections 6.2–6.4 based on existing code.
