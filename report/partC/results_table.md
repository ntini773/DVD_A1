# Part C results (OpenSTA, typical corner tt_025C_1v80, pre-layout, ideal clock)

Netlist: `synth/mult_array_netlist.v`. Constraints: input and output delay 1.0 ns.
Reports: `sta/timing_10ns.rpt`, `sta/timing_tmin.rpt`. Logs: `sta/sta_10ns.log`, `sta/sta_tmin.log`.

| Metric | Value |
|---|---|
| Worst slack at T = 10 ns (ns) | +7.396 |
| T_min (ns) | 2.604 (= 10 − 7.396) |
| F_max (MHz) | 384.02 (= 1000 / 2.604) |
| Slack at T = T_min (ns) | −0.004 at T = 2.60 ns (period rounded to 0.01 ns; close to 0) |
| Critical path start point | `_095_` (dfrtp_1 flip-flop, clk → Q) |
| Critical path end point | `_092_` (dfrtp_1 flip-flop, D input) |
| Number of cells on the critical path | 10: 2 flip-flops (start, end) + 8 combinational cells |
| Latency (ns) = 2 × T_min | 5.208 |
| Throughput (million results per second) | 384.02 (one result per clock cycle once the pipeline is full) |

## Critical path (from `sta/timing_tmin.rpt`)

| # | Cell instance | Type | Delay (ns) |
|---|---|---|---:|
| 1 | `_095_` | dfrtp_1 (flip-flop, clk→Q) | 0.398 |
| 2 | `_039_` | clkinv_1 | 0.074 |
| 3 | `_047_` | o311ai_0 | 0.348 |
| 4 | `_050_` | a21oi_1 | 0.172 |
| 5 | `_063_` | maj3_1 | 0.381 |
| 6 | `_064_` | xnor2_1 | 0.160 |
| 7 | `_066_` | maj3_1 | 0.385 |
| 8 | `_075_` | maj3_1 | 0.377 |
| 9 | `_079_` | xnor3_1 | 0.175 |
| 10 | `_092_` | dfrtp_1 (setup time 0.134 ns) | — |

Data arrival 2.471 ns. Required 2.600 − 0.134 = 2.466 ns. Slack −0.004 ns.

## Comparison with the 2N = 8 full-adder estimate

- Combinational cells on the path: 8. Total logic delay: 2.073 ns (2.471 − 0.398).
- Cells that come from full adders: `maj3` (carry) ×3, `xnor3` (sum) ×1 and `xnor2` (sum, with a shared half-add) ×1. This gives about 5 cells.
- The first 3 cells (`clkinv`, `o311ai`, `a21oi`) come from the AND gates and the first adder row. Yosys and ABC merged them.
- The count matches the estimate roughly (8 cells versus 8 full-adder delays). Yosys flattened the full adders and ABC re-mapped them, so cells no longer match one-to-one with `full_adder` instances. This reading comes from the cell types. It is not proved by a netlist trace.

## Other observations

- Asynchronous reset recovery slack: +9.228 ns at 10 ns, +1.828 ns at 2.60 ns. It is not the limiting path.
- These numbers are pre-layout. They use ideal clocks and no wire delay. Post-route results (Part D) are slower.
