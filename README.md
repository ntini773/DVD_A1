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

Run inside the IIC-OSIC-TOOLS container (OpenSTA 3.1.0), from the repo root.

**Setup - enter the container and select the PDK**
```bash
docker exec -it iic-osic bash          # on the host
cd /foss/designs/mult4_team07
sta -version                           # 3.1.0
sak-pdk sky130A
echo $PDK_ROOT $PDK                    # /foss/pdks sky130A
ls $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
```

**Task 1 - write `sta/sta.tcl` and run it at T = 10 ns** (7 steps: read_liberty, read_verilog + link_design, create_clock, set_input_delay 1.0, set_output_delay 1.0, report_worst_slack, report_checks. The period defaults to 10 ns and can be changed with `STA_PERIOD`.)
```bash
STA_PERIOD=10.0 STA_REPORT=sta/timing_10ns.rpt sta -exit sta/sta.tcl 2>&1 | tee sta/sta_10ns.log
```
Result: worst slack = **+7.396 ns**. So T_min = 10 - 7.396 = **2.604 ns**, F_max = 1000 / 2.604 = **384.02 MHz**.

**Task 1 (cont.) - run again at T = T_min rounded to 0.01 ns (2.60 ns)**
```bash
STA_PERIOD=2.60 STA_REPORT=sta/timing_tmin.rpt sta -exit sta/sta.tcl 2>&1 | tee sta/sta_tmin.log
STA_PERIOD=2.60 sta -exit sta/sta.tcl     # writes the deliverable sta/mult_array_timing.rpt
```
Result: worst slack = **-0.004 ns** (close to 0; the 0.004 ns comes from rounding 2.604 down to 2.60).

**Tasks 2 and 3 - critical path** (from `sta/mult_array_timing.rpt`)
- Start point: `_095_` = input register `a_r[1]` (dfrtp_1). End point: `_092_` = output register `p[6]` (dfrtp_1).
- Cells: `_095_` dfrtp_1 -> `_039_` clkinv_1 -> `_047_` o311ai_0 -> `_050_` a21oi_1 -> `_063_` maj3_1 -> `_064_` xnor2_1 -> `_066_` maj3_1 -> `_075_` maj3_1 -> `_079_` xnor3_1 -> `_092_` dfrtp_1
- 10 cells: 2 flip-flops + 8 combinational cells, compared with the estimate of 2N = 8 full-adder delays.

**All Part C runs in one go**
```bash
bash report/partC/run_partC.sh
```
Results table: `report/partC/results_table.md`

**Commit**
```bash
git add sta report/partC
git commit -m "Part C: OpenSTA script, timing reports, T_min and F_max"
```

### Part D - Physical design

Run inside the IIC-OSIC-TOOLS container with LibreLane v3.1.0.dev3 (Classic flow). The container's default PDK is `ihp-sg13g2`, so `--pdk sky130A --scl sky130_fd_sc_hd` is given on every run.

**Task 1 - write `pnr/config.json` and run the flow**

Start period = 1.2 x T_min = 1.2 x 2.604 = 3.125 ns, rounded up to the next 0.5 ns = **3.5 ns**. After each setup failure, add 0.5 ns and run again.
```bash
cd /foss/designs/mult4_team07
bash report/partD/run_partD.sh 3.5 8.0
# for each period P = 3.5, 4.0, ... the script writes a config with CLOCK_PERIOD = P and runs:
#   cd pnr && librelane --pdk sky130A --scl sky130_fd_sc_hd --run-tag pXns --overwrite config_pXns.json
# it stops at the first run with setup slack >= 0, DRC = 0 and LVS = 0
```
Configs and metrics of every attempt: `report/partD/attempts/`. Summary: `report/partD/attempts.tsv`.

Every attempt (setup slack = worst over all 9 signoff corners; the limiting corner is `max_ss_100C_1v60`):

