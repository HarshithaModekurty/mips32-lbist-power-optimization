# VL405 — Design for Testability Lab
## Scan-Based LBIST with Power-Aware Pattern Generation
### Member 3 Deliverable: LBIST Controller & Fault Analysis

---

## Project Overview

This repository implements a **scan-based Logic Built-In Self-Test (LBIST)** system targeting a MIPS32 processor. The system addresses the core problem of **high switching power** during LBIST by integrating with a toggle-rate-controlled PRPG (Member 2), while this sub-module handles:

- LBIST sequencing and control (FSM)
- Response compression via a 32-bit MISR
- Serial stuck-at fault injection for coverage analysis
- Full fault-coverage measurement framework

---

## Directory Structure

```
DFT_project/
├── src/                        # RTL source files (synthesisable)
│   ├── lbist_pkg.vhd           # Shared constants, state codes
│   ├── misr.vhd                # 32-bit MISR response compactor
│   ├── lbist_controller.vhd   # 8-state Moore FSM controller
│   ├── fault_injector.vhd     # Serial SA0/SA1 fault injector
│   └── lbist_top.vhd          # Top-level integration
│
├── tb/                         # Testbench files (simulation only)
│   ├── dut_scan_chain.vhd     # Placeholder DUT (N-FF XOR chain)
│   ├── prpg_placeholder.vhd   # Placeholder PRPG (Galois LFSR)
│   ├── tb_misr.vhd            # MISR unit testbench
│   ├── tb_lbist_controller.vhd # Controller unit testbench
│   └── tb_lbist_top.vhd       # Full-system + fault analysis TB
│
└── sim/                        # Simulation scripts & artifacts
    ├── run_ghdl.sh             # One-shot compile + simulate script
    └── work/                   # GHDL compiled object directory
```

---

## Architecture

```
  Member 2 (PRPG)
       │ prpg_scan_in (1 bit/clk)
       ▼
  dut_scan_in ──────────────────► [Member 1: MIPS32 Scan Chain]
                                           │ dut_scan_out
                                           ▼
                                   ┌────────────────┐
                                   │ fault_injector  │ ◄── fault_en/site/type
                                   └───────┬────────┘      (testbench only)
                                           │
                                           ▼
                                      ┌────────┐
                                      │  MISR  │ ◄── misr_rst_n, misr_capture
                                      └───┬────┘
                                          │ misr_sig (32-bit)
                                          ▼
                               ┌──────────────────┐
                               │ lbist_controller │ ◄── golden_sig, start
                               │   (8-state FSM)  │
                               └──────────────────┘
                                   │         │
                              scan_en    test_done/pass
```

---

## LBIST Controller FSM

| State | scan_en | misr_rst_n | misr_capture | prpg_advance | test_done |
|-------|---------|------------|--------------|--------------|-----------|
| IDLE | 0 | 1 | 0 | 0 | 0 |
| INIT | 0 | **0** | 0 | **1** | 0 |
| SHIFT | **1** | 1 | **1** | 0 | 0 |
| CAPTURE | 0 | 1 | 0 | 0 | 0 |
| LOAD | 0 | 1 | 0 | **1** | 0 |
| COMPARE | 0 | 1 | 0 | 0 | 0 |
| PASS | 0 | 1 | 0 | 0 | **1** |
| FAIL | 0 | 1 | 0 | 0 | **1** |

**Test time per run:** `1 + N_patterns × (chain_length + 2) + 1` clock cycles

---

## MISR Design

- **Width:** 32 bits
- **Primitive polynomial:** x³² + x²² + x² + x + 1
- **Form:** Galois (left-shift with feedback XOR at taps 21, 1, 0)
- **Seed:** All-ones (avoids LFSR lock-up at all-zeros)
- **Aliasing probability:** ≈ 2⁻³² ≈ 2.3 × 10⁻¹⁰

---

## Simulation Results

### MISR Unit Test (`tb_misr`)
| Test Case | Result |
|-----------|--------|
| TC1 — Reset seed = all-ones | PASS |
| TC2 — Hold stable without enable | PASS |
| TC3 — Signature after 32 zero-bits = `0x7FE00402` | PASS |
| TC4 — Different inputs → different signatures (no aliasing) | PASS |

### Controller Unit Test (`tb_lbist_controller`)
| Test Case | Result |
|-----------|--------|
| TC2 — Signatures match → test_pass = '1' | PASS |
| TC3 — Signatures differ → test_pass = '0' | PASS |
| TC4 — scan_en high only during SHIFT states | PASS |

### Full Fault Coverage (`tb_lbist_top`)
| Parameter | Value |
|-----------|-------|
| Scan chain length | 16 FFs |
| Test patterns | 50 |
| Total SA faults (SA0 + SA1) | 32 |
| Detected | **32** |
| Fault coverage | **100%** |
| Sim time | 301 µs (simulated) |

---

## How to Run Simulations

**Prerequisites:** `ghdl` ≥ 1.0 installed (`sudo apt install ghdl`)

```bash
cd DFT_project/sim
chmod +x run_ghdl.sh
./run_ghdl.sh
```

This will compile all files, run all three testbenches, and print the fault coverage report to stdout. Waveform files (`.ghw`) can be opened with `gtkwave`.

---

## Integration Guide (for final assembly)

Replace the two placeholder entities before final submission:

1. **Member 1 handoff** — swap `tb/dut_scan_chain.vhd` with the actual MIPS32 scan chain entity. Ensure ports `scan_en`, `scan_in`, `scan_out`, `clk`, `rst_n` match.

2. **Member 2 handoff** — swap `tb/prpg_placeholder.vhd` with the toggle-rate-controlled PRPG. Ensure port `serial_out` → `prpg_scan_in` and `advance` → `prpg_advance` are connected.

3. Re-run `run_ghdl.sh` to get fault coverage on the real MIPS32 DUT.

4. Set `CHAIN_LEN_TB = 32` and `PAT_CNT_TB = 1000` in `tb_lbist_top.vhd` for the final numbers.

---

## Key Parameters (adjust in `lbist_pkg.vhd`)

| Constant | Default | Description |
|----------|---------|-------------|
| `CHAIN_LEN_C` | 32 | Scan chain length (flip-flops) |
| `MISR_W_C` | 32 | MISR width |
| `PAT_CNT_C` | 1000 | Number of test patterns |

---

*Course: VL405 — Design for Testability Lab | Submission: Nov 19 2025*

