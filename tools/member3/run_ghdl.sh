#!/usr/bin/env bash
# =============================================================================
# run_ghdl.sh  –  Compile and simulate the LBIST system with GHDL
#
# Usage (from the sim/ directory):
#   chmod +x run_ghdl.sh
#   ./run_ghdl.sh
#
# Requires GHDL ≥ 2.0  (https://github.com/ghdl/ghdl)
# Optional:  gtkwave  (waveform viewer)
# =============================================================================

set -e   # exit on first error

WORK="./work"
SRC="../../rtl/member3"
TB="../../tb/member3"
STD="--std=08"

mkdir -p "$WORK"

echo "================================================================"
echo "  LBIST System – GHDL Compilation & Simulation"
echo "================================================================"

# ── 1. Analyse source (RTL) files in dependency order ──────────────────────
echo ""
echo "[1/3] Analysing RTL source files ..."

ghdl -a $STD --workdir="$WORK" "$SRC/lbist_pkg.vhd"
ghdl -a $STD --workdir="$WORK" "$SRC/misr.vhd"
ghdl -a $STD --workdir="$WORK" "$SRC/lbist_controller.vhd"
ghdl -a $STD --workdir="$WORK" "$SRC/fault_injector.vhd"
ghdl -a $STD --workdir="$WORK" "$SRC/lbist_top.vhd"

echo "    RTL analysis OK."

# ── 2. Analyse testbench files ──────────────────────────────────────────────
echo ""
echo "[2/3] Analysing testbench files ..."

ghdl -a $STD --workdir="$WORK" "$TB/dut_scan_chain.vhd"
ghdl -a $STD --workdir="$WORK" "$TB/prpg_placeholder.vhd"
ghdl -a $STD --workdir="$WORK" "$TB/tb_misr.vhd"
ghdl -a $STD --workdir="$WORK" "$TB/tb_lbist_controller.vhd"
ghdl -a $STD --workdir="$WORK" "$TB/tb_lbist_top.vhd"

echo "    Testbench analysis OK."

# ── 3. Elaborate and run each testbench ────────────────────────────────────
echo ""
echo "[3/3] Running simulations ..."

# --- MISR unit test ---
echo ""
echo "  [SIM] tb_misr ..."
ghdl -e $STD --workdir="$WORK" tb_misr
ghdl -r $STD --workdir="$WORK" tb_misr --wave=tb_misr.ghw
echo "        Done → tb_misr.ghw"

# --- LBIST Controller unit test ---
echo ""
echo "  [SIM] tb_lbist_controller ..."
ghdl -e $STD --workdir="$WORK" tb_lbist_controller
ghdl -r $STD --workdir="$WORK" tb_lbist_controller --wave=tb_lbist_controller.ghw
echo "        Done → tb_lbist_controller.ghw"

# --- Full-system + fault-coverage analysis ---
echo ""
echo "  [SIM] tb_lbist_top  (full fault-analysis – this may take a moment) ..."
ghdl -e $STD --workdir="$WORK" tb_lbist_top
ghdl -r $STD --workdir="$WORK" tb_lbist_top --wave=tb_lbist_top.ghw
echo "        Done → tb_lbist_top.ghw"

echo ""
echo "================================================================"
echo "  All simulations complete."
echo "  View waveforms:"
echo "    gtkwave tb_lbist_top.ghw"
echo "    gtkwave tb_misr.ghw"
echo "================================================================"
