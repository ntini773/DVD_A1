# 4-bit Array Multiplier - RTL to GDSII (SKY130)

## Team
| Name | Roll number |
|------|-------------|
| bhargav | 2023112014 |
| nitin | 2023112026 |

## Environment
- Host OS: Ubuntu 22.04
- Parts A and B (simulation, synthesis): pixi environment on the host with iverilog, yosys and gtkwave (`pixi shell`)
- Parts C and D (OpenSTA, LibreLane): IIC-OSIC-TOOLS Docker container `iic-osic`. The project folder is mounted at `/foss/designs/mult4_team07`.
- PDK: sky130A (`$PDK_ROOT/sky130A`), standard cell library sky130_fd_sc_hd, typical corner tt_025C_1v80

## Commands run (in order)

### Setup
```bash
cd ~/eda/designs
./setup_repo.sh mult4_team07      # creates folders, .gitignore, README, full_adder.v, first commits
cd mult4_team07
echo $PDK_ROOT $PDK              # check: sky130A
```

### Part A - RTL design and verification

**Task 1 - full adder** (`rtl/full_adder.v`, `assign` statements only)
```bash
iverilog -g2012 -o /dev/null rtl/full_adder.v
```

**Task 2 - array multiplier** (`rtl/mult_array.v`: 16 AND gates, 12 `full_adder` instances, 16 flip-flops, no `*`)
```bash
iverilog -g2012 -o /dev/null rtl/full_adder.v rtl/mult_array.v
```

**Task 3 - testbench** (`tb/tb_mult.v`: 10 ns clock, 2 reset cycles, 256 vectors, 2-cycle wait, writes `mult.vcd`)

**Task 4 - simulate until PASS**
```bash
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim
gtkwave mult.vcd
```
Result: `PASS: 256 vectors checked, 0 errors`  (saved in `report/partA/pass_line.txt`)

**Task 5 - own example and waveform** (roll number digit used: 4, from 2023112014, so A = 4 + 5 = 9, B = 7, P = 63. The other roll number, 2023112026, would give A = 11)
```bash
bash report/partA/run_partA.sh 4
gtkwave report/partA/example.vcd --script report/partA/gtkwave_view.tcl
```
Saved in `report/partA/`: `hand_example.txt`, `example_result.txt`, `waveform.png` (latency marked), `tb_example.v`.

**Task 6 - check that the testbench catches errors** (sum changed to `a ^ b`, then undone)
```bash
sed -i 's/assign sum  = a ^ b ^ cin;/assign sum  = a ^ b;/' rtl/full_adder.v
iverilog -g2012 -o sim tb/tb_mult.v rtl/full_adder.v rtl/mult_array.v
vvp sim | tail -3
git checkout rtl/full_adder.v
```
Result: `FAIL: 256 vectors checked, 95 errors`  (saved in `report/partA/fail_line.txt`; `run_partA.sh` repeats this on a temporary copy)

**Block diagram:** `report/partA/block_diagram.png` (16 AND, 12 full adders, 16 flip-flops)

**Commit**
```bash
git add rtl tb report/partA
git commit -m "Part A: RTL, testbench, results"
```

### Part B - Logic synthesis with Yosys

**Task 1 - write and run `synth/synth.tcl`** (7 steps: read_verilog, synth -flatten, dfflibmap, abc, opt_clean, stat, write_verilog)
```bash
yosys -c synth/synth.tcl
```
Writes `synth/mult_array_netlist.v` and `synth/mult_array_stat.rpt`.

**Task 2 - fill the Part B table** from `synth/mult_array_stat.rpt`
(the script below builds it: `report/partB/results_table.md`)

**Task 3 - simulate the synthesized netlist**
```bash
CELLS=$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog
iverilog -g2012 -DFUNCTIONAL -DUNIT_DELAY=#1 -o gls \
  tb/tb_mult.v $CELLS/primitives.v $CELLS/sky130_fd_sc_hd.v synth/mult_array_netlist.v
vvp gls
```
Result: see `report/partB/netlist_pass_line.txt`

**All three tasks in one go** (runs the commands above and saves results in `report/partB/`)
```bash
bash report/partB/run_partB.sh
```

**Commit**
```bash
git add synth report/partB
git commit -m "Part B: synthesis, netlist, stat report, netlist simulation"
```

### Part C - Static timing analysis

### Part D - Physical design
| Attempt | CLOCK_PERIOD (ns) | Setup slack (ns) | DRC | LVS | Result |
|---------|-------------------|------------------|-----|-----|--------|

## Use of AI tools
<!-- Say which parts used AI help, as the assignment requires. -->
