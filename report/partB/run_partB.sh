#!/usr/bin/env bash
# run_partB.sh - Part B: synthesis (Yosys), results table, gate-level simulation.
#
# Run from the repo root, in the shell where yosys and iverilog work:
#   bash report/partB/run_partB.sh
#
# It runs, in order:
#   B1/B2  yosys -c synth/synth.tcl
#   B3     reads synth/mult_array_stat.rpt and writes the results table
#   B4     simulates the synthesized netlist with tb/tb_mult.v
# Everything is saved in report/partB/.

set -euo pipefail

say()  { echo -e "\033[1;32m==>\033[0m $*"; }
fail() { echo -e "\033[1;31mERROR:\033[0m $*"; exit 1; }

[[ -f synth/synth.tcl && -f rtl/mult_array.v && -f tb/tb_mult.v ]] \
  || fail "Run this from the repo root (the folder that contains rtl/, tb/ and synth/)."
command -v yosys    > /dev/null || fail "yosys not found."
command -v iverilog > /dev/null || fail "iverilog not found."
[[ -n "${PDK_ROOT:-}" ]] || fail "PDK_ROOT is not set. Example: export PDK_ROOT=\$HOME/.ciel"

LIBDIR="$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd"
LIB="$LIBDIR/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
CELLS="$LIBDIR/verilog"
[[ -f "$LIB" ]] || fail "Liberty file not found: $LIB"

OUT=report/partB
mkdir -p "$OUT"

# ---------------------------------------------------------------------------
# B1 / B2. Synthesis
# ---------------------------------------------------------------------------
say "B1/B2: yosys -c synth/synth.tcl"
if ! yosys -c synth/synth.tcl > "$OUT/yosys.log" 2>&1; then
  tail -20 "$OUT/yosys.log"
  fail "Yosys failed. Full log: $OUT/yosys.log"
fi
[[ -s synth/mult_array_netlist.v && -s synth/mult_array_stat.rpt ]] \
  || fail "Yosys did not write the netlist or the stat report."
echo "   wrote synth/mult_array_netlist.v and synth/mult_array_stat.rpt"

# ---------------------------------------------------------------------------
# B3. Results table
# ---------------------------------------------------------------------------
say "B3: results table"
python3 - "$LIB" << 'PY' | tee "$OUT/results_table.md"
import re, sys
lib_path = sys.argv[1]
rpt = open("synth/mult_array_stat.rpt").read()


def give_up(msg):
    print("Could not read synth/mult_array_stat.rpt: " + msg, file=sys.stderr)
    print("---- first 40 lines of the report ----", file=sys.stderr)
    print("\n".join(rpt.splitlines()[:40]), file=sys.stderr)
    sys.exit(1)


# 1. Cell counts. Works for the old layout ("sky130_x   16") and the newer
#    layouts ("16   400.384   sky130_x"): the count is the first whole number on the line.
cells = {}
for line in rpt.splitlines():
    toks = line.split()
    name = next((t for t in toks if t.startswith("sky130_fd_sc_hd__")), None)
    if not name:
        continue
    counts = [t for t in toks if t.isdigit()]
    if counts:
        cells[name] = int(counts[0])
if not cells:
    give_up("no sky130 cell lines found")

# 2. Total number of cells: use the report if it says so, else add up the lines
m = (re.search(r"Number of cells:\s+(\d+)", rpt)
     or re.search(r"^\s*(\d+)\s+cells\b", rpt, re.M))
total_cells = int(m.group(1)) if m else sum(cells.values())
if total_cells != sum(cells.values()):
    # the report total can include non-library cells; trust the library cells we can price
    print(f"note: report total {total_cells}, cell lines add up to {sum(cells.values())}",
          file=sys.stderr)

# 3. Area of each cell from the liberty file
lib = open(lib_path).read()


def cell_area(n):
    i = lib.index('cell ("%s")' % n)
    return float(re.search(r"area\s*:\s*([\d.]+)", lib[i:i + 4000]).group(1))


areas = {n: cell_area(n) for n in cells}
calc_area = sum(c * areas[n] for n, c in cells.items())
m = re.search(r"Chip area for (?:top )?module '[^']*':\s+([\d.]+)", rpt)
total_area = float(m.group(1)) if m else calc_area

ff = {n: c for n, c in cells.items() if "__df" in n or "__sdf" in n or "__dlx" in n}
n_ff = sum(ff.values())
ff_area = sum(c * areas[n] for n, c in ff.items())

top3 = sorted(cells.items(), key=lambda kv: (-kv[1], kv[0]))[:3]
top3_txt = ", ".join(f"{n.replace('sky130_fd_sc_hd__', '')} x{c}" for n, c in top3)

print("| Metric | Value |")
print("|---|---|")
print(f"| Total number of cells | {total_cells} |")
print(f"| Number of flip-flops | {n_ff} |")
print(f"| Total cell area (um^2) | {total_area:.2f} |")
print(f"| Flip-flop area (um^2) | {ff_area:.2f} |")
print(f"| Flip-flop area (% of total) | {100 * ff_area / total_area:.1f} % |")
print(f"| 3 most-used cell types | {top3_txt} |")
print(f"| Logic cells (total - flip-flops) | {total_cells - n_ff} |")
PY

# ---------------------------------------------------------------------------
# B4. Gate-level simulation of the synthesized netlist
# ---------------------------------------------------------------------------
say "B4: gate-level simulation"
[[ -f "$CELLS/primitives.v" && -f "$CELLS/sky130_fd_sc_hd.v" ]] \
  || fail "Cell models not found in $CELLS"
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls \
  tb/tb_mult.v "$CELLS/primitives.v" "$CELLS/sky130_fd_sc_hd.v" synth/mult_array_netlist.v \
  2> "$OUT/gls_compile.log" || { cat "$OUT/gls_compile.log"; fail "iverilog failed on the netlist."; }
vvp gls | tee "$OUT/gls.log" | grep -E "^(PASS|FAIL)" | tee "$OUT/netlist_pass_line.txt"

if grep -q "^PASS" "$OUT/netlist_pass_line.txt"; then
  say "Netlist behaves like the RTL. Part B simulation check passed."
else
  echo
  echo "The netlist FAILED while the RTL passed. Look at the first lines of $OUT/gls.log."
  echo "If the mismatches are many and random, the 10 ns clock may be too fast for the"
  echo "gate delays. Ask me about the slow-clock option before changing anything."
  exit 1
fi

say "Saved in $OUT/:"
ls -1 "$OUT" | sed 's/^/   /'
