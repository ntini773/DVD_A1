# Part C — OpenSTA Reproduction Guide

**Design:** `mult_array` (4-bit unsigned array multiplier)  
**PDK:** SKY130A / `sky130_fd_sc_hd`  
**Environment:** IIC-OSIC-TOOLS Docker container `iic-osic`  
**Project directory inside container:** `/foss/designs/mult4_team07`

## 1. Enter the container (run on Ubuntu host)

```bash
docker exec -it iic-osic bash
```

The project directory is already mounted into the container. All remaining commands are run **inside Docker**.

## 2. Verify tools and select the PDK

```bash
cd /foss/designs/mult4_team07
ls /foss/designs/mult4_team07
command -v sta
sta -version
echo "$PDK_ROOT"
echo "$PDK"
ls /foss/pdks
sak-pdk sky130A
echo "$PDK"
echo "$PDK_ROOT"
ls "$PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
```

Expected PDK: `sky130A`; PDK root: `/foss/pdks`. OpenSTA version observed: `3.1.0`.

## 3. Create `sta/sta.tcl`

From the project root, execute:

```bash
cat > sta/sta.tcl <<'EOF_TCL'
# Part C: Static Timing Analysis — SKY130 typical corner
set lib "$::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"
read_liberty $lib
read_verilog synth/mult_array_netlist.v
link_design mult_array

# Default 10 ns; override with STA_PERIOD environment variable
set T 10.0
if {[info exists ::env(STA_PERIOD)]} {
    set T $::env(STA_PERIOD)
}
puts "Clock period: $T ns"
create_clock -name clk -period $T [get_ports clk]

set_input_delay 1.0 -clock clk \
    [delete_from_list [all_inputs] [get_ports clk]]
set_output_delay 1.0 -clock clk [all_outputs]

puts "========== WORST SETUP SLACK =========="
report_worst_slack -max

set report_file "sta/mult_array_timing.rpt"
if {[info exists ::env(STA_REPORT)]} {
    set report_file $::env(STA_REPORT)
}
report_checks -path_delay max -digits 3 > $report_file
puts "Timing report saved to: $report_file"
EOF_TCL
```

## 4. Run STA at the initial 10 ns clock period

```bash
STA_PERIOD=10.0 STA_REPORT=sta/timing_10ns.rpt \
  sta -exit sta/sta.tcl 2>&1 | tee sta/sta_10ns.log
cat sta/timing_10ns.rpt
```

**Measured register-to-register setup slack:** `+7.396 ns`.

## 5. Calculate the minimum period and maximum frequency

Using the 10 ns clock and reported setup slack:

```text
T_min = 10.000 - 7.396 = 2.604 ns
F_max = 1000 / 2.604 = 384.02 MHz
```

These are **pre-layout** timing results with ideal clocks and the typical-corner library. The asynchronous-reset recovery path is separate from the register-to-register critical data path.

## 6. Verify timing at 2.60 ns

```bash
STA_PERIOD=2.60 STA_REPORT=sta/timing_tmin.rpt \
  sta -exit sta/sta.tcl 2>&1 | tee sta/sta_tmin.log
cat sta/timing_tmin.rpt
```

**Measured setup slack:** `-0.004 ns` (approximately zero; the tiny violation is caused by rounding the period down to 2.60 ns).

## 7. Inspect saved outputs

```bash
ls -lh sta/
cat sta/sta_10ns.log
cat sta/sta_tmin.log
cat sta/timing_10ns.rpt
cat sta/timing_tmin.rpt
```

Expected artifacts:

```text
sta/sta.tcl
sta/sta_10ns.log
sta/sta_tmin.log
sta/timing_10ns.rpt
sta/timing_tmin.rpt
```

## 8. Results to record in report

| Metric | Value |
|---|---:|
| Initial clock period | 10.000 ns |
| Setup slack at 10 ns | +7.396 ns |
| Minimum period | 2.604 ns |
| Pre-layout Fmax | 384.02 MHz |
| Verification period | 2.600 ns |
| Verification setup slack | −0.004 ns |
| Critical data path | `_095_` to `_092_` |
| Combinational standard cells on path | 8 |
| Reset recovery slack at 10 ns | +9.228 ns |
| Reset recovery slack at 2.60 ns | +1.828 ns |

The critical data path is `_095_` → `_039_` → `_047_` → `_050_` → `_063_` → `_064_` → `_066_` → `_075_` → `_079_` → `_092_`.

## 9. Part D clock-period handoff

```text
1.2 × T_min = 1.2 × 2.604 = 3.1248 ns
Rounded upward to the next 0.5 ns = 3.5 ns
```

Use `"CLOCK_PERIOD": 3.5` in `pnr/config.json` for the first LibreLane run.
