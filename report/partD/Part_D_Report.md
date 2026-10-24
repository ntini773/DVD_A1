# Part D - RTL to GDSII with LibreLane (SKY130)

Flow: LibreLane v3.1.0.dev3 (Classic flow), run in the IIC-OSIC-TOOLS Docker container with `--pdk sky130A --scl sky130_fd_sc_hd`.
The container default PDK is `ihp-sg13g2`, so the PDK flags are required.
Command for all runs: `bash report/partD/run_partD.sh 3.5 8.0` (see the script header). Per-attempt configs and metrics are in `report/partD/attempts/`.

## Clock period rule
- Base period: `1.2 x T_min = 1.2 x 2.604 = 3.125 ns`, rounded up to the next 0.5 ns = **3.5 ns** (T_min from Part C).
- After each setup failure: add 0.5 ns and run again.

## Attempts (every run)

| Attempt | CLOCK_PERIOD (ns) | Setup slack (ns) | Hold slack (ns) | DRC | LVS | Result |
|---|---:|---:|---:|---:|---:|---|
| 1 | 3.5 | -2.184 | +0.114 | 0 | 0 | FAIL (setup) |
| 2 | 4.0 | -1.684 | +0.133 | 0 | 0 | FAIL (setup) |
| 3 | 4.5 | -1.184 | +0.135 | 0 | 0 | FAIL (setup) |
| 4 | 5.0 | -0.682 | +0.135 | 0 | 0 | FAIL (setup) |
| 5 | 5.5 | -0.208 | +0.135 | 0 | 0 | FAIL (setup) |
| 6 | 6.0 | -0.154 | +0.135 | 0 | 0 | FAIL (setup) |
| 7 | 6.5 | -0.224 | +0.136 | 0 | 0 | FAIL (setup) |
| 8 | 7.0 | -0.137 | +0.136 | 0 | 0 | FAIL (setup) |
| 9 | 7.5 | -0.100 | +0.136 | 0 | 0 | FAIL (setup) |
| 10 | **8.0** | **+0.400** | +0.136 | 0 | 0 | **PASS** |

The slack is the worst slack over all 9 signoff corners (tt / ss / ff, each with min / nom / max wire RC). The limiting corner is `max_ss_100C_1v60` (slow-slow transistors, 1.60 V, 100 C, maximum wire RC).
Slack does not improve evenly with the period: the flow's timing repair and the clock tree change between runs.

## Part D results table (final run, 8.0 ns)

| Metric | Value |
|---|---|
| CLOCK_PERIOD used (ns) | 8.0 |
| Number of runs needed | 10 |
| Core area (um^2) | 17759.5 (die 22500 = 150 x 150) |
| Cells after synthesis (Part B) | 63 (16 flip-flops + 47 logic) |
| Cells after place and route | 331 instances: 86 logic/buffer cells + 245 tap cells (1552 filler/decap cells are added on top; 1883 instances in total) |
| Kinds of cells added | `buf_2` x17 and `clkdlybuf4s25_1`/`clkdlybuf4s50_1` x4 (timing repair buffers, 21), `clkbuf_16` x3 (clock tree), `tapvpwrvgnd_1` x245 (tap), `decap_*` x1298 and `fill_*` x254 (filler) |
| Wirelength (um) | 2499 |
| DRC errors | 0 |
| LVS errors | 0 |
| Setup slack (ns) | +0.400 |
| Post-route F_max (MHz) | 131.58 = 1000 / (8.0 - 0.400) |
| Part C F_max (MHz) | 384.02 |

## Comparison with Part C
- Part C gives 384.02 MHz (pre-layout, ideal clock, typical corner, no wires).
- Post-route F_max is 131.58 MHz, about 2.9x lower. Flow signoff uses the worst corner (slow, 1.08 V, 125 C), real wire delay, a real clock tree and input/output constraints.
- The 3.5 ns start point from Part C is too tight for the slow corner. It reaches the typical-corner result only at much larger periods.

## Cells added by place and route
- Cell count after synthesis: 63. After place and route: 86 non-tap cells. LibreLane runs its own Yosys synthesis, which gives 62 logic and flip-flop cells (16 sequential + 42 multi-input + 4 inverters, from `metrics.json`). 62 + 21 timing repair buffers + 3 clock buffers = 86.
- Tap cells (245) connect the wells to the power rails. Filler and decap cells (1552) fill empty space in the rows. They have no logic function.
- Standard-cell area is 1264.96 um^2 (7.1 % utilisation of the 17759.5 um^2 core). The die is large for this design by the assignment's rule.

## Sign-off
- All 76 stages completed in the final run. Setup, hold, DRC (Magic and KLayout), LVS and antenna checks all pass.
- Final files: `pnr/config.json`, `pnr/metrics.json`, `pnr/mult_array.gds`.
- Full run: `pnr/runs/p8ns/` (not committed; it is large).
