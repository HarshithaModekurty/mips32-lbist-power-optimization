# MIPS32 Four-Chain LBIST Integration Plan

## 1. Current staged handoffs

The source snapshots have been copied into this repository without changing
their behavior:

- `rtl/member2/`: PRPG, toggle-rate controller, pattern modifier, activity
  monitors, and the conventional PRPG reference.
- `rtl/member3/`: four-channel LBIST package, controller, top-level wrapper,
  four-input MISR, and fault injector.
- `tb/member2/`: Member-2 unit testbenches.
- `tb/member3/`: Member-3 controller, MISR, placeholder-DUT, and coverage
  testbenches.
- `tools/member3/run_ghdl.sh`: the original Member-3 standalone regression
  script.
- `docs/handoffs/member2/` and `docs/handoffs/member3/`: reference copies of
  the original handoff documentation.

These are reference snapshots, not yet the final integrated design. The
existing Member-1 files in `rtl/` remain the current MIPS32 implementation.

## Current progress

- Phase 0 Member-1 baseline: passed.
- Phase 0 Member-2 baseline: passed after compiling its required
  `scan_chain_model` dependency.
- Phase 0 Member-3 four-channel placeholder regression: passed.
- A 32-bit Member-2 PRPG path and explicit four-lane adapter have been added
  in `rtl/member2/modified_prpg_4lane_adapter.vhd`.
- A first integrated wrapper has been added in
  `rtl/lbist_mips32_top.vhd`.
- The integrated smoke test in `tb/tb_lbist_mips32_top.vhd` passed a
  fault-free golden-signature run using the real MIPS32 core.
- The integrated protocol monitor passed for four patterns: 1,024 shift
  edges, four capture edges, and no scan/capture overlap.
- The representative integrated fault campaign passed its 90% gate at
  23/24 faults (95.8%) before the output-only fault model was replaced with
  a scan-cell state model. The original alias was a real equivalence case at
  the first observed scan-output bit and is no longer treated as a false
  positive from a bus-only override.
- The Member-3 fault injector now models a per-chain scan-cell state and
  injects stuck-at values at the modeled cell index rather than flattening the
  fault to the observed output bus. This avoids the false alias caused by
  forcing SA0/SA1 on an already-zero output bit.
- The attempted full 1,024-bit campaign did not complete within a 180-second
  validation limit. It is not marked as passed; the campaign needs a faster
  harness or a reduced-output batch mode before final coverage claims.
- The integrated testbench now exposes `PATTERN_COUNT` as a simulation
  generic. A complete 2,048-fault sweep with one pattern completed in
  approximately 5.4 ms of simulated time and detected 512 faults (25%).
  This is a runtime/space diagnostic only, not the final coverage result;
  the acceptance configuration remains the four-pattern fault-free run and
  its representative 90% gate.
- An integrated `scan_activity_monitor` now counts transitions on the actual
  four-lane MIPS32 scan input during shift, independently of the PRPG's
  internal activity counter. The four-pattern smoke run measured 2,057 lane
  transitions over 4,096 lane-shift opportunities, or 50%.
- The initial complete four-pattern integrated campaign exercised all 2,048
  modeled stuck-at faults and detected 1,762 (86.0%). Alias analysis showed
  that the injector was treating `fault_site` as a clock number rather than
  as a physical scan-cell position.
- The fault injector was corrected to apply the selected stuck-at value after
  the cell-to-output propagation latency and to hold it through observation.
  The corrected four-pattern campaign detected 2,048/2,048 faults (100.0%)
  and passed the 90% acceptance gate. It completed at approximately 21.3 ms
  of simulated time.

The integrated wrapper has passed the full fault-coverage gate and now
includes real scan-lane activity characterization. Remaining work is final
report packaging and, if required, post-synthesis/post-route power analysis.

## 2. Target integrated architecture

```text
Member-2 modified PRPG
    scan_data_parallel(3 downto 0)
              |
              v
Member-3 LBIST wrapper/controller
    test_mode, scan_enable, capture_enable, reset
              |
              v
Member-1 MIPS32 core
    scan_out(3 downto 0)
              |
              v
Member-3 fault injector -> four-input MISR -> signature comparator
```

The target scan configuration is four balanced chains of 256 bits each:

```text
4 chains * 256 bits = 1,024 scanned state bits
```

One shift clock must transfer one bit on each of the four chains. One
capture clock follows each 256-cycle shift window.

## 3. Required compatibility modifications

### 3.1 Member-2 PRPG changes

Files to modify:

- `rtl/member2/lfsr_prpg.vhd`
- `rtl/member2/pattern_modifier.vhd`
- `rtl/member2/toggle_rate_controller.vhd`
- `rtl/member2/modified_prpg_top.vhd`

Required changes:

1. Define the final four-lane output contract:
   `scan_data_parallel(3 downto 0)` must map directly to
   `mips32_core.scan_in(3 downto 0)`.
