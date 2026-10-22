#!/usr/bin/env bash
# run_partA.sh - run Part A checks and save every result for the report.
#
# Usage (from the repo root, inside `pixi shell`):
#   bash report/partA/run_partA.sh <last_digit_of_roll_number>
# Example:
#   bash report/partA/run_partA.sh 7
#
# It does NOT change anything in rtl/ or tb/. All results go to report/partA/.

set -euo pipefail

DIGIT="${1:-}"
[[ "$DIGIT" =~ ^[0-9]$ ]] || { echo "Usage: $0 <last digit of roll number, 0-9>"; exit 1; }
[[ -f rtl/full_adder.v && -f rtl/mult_array.v && -f tb/tb_mult.v ]] \
  || { echo "Run this from the repo root (the folder that contains rtl/ and tb/)."; exit 1; }
command -v iverilog > /dev/null || { echo "iverilog not found. Run 'pixi shell' first."; exit 1; }

OUT=report/partA
mkdir -p "$OUT"
say() { echo -e "\033[1;32m==>\033[0m $*"; }

A=$((DIGIT + 5))
B=7
[[ $A -eq 7 ]] && B=9
EXP=$((A * B))

# ---------------------------------------------------------------------------
# A1. Real design: must print PASS
# ---------------------------------------------------------------------------
say "A1: simulate the real design"
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim | tee "$OUT/sim_full.log" | grep -E "^(PASS|FAIL)" | tee "$OUT/pass_line.txt"
grep -q "^PASS" "$OUT/pass_line.txt" || { echo "Design did not pass - fix it before going on."; exit 1; }

# ---------------------------------------------------------------------------
# A6 (task 6). Deliberate bug, done on a temp copy so your real files are untouched
# ---------------------------------------------------------------------------
say "Task 6: break the sum on purpose (temp copy only)"
TMP=$(mktemp -d)
sed 's/assign sum  *= a ^ b ^ cin;/assign sum  = a ^ b;/' rtl/full_adder.v > "$TMP/full_adder.v"
if cmp -s rtl/full_adder.v "$TMP/full_adder.v"; then
  echo "Could not apply the bug (check the sum line in full_adder.v)."; rm -rf "$TMP"; exit 1
fi
iverilog -g2012 -o "$TMP/sim_bad" tb/tb_mult.v "$TMP/full_adder.v" rtl/mult_array.v
( cd "$TMP" && vvp sim_bad ) | tee "$OUT/sim_broken.log" | grep -E "^(PASS|FAIL)" | tee "$OUT/fail_line.txt"
grep -q "^FAIL" "$OUT/fail_line.txt" || { echo "Testbench did not catch the bug!"; exit 1; }
rm -rf "$TMP" mult.vcd.tmp 2> /dev/null || true
# The broken run wrote nothing into your repo. Rebuild the real sim to be safe:
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v

# ---------------------------------------------------------------------------
# A2. Hand-worked example in the Section 2 layout
# ---------------------------------------------------------------------------
say "A2: hand example for A=$A, B=$B"
python3 - "$A" "$B" > "$OUT/hand_example.txt" << 'PY'
import sys
A, B = int(sys.argv[1]), int(sys.argv[2])
w = 8
lines = []
lines.append(f"A = {A:04b} ({A}) and B = {B:04b} ({B})\n")
lines.append(f"{'':>{w-4}}{A:04b}   A")
lines.append(f"{'x':<{w-4}}{B:04b}   B")
lines.append("-" * (w + 4))
total = 0
for i in range(4):
    bi = (B >> i) & 1
    pp = A if bi else 0
    total += pp << i
    bits = f"{pp:04b}" + "0" * i
    lines.append(f"{bits:>{w}}   pp{i} = A AND b{i} (b{i} = {bi}), shifted {i}")
lines.append("-" * (w + 4))
lines.append(f"{total:08b}   P = {total}")
lines.append(f"\nCheck: {A} x {B} = {A*B}  ->  {'OK' if total == A*B else 'MISMATCH'}")
print("\n".join(lines))
PY
cat "$OUT/hand_example.txt"

# ---------------------------------------------------------------------------
# A3. Small testbench just for your example -> short, clean waveform
# ---------------------------------------------------------------------------
say "A3: example waveform for $A x $B"
cat > "$OUT/tb_example.v" << EOF
\`timescale 1ns/1ps
// Waveform helper for the report: reset, then ONE multiplication ($A x $B).
module tb_example;
    reg        clk   = 0;
    reg        rst_n = 0;
    reg  [3:0] a     = 0;
    reg  [3:0] b     = 0;
    wire [7:0] p;
    mult_array dut (.clk(clk), .rst_n(rst_n), .a(a), .b(b), .p(p));
    always #5 clk = ~clk;                // posedges at 5, 15, 25, 35, 45 ns
    initial begin
        \$dumpfile("$OUT/example.vcd");
        \$dumpvars(0, tb_example);
        #20 rst_n = 1;                   // reset held low for 2 clock edges (5, 15 ns)
        #10 a = $A; b = $B;              // inputs change at 30 ns
        #60 \$display("a=%0d b=%0d p=%0d (expected $EXP)", a, b, p);
        \$finish;
    end
endmodule
EOF
iverilog -g2012 -o sim_example "$OUT/tb_example.v" rtl/full_adder.v rtl/mult_array.v
vvp sim_example | grep "p=" | tee "$OUT/example_result.txt"
rm -f sim_example

cat > "$OUT/gtkwave_view.tcl" << 'EOF'
# Loads the 5 signals and zooms to 0-80 ns. Times are in ps (the VCD unit).
gtkwave::addSignalsFromList [list \
  tb_example.clk tb_example.rst_n tb_example.a\[3:0\] tb_example.b\[3:0\] tb_example.p\[7:0\]]
gtkwave::setZoomRangeTimes 0 80000
gtkwave::setMarker 35000
EOF

cat << EOF

Waveform timeline for your example (ns):
   30  inputs a=$A, b=$B change
   35  clock edge 1 -> inputs captured into a_r, b_r
   45  clock edge 2 -> product captured into p  (p = $EXP after this edge)
Latency = 2 clock edges. Mark 35 -> 45 in the screenshot.

Open the waveform:
   gtkwave $OUT/example.vcd --script $OUT/gtkwave_view.tcl
EOF

say "Done. Results are in $OUT/"
ls -1 "$OUT" | sed 's/^/   /'