| Attempt | CLOCK_PERIOD (ns) | Setup slack (ns) | DRC | LVS | Result |
|---------|-------------------|------------------|-----|-----|--------|
| 1  | 3.5 | -2.184 | 0 | 0 | FAIL (setup) |
| 2  | 4.0 | -1.684 | 0 | 0 | FAIL (setup) |
| 3  | 4.5 | -1.184 | 0 | 0 | FAIL (setup) |
| 4  | 5.0 | -0.682 | 0 | 0 | FAIL (setup) |
| 5  | 5.5 | -0.208 | 0 | 0 | FAIL (setup) |
| 6  | 6.0 | -0.154 | 0 | 0 | FAIL (setup) |
| 7  | 6.5 | -0.224 | 0 | 0 | FAIL (setup) |
| 8  | 7.0 | -0.137 | 0 | 0 | FAIL (setup) |
| 9  | 7.5 | -0.100 | 0 | 0 | FAIL (setup) |
| 10 | **8.0** | **+0.400** | 0 | 0 | **PASS** |

**Copy the final results** (run `p8ns`)
```bash
cp report/partD/attempts/config_p8ns.json pnr/config.json
cp pnr/runs/p8ns/final/metrics.json pnr/metrics.json
cp pnr/runs/p8ns/final/gds/mult_array.gds pnr/mult_array.gds
```

**Tasks 2 to 4 - read the numbers from `pnr/metrics.json`**
```bash
grep -E '"design__instance__count"|core__area|die__area|"route__wirelength"|"timing__setup__ws"|drc_error|lvs_error' pnr/metrics.json
grep -E 'instance__count__class' pnr/metrics.json      # buffers, tap, fill cells added
```
Result: CLOCK_PERIOD 8.0 ns, setup slack +0.400 ns, post-route F_max = 1000 / (8.0 - 0.400) = **131.58 MHz** (Part C: 384.02 MHz), core area 17759.5 um^2, wirelength 2499 um, 0 DRC, 0 LVS. Full table: `report/partD/Part_D_Report.md`.

**Task 5 - layout screenshots in KLayout**
```bash
klayout -l report/partD/sky130A.lyp pnr/mult_array.gds
```
Saved: `report/partD/klayout_full_die.png` (whole die), `report/partD/klyaout_zoom.png` (cell rows and metal wires).

**Commit**
```bash
git add pnr/config.json pnr/metrics.json pnr/mult_array.gds report/partD
git commit -m "Part D: LibreLane flow, final GDS and metrics"
```

### Report
`report/report.pdf` (8 pages): sections 1 Introduction, 2 Design and verification (Part A), 3 Synthesis (Part B), 4 Timing (Part C), 5 Physical design (Part D), 6 Answers to questions, 7 Conclusion, then Individual Contributions and an appendix with logs. It holds the results tables for Parts A to D, the waveform, block diagram and layout screenshots, and the answers to questions 1 to 6. The LaTeX source is `report/latex/report.tex`; to rebuild it:
```bash
cd report/latex
pdflatex report.tex && pdflatex report.tex   # run twice so the cross-references update
cp report.pdf ../report.pdf
```

## Individual contributions
The work was divided equally: Bhargav did Parts A and C, answered Q2 and Q6, maintained this README and wrote the report; Nitin did Parts B and D, drew the block diagram and answered Q1, Q3, Q4 and Q5. Both cross-checked each other's results. Details are in the report.

## Use of AI tools
An AI assistant was used during this assignment, as the assignment allows. We used it to:
- check our deliverables against the assignment guide;
- analyse the tool logs and metrics, for example to explain why the setup slack changes unevenly across the LibreLane runs and to trace the critical path back to the full adders;
- write the Part C and Part D sections of this README from our logs and scripts;
- draft and typeset the report from our results.

All RTL, scripts and tool runs are our own, and every number in this README and the report comes from our own runs. We reviewed every part and can explain each line.