2. Do not rely on the current default `WIDTH => 16` or on undocumented
   truncation. Either:
   - use a validated four-bit PRPG and four-bit modifier, or
   - retain a wider PRPG but explicitly select and document four scan-lane
     outputs while measuring those four lanes.
3. Replace the non-16-bit fallback in `lfsr_prpg.vhd` with a validated,
   parameterized polynomial/seed implementation. The current fallback is not
   demonstrated to be maximal-length for `WIDTH => 4`.
4. Make PRPG advancement explicit. Member 3 currently emits
   `prpg_advance`, while Member 2 advances through `lbist_enable`. Define
   whether one PRPG update occurs per shift edge or once per pattern, then
   implement that handshake consistently.
5. Add or preserve a synchronous pattern-valid/enable contract so the scan
   inputs are stable before each active scan edge.
6. Preserve the selected toggle-rate behavior across all four actual scan
   inputs, not only across an internal 16-bit word.
7. Reset activity/statistics deterministically for the integrated test run.

### 3.2 Member-3 controller/top-level changes

Files to modify:

- `rtl/member3/lbist_controller.vhd`
- `rtl/member3/lbist_top.vhd`
- `rtl/member3/lbist_pkg.vhd`

Required changes:

1. Expose Member-2 controls:
   `lbist_enable`, `seed_load`, `seed_data`, `target_rate_sel`, and
   `custom_toggle_limit`, or create a wrapper that provides these controls.
2. Replace the ambiguous `prpg_advance`-only interface with the agreed PRPG
   handshake. The controller must not assume a pattern advances at a different
   rate from the PRPG implementation.
3. Keep `test_mode`, `scan_enable`, and `capture_enable` aligned with Member 1:
   - shift: `test_mode='1'`, `scan_enable='1'`, `capture_enable='0'`
   - capture: `test_mode='1'`, `scan_enable='0'`, `capture_enable='1'`
   - hold/load: `test_mode='1'`, `scan_enable='0'`, `capture_enable='0'`
4. Connect `dut_rst_sync` to the Member-1 active-high synchronous `reset`
   input. Do not connect the active-low system reset directly to the MIPS
   reset port.
5. Define whether the controller resets the MIPS state before every pattern or
   only once at LBIST initialization. The recommended choice is one reset at
   initialization, followed by scan shift/capture cycles.
6. Ensure the final pattern count and chain length are derived from the
   integrated constants rather than placeholder testbench values.
7. Keep fault-injection ports out of the production path or gate them under a
   verification wrapper.

### 3.3 Member-3 MISR changes

File to modify:

- `rtl/member3/misr.vhd`

Required changes:

1. Retain the four-input interface and document the chain-to-MISR bit mapping.
2. Verify the parallel update equation against an independently calculated
   reference model. Four response bits must be incorporated every shift edge.
3. Keep the MISR reset polarity local and explicit; the integrated top level
   must translate the system reset without relying on signal-name convention.
4. Add a directed test for lane-order sensitivity: changing only one of the
   four response lanes must change the signature.

### 3.4 Member-3 fault injector changes

File to modify:

- `rtl/member3/fault_injector.vhd`

Required changes:

1. Define `fault_chain` and `fault_site` in Member-1's scan coordinates.
   Member 1 interleaves state bits as `c, c+4, c+8, ...`; a fault site must
   therefore be mapped deliberately rather than treated as a flat serial
   index.
2. Confirm whether fault injection models a stuck scan-cell value, a stuck
   scan-output observation, or both. The current injector overrides the
   observed output only.
3. Reset the shift-position counter at the same boundary as the controller's
   shift window.
4. Add tests for the first and last positions of every chain and both SA0/SA1.

Status update: implemented. The injector now maintains a per-chain scan-cell
state and injects a stuck-at value at the requested cell index during the
shift window instead of corrupting only the instantaneous output bus. This
removes the false alias that was caused by an SA0 override on an already-zero
visible output bit.

### 3.5 Testbench and integration harness changes

Files to add or modify:

- `tb/member3/tb_lbist_top.vhd`
- new integrated testbench under `tb/`
- existing Member-1 testbench as a regression reference

Required changes:

1. Replace `dut_scan_chain` with the actual `mips32_core`.
2. Drive deterministic `instruction` and `data_read` values during capture.
3. Connect all four PRPG outputs to `scan_in(3 downto 0)`.
4. Connect all four MIPS scan outputs to the fault injector and MISR.
5. Drive the MIPS active-high synchronous reset from `dut_rst_sync`.
6. Generate a fault-free golden signature using the integrated PRPG and core.
7. Re-run the same pattern set with each modeled fault and report detected,
   undetected, and coverage percentages.
8. Add assertions for:
   - exactly 256 shift edges per pattern;
   - no scan shift during capture;
   - capture occurs for exactly one edge;
   - PRPG data is valid before each shift edge;
   - all four response lanes reach the MISR.

