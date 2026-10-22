# Part D — RTL-to-GDSII Physical Design Report

## Design
- Design: `mult_array`
- Technology: SKY130
- Flow: LibreLane
- Final clock period: 8.0 ns
- Successful run: `RUN_2026-10-22_12-21-04`

## Final Results

| Metric | Value |
|---|---:|
| Clock period | 8.0 ns |
| Setup WNS | +0.3999 ns |
| Setup TNS | 0.0000 ns |
| Setup violations | 0 |
| Hold WNS | 0.0000 ns |
| Die area | 22500.00 µm² |
| Core area | 17759.50 µm² |
| Standard-cell area | 1264.96 µm² |
| Standard-cell instances | 331 |
| Filler cells | 1552 |
| Tap cells | 245 |
| Routed wirelength | 2499.00 µm |
| DRC errors | 0 |
| LVS errors | 0 |
| Antenna-violating nets | 0 |
| Estimated post-route Fmax | 131.58 MHz |

## Timing Closure

| Clock period | Setup WNS | Result |
|---|---:|---|
| 3.5 ns | -2.184 ns | Setup failed |
| 4.0 ns | -1.684 ns | Setup failed |
| 6.0 ns | -0.154 ns | Setup failed |
| 10.5 ns | +2.900 ns | Passed |
| 8.0 ns | +0.400 ns | Passed — selected |

The initial clock period was calculated from the Part C
typical-corner minimum period of approximately 2.604 ns:

`ceil_to_0.5ns(1.2 × 2.604) = 3.5 ns`

The final post-route frequency estimate is:

`Fmax = 1000 / (8.0 - setup_slack) = 131.58 MHz`

Part C estimated Fmax: 384.02 MHz.

## Signoff and Warnings

The selected run completed all 80 LibreLane stages.

- Setup timing: PASS
- Hold timing: PASS
- DRC: PASS
- LVS: PASS
- Antenna: PASS

Maximum-slew violations were reported at slow PVT corners.
The flow completed successfully despite these warnings.

## Deliverables

- `pnr/config.json` — LibreLane configuration
- `pnr/mult_array.gds` — final GDSII
- `pnr/metrics.json` — final flow metrics
- `pnr/runs/RUN_2026-10-22_12-21-04/` — successful run artifacts