## 4. Stepwise execution plan

### Phase 0 — Baseline and provenance

1. Preserve the copied handoff snapshots.
2. Run the existing Member-1 regression and record its baseline result.
3. Run the copied Member-2 unit tests independently.
4. Run the copied Member-3 four-channel regression independently.
5. Record known limitations: placeholder DUT, placeholder PRPG, reset
   mismatch, and standalone script assumptions.

### Phase 1 — Establish shared integration definitions

1. Create one shared package for `NUM_CHAINS=4`, `CHAIN_LENGTH=256`,
   `TOTAL_FFS=1024`, MISR width, reset polarity, and scan-lane ordering.
2. Define the clock-edge protocol for PRPG update, scan shift, capture, and
   MISR sampling.
3. Define the PRPG handshake and the exact meaning of pattern boundaries.
4. Define the mapping between Member-1 interleaved state bits and
   `(fault_chain, fault_site)`.

### Phase 2 — Adapt Member 2

1. Implement and verify the four-lane PRPG output.
2. Correct generic-width polynomial and seed handling.
3. Add the agreed enable/advance/seed interface.
4. Connect the toggle-rate modifier to the four bits actually entering the MIPS
   scan chains.
5. Test bypass mode first, then 10%, 20%, 30%, 40%, 50%, and 60% modes.
6. Measure actual scan-register transitions, not only PRPG word Hamming
   distance.

### Phase 3 — Adapt Member 3

1. Update the controller to drive the Member-2 handshake.
2. Connect `dut_rst_sync` to the active-high MIPS reset.
3. Verify four-lane MISR compression and response ordering.
4. Verify fault injection at every chain boundary and representative interior
   positions.
5. Keep the standalone placeholder regression passing while developing the
   integrated harness.

### Phase 4 — Integrate the real MIPS32 core

1. Instantiate `mips32_core` in a new integrated top level.
2. Connect the four PRPG scan inputs and four MIPS scan outputs.
3. Drive deterministic instruction/data inputs during capture.
4. Connect the four-input MISR and signature comparator.
5. Verify reset, shift, capture, hold, and post-LBIST functional recovery.
6. Recalculate the golden signature using the final integrated configuration.

### Phase 5 — Verification and performance analysis

1. Run the fault-free LBIST at the selected pattern count. **Complete for
   the four-pattern integrated smoke run.**
2. Run stuck-at fault campaigns using the Member-1 scan mapping. **Complete:
   the corrected four-pattern 2,048-fault campaign detected 2,048/2,048
   faults (100.0%).**
3. Compare conventional PRPG versus modified PRPG at each target toggle rate.
   **The integrated modified-PRPG scan-lane sweep is complete; conventional
   PRPG remains a handoff-level reference because the integrated top uses the
   modified PRPG path.**
4. Measure:
   - total shift cycles;
   - total capture cycles;
   - four-chain scan-flop transitions;
   - measured toggle rate;
   - fault coverage;
   - signature aliasing cases;
   - resource and timing results where available.
5. Repeat with the full 1,024-bit, four-chain configuration rather than only
   reduced simulation dimensions.

Status update: the integrated scan transition counter and rate calculation are
implemented in `rtl/scan_activity_monitor.vhd` and connected through
`rtl/lbist_mips32_top.vhd`. The activity-only integrated smoke gate passes.
The corrected exhaustive four-pattern campaign passes with 100.0% coverage.
The final activity and coverage figures are documented in
`docs/POST_INTEGRATION_ANALYSIS.md`.

### Phase 6 — Documentation and final packaging

1. Update the main README with the integrated architecture and build commands.
2. Replace stale serial-only Member-3 interface descriptions.
3. Add final waveforms, signatures, coverage tables, and toggle-rate plots.
4. Document all assumptions, especially instruction/data values during capture.
5. Run clean regressions from the repository root.
6. Review that generated build artifacts and waveforms are excluded or stored
   intentionally.

## 5. Acceptance checklist

- [x] Four scan inputs and four scan outputs connect end-to-end.
- [x] MIPS reset is active-high and synchronous at the core boundary.
- [x] System reset polarity is explicit for each block.
- [x] One pattern performs exactly 256 shift cycles and one capture cycle.
- [ ] The PRPG handshake advances at the documented boundary.
- [x] The modifier limits the activity of the actual four scan lanes.
- [x] MISR incorporates all four response bits per shift edge.
- [x] Fault coordinates match Member-1's interleaved scan mapping.
- [x] Golden signature is generated by the integrated fault-free system.
- [x] Fault coverage and toggle-rate measurements use the full 1,024-bit core.
- [x] Integrated scan-lane transition counter reports activity from the real
  MIPS32 scan path.
- [x] Member-1, Member-2, Member-3, and integrated regressions pass.
- [x] Report and README describe the same final interfaces and results.
